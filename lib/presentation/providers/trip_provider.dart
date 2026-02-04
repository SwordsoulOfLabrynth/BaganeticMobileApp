import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../data/models/trip_model.dart';
import '../../data/datasources/local_datasource.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/logger.dart';

class TripProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

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
    _authSub = _auth.authStateChanges().listen((user) {
      final nextOwnerId = _resolveOwnerId(user);
      if (nextOwnerId == _currentOwnerId) {
        return;
      }
      _currentOwnerId = nextOwnerId;
      loadTrips();
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
      _trips = await _db.getAllTrips(ownerUserId: _currentOwnerId);
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
}
