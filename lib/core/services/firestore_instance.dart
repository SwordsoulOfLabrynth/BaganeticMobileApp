import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;

class FirestoreInstance {
  FirestoreInstance._();

  static const String _databaseId = String.fromEnvironment(
    'FIRESTORE_DATABASE_ID',
    defaultValue: 'baganetic-mobile',
  );

  static String get configuredDatabaseId => _databaseId.trim();

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
