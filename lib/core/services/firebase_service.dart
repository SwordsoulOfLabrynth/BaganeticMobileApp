import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart'
    show Firebase, FirebaseException;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import '../../data/models/trip_model.dart';
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
  static const _functionsRegion = String.fromEnvironment(
    'AI_FUNCTION_REGION',
    defaultValue: 'asia-southeast1',
  );

  firebase_auth.FirebaseAuth? get _authOrNull {
    if (!isFirebaseAvailable) {
      return null;
    }
    try {
      return firebase_auth.FirebaseAuth.instance;
    } catch (e, st) {
      Logger.error('FirebaseService: FirebaseAuth unavailable', e, st);
      return null;
    }
  }

  FirebaseFirestore? get _firestoreOrNull {
    try {
      return FirestoreInstance.instanceOrNull;
    } catch (e, st) {
      Logger.error('FirebaseService: Firestore unavailable', e, st);
      return null;
    }
  }

  firebase_storage.FirebaseStorage? get _storageOrNull {
    if (!isFirebaseAvailable) {
      return null;
    }
    try {
      return firebase_storage.FirebaseStorage.instance;
    } catch (e, st) {
      Logger.error('FirebaseService: Firebase Storage unavailable', e, st);
      return null;
    }
  }

  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  firebase_auth.User? get currentUser {
    try {
      return _authOrNull?.currentUser;
    } catch (e) {
      Logger.error('FirebaseService: Firebase not initialized', e);
      return null;
    }
  }

  Stream<firebase_auth.User?> get authStateChanges {
    try {
      final auth = _authOrNull;
      if (auth == null) {
        return Stream<firebase_auth.User?>.value(null);
      }
      return auth.authStateChanges();
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
      final auth = _requireAuth();
      return await auth.signInWithEmailAndPassword(
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
    String password, {
    String? displayName,
  }) async {
    try {
      final auth = _requireAuth();
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final initialUser = userCredential.user;
      if (initialUser == null) {
        throw AuthFailure('auth.unexpectedError');
      }
      firebase_auth.User user = initialUser;

      final normalizedDisplayName = displayName?.trim();
      if (normalizedDisplayName != null && normalizedDisplayName.isNotEmpty) {
        try {
          await user.updateDisplayName(normalizedDisplayName);
          await user.reload();
          final refreshedUser = auth.currentUser;
          if (refreshedUser != null) {
            user = refreshedUser;
          }
        } catch (e, st) {
          Logger.error(
            'FirebaseService: Failed to set display name during sign up',
            e,
            st,
          );
        }
      }

      try {
        await _createUserDocument(user);
      } catch (e, st) {
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
      }

      return userCredential;
    } catch (e, st) {
      final failure = _handleAuthException(e);
      Logger.error('FirebaseService: Sign up failed', e, st);
      throw failure;
    }
  }

  Future<void> signOut() async {
    final auth = _authOrNull;
    if (auth == null) {
      return;
    }
    await auth.signOut();
  }

  Future<void> deleteAccount({required String password}) async {
    try {
      final auth = _requireAuth();
      final user = auth.currentUser;
      final email = user?.email?.trim() ?? '';
      if (user == null || email.isEmpty) {
        throw AuthFailure('auth.failed');
      }

      final credential = firebase_auth.EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Account deletion spans profile data, community activity, AI usage, and
      // Storage. It must be performed by the trusted Cloud Function; a client
      // fallback can only remove part of that data and would incorrectly report
      // a completed deletion.
      await FirebaseFunctions.instanceFor(region: _functionsRegion)
          .httpsCallable(
            'deleteUserAccount',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 60),
            ),
          )
          .call();
    } catch (e, st) {
      final failure = _handleAuthException(e);
      Logger.error('FirebaseService: Delete account failed', e, st);
      throw failure;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      final auth = _requireAuth();
      await auth.sendPasswordResetEmail(email: email);
    } catch (e, st) {
      final failure = _handleAuthException(e);
      Logger.error('FirebaseService: Reset password failed', e, st);
      throw failure;
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    try {
      final auth = _requireAuth();
      final user = auth.currentUser;
      if (user == null) {
        throw AuthFailure('auth.failed');
      }

      final normalized = displayName.trim();
      await user.updateDisplayName(normalized);
      await user.reload();

      final firestore = _firestoreOrNull;
      if (firestore == null) {
        return;
      }

      try {
        await firestore.collection('users').doc(user.uid).set({
          'id': user.uid,
          'email': user.email,
          'displayName': normalized,
          'photoUrl': user.photoURL,
        }, SetOptions(merge: true));
      } catch (e, st) {
        Logger.error(
          'FirebaseService: Failed to sync display name to Firestore',
          e,
          st,
        );
      }
    } catch (e, st) {
      final failure = _handleAuthException(e);
      Logger.error('FirebaseService: Update display name failed', e, st);
      throw failure;
    }
  }

  Future<void> updateProfilePhoto(
    Uint8List bytes, {
    String? contentType,
  }) async {
    try {
      final auth = _requireAuth();
      final user = auth.currentUser;
      final storage = _storageOrNull;
      if (user == null || storage == null) {
        throw AuthFailure('profile.photoUploadFailed');
      }

      final reference = storage.ref().child('users/${user.uid}/profile.jpg');
      await reference.putData(
        bytes,
        firebase_storage.SettableMetadata(
          contentType: contentType ?? 'image/jpeg',
          cacheControl: 'public,max-age=86400',
        ),
      );
      final photoUrl = await reference.getDownloadURL();
      await user.updatePhotoURL(photoUrl);
      await user.reload();

      final firestore = _firestoreOrNull;
      if (firestore != null) {
        await firestore.collection('users').doc(user.uid).set({
          'id': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': photoUrl,
        }, SetOptions(merge: true));
      }
    } catch (e, st) {
      final failure = _handleAuthException(e);
      Logger.error('FirebaseService: Update profile photo failed', e, st);
      throw failure;
    }
  }

  Future<void> _createUserDocument(firebase_auth.User user) async {
    final firestore = _requireFirestore();
    final userModel = User(
      id: user.uid,
      email: user.email!,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
    );

    await firestore
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
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return null;
    }
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return User.fromJson(doc.data()!);
    } catch (e) {
      Logger.error('Error getting user data', e);
      return null;
    }
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    final firestore = _requireFirestore();
    await firestore.collection('users').doc(uid).update(data);
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
        case 'requires-recent-login':
          return AuthFailure('auth.requiresRecentLogin', cause: e);
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

  firebase_auth.FirebaseAuth _requireAuth() {
    final auth = _authOrNull;
    if (auth == null) {
      throw AuthFailure('auth.serviceUnavailable');
    }
    return auth;
  }

  FirebaseFirestore _requireFirestore() {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      throw AuthFailure('auth.serviceUnavailable');
    }
    return firestore;
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

  Future<void> syncFavorites(String uid, List<String> favoriteIds) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }
    await firestore.collection('users').doc(uid).set({
      'id': uid,
      'favoriteIds': favoriteIds,
    }, SetOptions(merge: true));
  }

  Future<List<String>> getFavoriteIds(String uid) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return const [];
    }
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) {
        return const [];
      }
      final ids = data['favoriteIds'];
      if (ids is List) {
        return ids.whereType<String>().where((id) => id.isNotEmpty).toList();
      }
    } catch (e, st) {
      Logger.error('FirebaseService: Failed to load favorite IDs', e, st);
    }
    return const [];
  }

  Future<void> syncTrip(String uid, Map<String, dynamic> tripData) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }
    await firestore
        .collection('users')
        .doc(uid)
        .collection('trips')
        .doc(tripData['id'])
        .set(tripData);
  }

  Future<List<Trip>> getTrips(String uid) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return const [];
    }
    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('trips')
        .get();

    final trips =
        snapshot.docs
            .map((doc) => Trip.fromJson({'id': doc.id, ...doc.data()}))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return trips;
  }

  Future<void> deleteTrip(String uid, String tripId) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }
    await firestore
        .collection('users')
        .doc(uid)
        .collection('trips')
        .doc(tripId)
        .delete();
  }
}
