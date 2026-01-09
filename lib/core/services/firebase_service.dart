import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';

class FirebaseService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth methods
  firebase_auth.User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      print('FirebaseService: Firebase not initialized: $e');
      return null;
    }
  }

  Stream<firebase_auth.User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (e) {
      print('FirebaseService: Firebase not initialized: $e');
      return Stream.value(null);
    }
  }
  
  Future<firebase_auth.UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      final errorMessage = _handleAuthException(e);
      throw Exception(errorMessage);
    }
  }

  Future<firebase_auth.UserCredential> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document
      await _createUserDocument(userCredential.user!);

      return userCredential;
    } catch (e) {
      final errorMessage = _handleAuthException(e);
      throw Exception(errorMessage);
    }
  }
  
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      final errorMessage = _handleAuthException(e);
      throw Exception(errorMessage);
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

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userModel.toJson());
  }
  
  Future<User?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return User.fromJson(doc.data()!);
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
  
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }
  
  String _handleAuthException(dynamic e) {
    if (e is firebase_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        default:
          return 'Authentication error: ${e.message}';
      }
    }
    return 'An unexpected error occurred.';
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
}
