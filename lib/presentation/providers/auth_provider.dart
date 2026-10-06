import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/logger.dart';
import '../../data/datasources/local_datasource.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  firebase_auth.User? _user;
  bool _isLoading = false;
  String? _errorKey;
  String? _errorDetails;
  bool _isGuest = false;
  StreamSubscription<firebase_auth.User?>? _authSub;
  String? _localProfilePhotoPath;

  firebase_auth.User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorKey => _errorKey;
  String? get errorDetails => _errorDetails;
  bool get isGuest => _isGuest;
  bool get isAuthenticated => _user != null || _isGuest;
  String? get localProfilePhotoPath => _localProfilePhotoPath;

  AuthProvider() {
    try {
      _authSub = _firebaseService.authStateChanges.listen((user) {
        _user = user;
        if (user != null) {
          _isGuest = false;
          _localProfilePhotoPath = null;
          unawaited(_loadLocalProfilePhoto(user.uid));
        } else {
          _localProfilePhotoPath = null;
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
      await _loadLocalProfilePhoto(_user!.uid);
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

  Future<bool> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    _isLoading = true;
    _errorKey = null;
    _errorDetails = null;
    notifyListeners();

    var success = false;
    try {
      final credential = await _firebaseService.signUpWithEmail(
        email,
        password,
        displayName: displayName,
      );
      _user = credential.user;
      _isGuest = false;
      await _loadLocalProfilePhoto(_user!.uid);
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
    _localProfilePhotoPath = null;
    notifyListeners();
  }

  Future<bool> deleteAccount({required String password}) async {
    _isLoading = true;
    _errorKey = null;
    _errorDetails = null;
    notifyListeners();

    var success = false;
    final userId = _user?.uid;
    try {
      await _firebaseService.deleteAccount(password: password);
      if (userId != null && userId.isNotEmpty) {
        try {
          await DatabaseService().clearAccountData(userId);
        } catch (e, st) {
          Logger.error('Could not clear local account data', e, st);
        }
        try {
          final photo = File(
            '${(await getApplicationDocumentsDirectory()).path}'
            '${Platform.pathSeparator}profile_$userId.jpg',
          );
          if (await photo.exists()) {
            await photo.delete();
          }
          await (await SharedPreferences.getInstance()).remove(
            'profile_photo_path_$userId',
          );
        } catch (e, st) {
          Logger.error('Could not remove local profile photo', e, st);
        }
      }
      _user = null;
      _isGuest = false;
      _localProfilePhotoPath = null;
      success = true;
    } on AuthFailure catch (e) {
      _setAuthFailure(e);
      Logger.error('Delete account error: ${e.code}', e.cause);
    } catch (e) {
      _errorKey = 'profile.deleteAccountFailed';
      _errorDetails = e.toString();
      Logger.error('Delete account error: $_errorKey', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return success;
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

  Future<bool> updateDisplayName(String displayName) async {
    _isLoading = true;
    _errorKey = null;
    _errorDetails = null;
    notifyListeners();

    var success = false;
    try {
      await _firebaseService.updateDisplayName(displayName);
      _user = _firebaseService.currentUser;
      success = true;
    } on AuthFailure catch (e) {
      _setAuthFailure(e);
      Logger.error('Update display name error: ${e.code}', e.cause);
    } catch (e) {
      _errorKey = 'auth.failed';
      _errorDetails = e.toString();
      Logger.error('Update display name error: $_errorKey', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> updateProfilePhoto(
    Uint8List bytes, {
    String? contentType,
  }) async {
    _isLoading = true;
    _errorKey = null;
    _errorDetails = null;
    notifyListeners();

    var success = false;
    try {
      await _saveLocalProfilePhoto(bytes);
      success = true;

      // A profile picture should still work on a trip with no connection.
      // Firebase Storage is only used to keep that local picture in sync on
      // other devices; a failed sync must not discard the selected photo.
      try {
        await _firebaseService.updateProfilePhoto(
          bytes,
          contentType: contentType,
        );
        _user = _firebaseService.currentUser;
      } catch (e, st) {
        Logger.error(
          'Update profile photo cloud sync failed; local photo was saved',
          e,
          st,
        );
      }
    } catch (e) {
      _errorKey = 'profile.photoUploadFailed';
      _errorDetails = e.toString();
      Logger.error('Update profile photo error: $_errorKey', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<void> _loadLocalProfilePhoto(String userId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final standardFile = File(
        '${directory.path}${Platform.pathSeparator}profile_$userId.jpg',
      );
      final preferences = await SharedPreferences.getInstance();
      String? validPath;
      if (await standardFile.exists()) {
        validPath = standardFile.path;
      } else {
        final path = preferences.getString('profile_photo_path_$userId');
        if (path != null && await File(path).exists()) {
          validPath = path;
        }
      }

      if (validPath == null) {
        return;
      }

      if (_user?.uid == userId && _localProfilePhotoPath != validPath) {
        _localProfilePhotoPath = validPath;
        if (preferences.getString('profile_photo_path_$userId') != validPath) {
          await preferences.setString(
            'profile_photo_path_$userId',
            validPath,
          );
        }
        notifyListeners();
      }
    } catch (e, st) {
      Logger.error('Could not load local profile photo', e, st);
    }
  }

  Future<void> _saveLocalProfilePhoto(Uint8List bytes) async {
    final user = _user ?? _firebaseService.currentUser;
    if (user == null) {
      throw AuthFailure('auth.failed');
    }
    final directory = await getApplicationDocumentsDirectory();
    final photo = File(
      '${directory.path}${Platform.pathSeparator}profile_${user.uid}.jpg',
    );
    await photo.writeAsBytes(bytes, flush: true);
    await (await SharedPreferences.getInstance()).setString(
      'profile_photo_path_${user.uid}',
      photo.path,
    );
    _localProfilePhotoPath = photo.path;
  }

  void setGuestMode() {
    _isGuest = true;
    notifyListeners();
  }

  void exitGuestMode() {
    _isGuest = false;
    notifyListeners();
  }

  void clearError() {
    if (_errorKey == null && _errorDetails == null) {
      return;
    }
    _errorKey = null;
    _errorDetails = null;
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

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
