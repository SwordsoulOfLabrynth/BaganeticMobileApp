# Baganetic Mobile Setup Guide

This guide reflects the current Flutter app in this repository.

## Prerequisites

- Flutter SDK with Dart `3.10.x`
- Android Studio or VS Code with Flutter support
- A connected device or emulator
- Firebase project only if you want auth, road reports, or synced AI history
- NVIDIA API key only if you want live AI replies

Verify your toolchain:

```bash
flutter doctor
```

## 1. Install Dependencies

From the repository root:

```bash
flutter pub get
```

## 2. Optional AI Configuration

The app can run without AI. To enable the assistant:

1. Copy `config/dart_defines.example.env` to
   `config/dart_defines.local.env`
2. Set your values:

```text
NVIDIA_API_KEY=your_key_here
NVIDIA_MODEL=meta/llama-3.1-8b-instruct
```

3. Run the app with:

```bash
flutter run --dart-define-from-file=config/dart_defines.local.env
```

If `NVIDIA_API_KEY` is blank, the assistant UI can still appear, but live AI
responses stay disabled.

## 3. Optional Firebase Configuration

Firebase is not required for basic guest-mode browsing. It is required for:

- Email/password sign-in
- Firestore-backed road reports
- Synced AI chat history

### Android

1. Create or open your Firebase project
2. Add an Android app with package name:

```text
com.baganetic.baganetic_mobile
```

3. Download `google-services.json`
4. Place it at:

```text
android/app/google-services.json
```

### iOS

If you plan to build for iOS:

1. Add an iOS app in Firebase Console
2. Download `GoogleService-Info.plist`
3. Place it at:

```text
ios/Runner/GoogleService-Info.plist
```

### Firebase Options

Ensure `lib/firebase_options.dart` matches the Firebase project you want to use.

### Required Firebase Services

Enable these services in Firebase Console:

- Authentication -> Email/Password
- Firestore Database

For Firestore-specific setup notes, see `setup_firestore.md`.

## 4. Run the App

Standard run:

```bash
flutter run
```

Run with local AI config:

```bash
flutter run --dart-define-from-file=config/dart_defines.local.env
```

## 5. Validate the Setup

Use static analysis as the current baseline check:

```bash
flutter analyze
```

No automated test suite is currently checked into this repository.

## 6. Current Project Structure

```text
baganetic_mobile/
├── android/
├── ios/
├── lib/
│   ├── core/
│   ├── data/
│   ├── models/
│   ├── presentation/
│   ├── firebase_options.dart
│   └── main.dart
├── assets/
├── config/
├── pubspec.yaml
├── README.md
└── SETUP.md
```

## 7. Current App Behavior

- Main navigation: Home, Pagodas, Map / Trips, Profile
- Trip creation lives inside map and pagoda detail flows
- Guest mode works without Firebase
- Pagoda content is seeded from `assets/data/sample_pagodas.json`
- Offline graph data is bundled in `assets/data/offline_graph.json`
- Map tiles are cached after first download

## 8. Troubleshooting

### Firebase not initialized

- Confirm `android/app/google-services.json` exists for Android
- Confirm `ios/Runner/GoogleService-Info.plist` exists for iOS builds
- Confirm `lib/firebase_options.dart` matches the same project

### Firestore-backed features fail

If sign-up, road reports, or synced AI history fail, create the Firestore
database in Firebase Console and publish rules that match the current app scope.

### AI assistant does not respond

- Confirm `NVIDIA_API_KEY` is set
- Relaunch the app after changing dart-defines
- Make sure you are signed in before using synced AI history

### Asset or generated file issues

```bash
flutter clean
flutter pub get
```

### Map tiles do not appear on a fresh install

The first tile download needs internet access. Cached areas continue to work
offline after download.

## 9. Build Commands

Android APK:

```bash
flutter build apk --release
```

Android App Bundle:

```bash
flutter build appbundle --release
```
