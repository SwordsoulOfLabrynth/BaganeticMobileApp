import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBCPoRPdPB6p74PmXqTJrjh4z_BdPDiVhs',
    appId: '1:1076087639842:android:1b6a0aa3b4e9497428df7b',
    messagingSenderId: '1076087639842',
    projectId: 'baganetic-mobile',
    storageBucket: 'baganetic-mobile.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBCPoRPdPB6p74PmXqTJrjh4z_BdPDiVhs',
    appId: '1:1076087639842:ios:1b6a0aa3b4e9497428df7b',
    messagingSenderId: '1076087639842',
    projectId: 'baganetic-mobile',
    storageBucket: 'baganetic-mobile.firebasestorage.app',
    iosBundleId: 'com.baganetic.baganeticMobile',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBCPoRPdPB6p74PmXqTJrjh4z_BdPDiVhs',
    appId: '1:1076087639842:web:1b6a0aa3b4e9497428df7b',
    messagingSenderId: '1076087639842',
    projectId: 'baganetic-mobile',
    storageBucket: 'baganetic-mobile.firebasestorage.app',
    authDomain: 'baganetic-mobile.firebaseapp.com',
    measurementId: 'G-XXXXXXXXXX', // Optional: Add if using Analytics
  );
}
