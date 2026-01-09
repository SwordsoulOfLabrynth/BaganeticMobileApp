import 'package:flutter/material.dart';
import '../../data/models/trip_model.dart';
import '../../data/datasources/local_datasource.dart';

class TripProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  
  List<Trip> _trips = [];
  bool _isLoading = false;
  
  List<Trip> get trips => _trips;
  bool get isLoading => _isLoading;
  
  TripProvider() {
    loadTrips();
  }
  
  Future<void> loadTrips() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _trips = await _db.getAllTrips();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading trips: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> saveTrip(Trip trip) async {
    try {
      await _db.insertTrip(trip);
      await loadTrips();
    } catch (e) {
      print('Error saving trip: $e');
      rethrow;
    }
  }
  
  Future<void> deleteTrip(String id) async {
    try {
      await _db.deleteTrip(id);
      await loadTrips();
    } catch (e) {
      print('Error deleting trip: $e');
      rethrow;
    }
  }
  
  Future<Trip?> getTripById(String id) async {
    return await _db.getTripById(id);
  }
}
