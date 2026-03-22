import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseException;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';
import 'firestore_instance.dart';
import 'logger.dart';

class AuthFailure implements Exception {
  AuthFailure(this.code, {this.cause});

  final String code;
  final Object? cause;

  @override
  String toString() => 'AuthFailure($code)';
}

class FirebaseService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirestoreInstance.instance;

  // Auth methods
  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  firebase_auth.User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      Logger.error('FirebaseService: Firebase not initialized', e);
      return null;
    }
  }

  Stream<firebase_auth.User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (e) {
      Logger.error('FirebaseService: Firebase not initialized', e);
      return Stream.value(null);
    }
  }

  Future<firebase_auth.UserCredential> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      _ensureFirebaseAvailable();
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, st) {
      final failure = _handleAuthException(e);
      Logger.error('FirebaseService: Sign in failed', e, st);
      throw failure;
    }
  }

  Future<firebase_auth.UserCredential> signUpWithEmail(
    String email,
    String password,
  ) async {
    try {
      _ensureFirebaseAvailable();
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document
      final user = userCredential.user;
      if (user == null) {
        throw AuthFailure('auth.unexpectedError');
      }

      try {
        await _createUserDocument(user);
      } catch (e, st) {
        // Do not block sign up if profile creation fails.
        if (_isMissingFirestoreDatabase(e) ||
            (e is FirebaseException && e.code == 'deadline-exceeded')) {
          Logger.error(
            'FirebaseService: Firestore database is not configured for this project. '
            'Create a Firestore database in Firebase Console.',
            e,
            st,
          );
        } else {
          Logger.error('FirebaseService: Failed to create user profile', e, st);
        }
        // Continue with signup even if document creation fails
      }

      return userCredential;
    } catch (e, st) {
      final failure = _handleAuthException(e);
      Logger.error('FirebaseService: Sign up failed', e, st);
      throw failure;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      _ensureFirebaseAvailable();
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e, st) {
      final failure = _handleAuthException(e);
      Logger.error('FirebaseService: Reset password failed', e, st);
      throw failure;
    }
  }

  Future<void> _createUserDocument(firebase_auth.User user) async {
    final userModel = User(
      id: user.uid,
      email: user.email!,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
    );

    // Add timeout to prevent infinite hanging when Firestore database doesn't exist
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userModel.toJson())
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw FirebaseException(
              plugin: 'firebase_service',
              code: 'deadline-exceeded',
              message:
                  'Firestore operation timed out. The database may not be configured.',
            );
          },
        );
  }

  Future<User?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return User.fromJson(doc.data()!);
    } catch (e) {
      Logger.error('Error getting user data', e);
      return null;
    }
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  AuthFailure _handleAuthException(dynamic e) {
    if (e is AuthFailure) {
      return e;
    }
    if (e is firebase_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return AuthFailure('auth.userNotFound', cause: e);
        case 'wrong-password':
          return AuthFailure('auth.wrongPassword', cause: e);
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return AuthFailure('auth.invalidCredentials', cause: e);
        case 'email-already-in-use':
          return AuthFailure('auth.emailInUse', cause: e);
        case 'invalid-email':
          return AuthFailure('auth.invalidEmail', cause: e);
        case 'weak-password':
          return AuthFailure('auth.weakPassword', cause: e);
        case 'operation-not-allowed':
          return AuthFailure('auth.operationNotAllowed', cause: e);
        case 'user-disabled':
          return AuthFailure('auth.userDisabled', cause: e);
        case 'too-many-requests':
          return AuthFailure('auth.tooManyRequests', cause: e);
        case 'network-request-failed':
          return AuthFailure('auth.networkRequestFailed', cause: e);
        case 'missing-email':
          return AuthFailure('auth.emailRequired', cause: e);
        case 'missing-password':
          return AuthFailure('auth.passwordRequired', cause: e);
        default:
          return AuthFailure('auth.genericError', cause: e);
      }
    }
    if (e is FirebaseException) {
      switch (e.code) {
        case 'no-app':
        case 'app-not-authorized':
        case 'invalid-api-key':
          return AuthFailure('auth.serviceUnavailable', cause: e);
      }
    }
    return AuthFailure('auth.unexpectedError', cause: e);
  }

  void _ensureFirebaseAvailable() {
    if (!isFirebaseAvailable) {
      throw AuthFailure('auth.serviceUnavailable');
    }
  }

  bool _isMissingFirestoreDatabase(Object error) {
    if (error is! FirebaseException) {
      return false;
    }
    final message = (error.message ?? '').toLowerCase();
    return error.code == 'not-found' &&
        message.contains('database') &&
        message.contains('does not exist');
  }

  // Firestore sync methods
  Future<void> syncFavorites(String uid, List<String> favoriteIds) async {
    await _firestore.collection('users').doc(uid).update({
      'favoriteIds': favoriteIds,
    });
  }

  Future<void> syncTrip(String uid, Map<String, dynamic> tripData) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('trips')
        .doc(tripData['id'])
        .set(tripData);
  }

  Future<void> deleteTrip(String uid, String tripId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('trips')
        .doc(tripId)
        .delete();
  }
}
