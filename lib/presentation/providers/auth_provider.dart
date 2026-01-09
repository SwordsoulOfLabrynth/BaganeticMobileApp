import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isGuest = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isGuest => _isGuest;
  bool get isAuthenticated => _user != null || _isGuest;

  AuthProvider() {
    try {
      _firebaseService.authStateChanges.listen((user) {
        _user = user;
        notifyListeners();
      });
    } catch (e) {
      // Firebase not initialized, user will be null (not authenticated)
      print('AuthProvider: Firebase not available, treating as not authenticated: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.signInWithEmail(email, password);
      _isLoading = false;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      // Extract error message from Exception
      if (e is Exception) {
        _error = e.toString().replaceFirst('Exception: ', '');
      } else {
        _error = 'Authentication failed. Please check your email and password.';
      }
      _isLoading = false;
      notifyListeners();
      print('Sign in error: $_error');
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.signUpWithEmail(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.resetPassword(email);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void setGuestMode() {
    _isGuest = true;
    notifyListeners();
  }

  void exitGuestMode() {
    _isGuest = false;
    notifyListeners();
  }
}
