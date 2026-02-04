import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TestFirebaseApp());
}

class TestFirebaseApp extends StatelessWidget {
  const TestFirebaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const TestFirebaseScreen());
  }
}

class TestFirebaseScreen extends StatefulWidget {
  const TestFirebaseScreen({super.key});

  @override
  State<TestFirebaseScreen> createState() => _TestFirebaseScreenState();
}

class _TestFirebaseScreenState extends State<TestFirebaseScreen> {
  String _status = 'Testing Firebase connection...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  Future<void> _testFirebase() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing Firebase...';
    });

    try {
      // Test Firestore connection only (skip auth for now)
      setState(() {
        _status = 'Testing Firestore connection...';
      });
      final firestore = FirebaseFirestore.instance;

      // Try to read a test document
      final testDoc = await firestore
          .collection('test')
          .doc('connection_test')
          .get();
      debugPrint(
        'Firestore connection successful. Test document exists: ${testDoc.exists}',
      );

      // Try to write a test document
      setState(() {
        _status = 'Testing Firestore write...';
      });
      await firestore.collection('test').doc('connection_test').set({
        'message': 'Firebase connection test successful',
        'timestamp': DateTime.now(),
        'test': true,
      });
      debugPrint('Firestore write successful');

      setState(() {
        _status =
            'Firestore test completed successfully! Firebase is connected but Authentication may need to be enabled in Firebase Console.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Firebase test failed: $e';
        _isLoading = false;
      });
      debugPrint('Firebase test error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else
                const Icon(Icons.check_circle, color: Colors.green, size: 50),
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
