import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../core/services/firebase_service.dart';
import '../../core/services/logger.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  firebase_auth.User? _user;
  bool _isLoading = false;
  String? _errorKey;
  String? _errorDetails;
  bool _isGuest = false;

  firebase_auth.User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorKey => _errorKey;
  String? get errorDetails => _errorDetails;
  bool get isGuest => _isGuest;
  bool get isAuthenticated => _user != null || _isGuest;

  AuthProvider() {
    try {
      _firebaseService.authStateChanges.listen((user) {
        _user = user;
        if (user != null) {
          _isGuest = false;
        }
        notifyListeners();
      });
    } catch (e) {
      // Firebase not initialized, user will be null (not authenticated)
      Logger.error(
        'AuthProvider: Firebase not available, treating as not authenticated',
        e,
      );
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorKey = null;
    _errorDetails = null;
    notifyListeners();

    var success = false;
    try {
      final credential = await _firebaseService.signInWithEmail(
        email,
        password,
      );
      _user = credential.user;
      _isGuest = false;
      _errorKey = null;
      _errorDetails = null;
      success = true;
    } on AuthFailure catch (e) {
      _setAuthFailure(e);
      Logger.error('Sign in error: ${e.code}', e.cause);
    } catch (e) {
      _errorKey = 'auth.failed';
      _errorDetails = e.toString();
      Logger.error('Sign in error: $_errorKey', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> signUp(String email, String password) async {
    _isLoading = true;
    _errorKey = null;
    _errorDetails = null;
    notifyListeners();

    var success = false;
    try {
      final credential = await _firebaseService.signUpWithEmail(
        email,
        password,
      );
      _user = credential.user;
      _isGuest = false;
      success = true;
    } on AuthFailure catch (e) {
      _setAuthFailure(e);
      Logger.error('Sign up error: ${e.code}', e.cause);
    } catch (e) {
      _errorKey = 'auth.failed';
      _errorDetails = e.toString();
      Logger.error('Sign up error: $_errorKey', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<void> signOut() async {
    try {
      await _firebaseService.signOut();
    } catch (e) {
      Logger.error('Sign out error', e);
    }
    _user = null;
    _isGuest = false;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _errorKey = null;
    _errorDetails = null;
    notifyListeners();

    try {
      await _firebaseService.resetPassword(email);
    } on AuthFailure catch (e) {
      _setAuthFailure(e);
      Logger.error('Reset password error: ${e.code}', e.cause);
    } catch (e) {
      _errorKey = 'auth.failed';
      _errorDetails = e.toString();
      Logger.error('Reset password error: $_errorKey', e);
    } finally {
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

  void _setAuthFailure(AuthFailure failure) {
    _errorKey = failure.code;
    _errorDetails = _formatAuthCause(failure.cause);
  }

  String? _formatAuthCause(Object? cause) {
    if (cause is firebase_auth.FirebaseAuthException) {
      final message = cause.message;
      if (message == null || message.trim().isEmpty) {
        return cause.code;
      }
      return '${cause.code}: ${message.replaceAll('\n', ' ').trim()}';
    }
    if (cause == null) {
      return null;
    }
    return cause.toString();
  }
}
