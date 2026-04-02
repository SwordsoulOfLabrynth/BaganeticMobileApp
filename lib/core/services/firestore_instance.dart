import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;

class FirestoreInstance {
  FirestoreInstance._();

  static const String _databaseId = String.fromEnvironment(
    'FIRESTORE_DATABASE_ID',
    defaultValue: 'baganetic-mobile',
  );

  static String get configuredDatabaseId => _databaseId.trim();

  static bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static FirebaseFirestore? get instanceOrNull {
    if (!isAvailable) {
      return null;
    }
    try {
      return instance;
    } catch (_) {
      return null;
    }
  }

  static FirebaseFirestore get instance {
    final configuredId = configuredDatabaseId;
    if (configuredId.isEmpty) {
      return FirebaseFirestore.instance;
    }
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: configuredId,
    );
  }
}
