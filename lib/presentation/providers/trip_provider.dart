import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../data/models/trip_model.dart';
import '../../data/datasources/local_datasource.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/logger.dart';

class TripProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();

  List<Trip> _trips = [];
  bool _isLoading = false;
  String _currentOwnerId = AppConstants.guestOwnerId;
  StreamSubscription<firebase_auth.User?>? _authSub;

  List<Trip> get trips => _trips;
  bool get isLoading => _isLoading;
  String get currentOwnerId => _currentOwnerId;
  bool get canManageTrips => _currentOwnerId != AppConstants.guestOwnerId;

  TripProvider() {
    _currentOwnerId = _resolveOwnerId(_auth.currentUser);
    _authSub = _auth.authStateChanges().listen((user) async {
      final nextOwnerId = _resolveOwnerId(user);
      if (nextOwnerId == _currentOwnerId) {
        return;
      }
      _currentOwnerId = nextOwnerId;
      if (canManageTrips) {
        await _adoptLegacyLocalTrips();
      }
      await loadTrips();
    });
    loadTrips();
  }

  String _resolveOwnerId(firebase_auth.User? user) {
    return user?.uid ?? AppConstants.guestOwnerId;
  }

  Future<void> loadTrips() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!canManageTrips) {
        _trips = [];
        return;
      }
      await _adoptLegacyLocalTrips();
      _trips = await _loadTripsWithCloudSync();
    } catch (e) {
      Logger.error('Error loading trips', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveTrip(Trip trip) async {
    if (!canManageTrips) {
      throw StateError('Sign in is required to save trips.');
    }
    try {
      final scopedTrip = trip.copyWith(ownerUserId: _currentOwnerId);
      await _db.insertTrip(scopedTrip);
      await _syncSingleTrip(scopedTrip);
      await loadTrips();
    } catch (e) {
      Logger.error('Error saving trip', e);
      rethrow;
    }
  }

  Future<void> deleteTrip(String id) async {
    if (!canManageTrips) {
      throw StateError('Sign in is required to manage trips.');
    }
    try {
      await _db.deleteTrip(id, ownerUserId: _currentOwnerId);
      await _deleteSyncedTrip(id);
      await loadTrips();
    } catch (e) {
      Logger.error('Error deleting trip', e);
      rethrow;
    }
  }

  Future<Trip?> getTripById(String id) async {
    if (!canManageTrips) return null;
    return await _db.getTripById(id, ownerUserId: _currentOwnerId);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _syncTripsToCloud(List<Trip> trips) async {
    if (!canManageTrips || !_firebaseService.isFirebaseAvailable) {
      return;
    }
    for (final trip in trips) {
      await _syncSingleTrip(trip);
    }
  }

  Future<void> _syncSingleTrip(Trip trip) async {
    if (!canManageTrips || !_firebaseService.isFirebaseAvailable) {
      return;
    }
    try {
      await _firebaseService.syncTrip(_currentOwnerId, trip.toJson());
    } catch (e, stackTrace) {
      Logger.error('Error syncing trip to Firestore', e, stackTrace);
    }
  }

  Future<void> _deleteSyncedTrip(String tripId) async {
    if (!canManageTrips || !_firebaseService.isFirebaseAvailable) {
      return;
    }
    try {
      await _firebaseService.deleteTrip(_currentOwnerId, tripId);
    } catch (e, stackTrace) {
      Logger.error('Error deleting synced trip from Firestore', e, stackTrace);
    }
  }

  Future<void> _adoptLegacyLocalTrips() async {
    if (!canManageTrips) {
      return;
    }
    try {
      await _db.assignOwnerToUnownedTrips(_currentOwnerId);
    } catch (e, stackTrace) {
      Logger.error('Error adopting legacy local trips', e, stackTrace);
    }
  }

  Future<List<Trip>> _loadTripsWithCloudSync() async {
    final localTrips = await _db.getAllTrips(ownerUserId: _currentOwnerId);

    if (!_firebaseService.isFirebaseAvailable) {
      return localTrips;
    }

    try {
      final remoteTrips = await _firebaseService.getTrips(_currentOwnerId);
      final localById = {for (final trip in localTrips) trip.id: trip};
      final remoteById = {for (final trip in remoteTrips) trip.id: trip};
      final allIds = {...localById.keys, ...remoteById.keys};
      final tripsToPush = <Trip>[];
      var didUpdateLocal = false;

      for (final tripId in allIds) {
        final localTrip = localById[tripId];
        final remoteTrip = remoteById[tripId];

        if (localTrip == null && remoteTrip != null) {
          await _db.insertTrip(remoteTrip);
          didUpdateLocal = true;
          continue;
        }

        if (remoteTrip == null && localTrip != null) {
          tripsToPush.add(localTrip);
          continue;
        }

        if (localTrip == null || remoteTrip == null) {
          continue;
        }

        if (remoteTrip.updatedAt.isAfter(localTrip.updatedAt)) {
          await _db.insertTrip(remoteTrip);
          didUpdateLocal = true;
        } else if (localTrip.updatedAt.isAfter(remoteTrip.updatedAt)) {
          tripsToPush.add(localTrip);
        }
      }

      if (tripsToPush.isNotEmpty) {
        await _syncTripsToCloud(tripsToPush);
      }

      if (!didUpdateLocal && tripsToPush.isEmpty) {
        return localTrips;
      }

      return await _db.getAllTrips(ownerUserId: _currentOwnerId);
    } catch (e, stackTrace) {
      Logger.error('Error syncing trips with Firestore', e, stackTrace);
      unawaited(_syncTripsToCloud(localTrips));
      return localTrips;
    }
  }
}
