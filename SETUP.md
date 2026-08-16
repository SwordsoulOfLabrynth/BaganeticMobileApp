# Baganetic Mobile Setup Guide

This guide reflects the current Flutter app in this repository.

## Prerequisites

- Flutter SDK with Dart `3.10.x`
- Android Studio or VS Code with Flutter support
- A connected device or emulator
- Firebase project only if you want auth, road reports, or synced AI history
- Firebase Functions setup only if you want live AI replies

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

The app can run without AI. Live AI replies use the `generateAiReply` Firebase
Function so the NVIDIA key never enters a mobile build.

1. Install the Function dependencies:

```bash
npm --prefix functions install
```

2. Set the secret interactively. Do not put it in a Dart define, source file,
or Git repository:

```bash
firebase functions:secrets:set NVIDIA_API_KEY
```

3. Deploy the Function with the rules:

```bash
firebase deploy --only functions,firestore:rules,storage
```

The Function defaults to `asia-southeast1`. If you deploy it elsewhere, copy
`config/dart_defines.example.env` to `config/dart_defines.local.env`, set
`AI_FUNCTION_REGION`, and run with `--dart-define-from-file`.

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

## 5. Validate the Setup

Run the automated checks:

```bash
flutter analyze
flutter test
```

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

- Make sure you are signed in
- Run `firebase functions:list` and confirm `generateAiReply` is deployed
- Confirm the `NVIDIA_API_KEY` Functions secret was set in the same Firebase project
- Confirm the app and Function use the same `AI_FUNCTION_REGION`

### Asset or generated file issues

```bash
flutter clean
flutter pub get
```

### Map tiles do not appear on a fresh install

The first tile download needs internet access. Cached areas continue to work
offline after download.

## 9. Build Commands

Before a release build, create a keystore and copy
`android/key.properties.example` to `android/key.properties`. Keep both the
keystore and real properties file out of Git.

Android APK:

```bash
flutter build apk --release
```

Android App Bundle:

```bash
flutter build appbundle --release
```
