# Baganetic Mobile

Baganetic is a Flutter app for exploring Bagan pagodas with an offline-first
focus. The current app combines local pagoda data, map browsing, trip planning,
Firebase auth, road safety reports, and an optional AI travel assistant.

## Current Features

- Pagoda browsing with search, filters, favorites, and rich detail pages
- Local pagoda data and bundled image assets
- Interactive map built with `flutter_map`
- Offline tile caching and offline route graph support
- Trip planning from the map and pagoda detail flows
- Guest mode plus Firebase email/password sign-in
- Road reports tied to individual pagodas
- Signed-in AI assistant with pagoda, trip, and road-context grounding
- English and Myanmar localization

## Current Navigation

The main app navigation currently includes:

1. Home
2. Pagodas
3. Map / Trips
4. Profile

Trip creation and trip detail screens are launched from the map screen and
pagoda detail actions. There is no separate splash screen in the current app
flow.

## Requirements

- Flutter SDK compatible with Dart `3.10.x`
- Android Studio or VS Code with Flutter support
- Firebase project only if you want auth, road reports, or synced AI history
- NVIDIA API key only if you want live AI replies

## Quick Start

Install dependencies:

```bash
flutter pub get
```

Optional local AI config:

1. Copy `config/dart_defines.example.env` to
   `config/dart_defines.local.env`
2. Set `NVIDIA_API_KEY`
3. Run:

```bash
flutter run --dart-define-from-file=config/dart_defines.local.env
```

Run without AI:

```bash
flutter run
```

## Firebase Setup

Firebase is optional. Without it, the app still launches and guest-mode flows
work, but email/password auth, road reports, and synced AI chat history are not
available.

- Android: place `google-services.json` in `android/app/`
- iOS: place `GoogleService-Info.plist` in `ios/Runner/` if you build for iOS
- Ensure `lib/firebase_options.dart` matches your Firebase project
- Enable Email/Password authentication in Firebase Console
- Create a Firestore database before using sign-in, road reports, or AI history

See `SETUP.md` for the full setup flow and `setup_firestore.md` for Firestore
notes.

## AI Assistant

The AI assistant uses direct NVIDIA API calls from Flutter. It stays disabled
unless `NVIDIA_API_KEY` is provided at launch time.

Default model:

```text
meta/llama-3.1-8b-instruct
```

You can override it with `NVIDIA_MODEL` in the same dart-define file.

## Data and Offline Behavior

- `assets/data/sample_pagodas.json` seeds pagoda content into SQLite
- `assets/data/offline_graph.json` is bundled for offline route generation
- Map tiles are cached locally after first download
- `AppConstants.offlineGraphUrl` is empty by default, so graph updates are
  local-only unless you configure a hosted graph source

## Project Layout

```text
lib/
├── core/
│   ├── constants/
│   ├── localization/
│   ├── services/
│   ├── theme/
│   └── utils/
├── data/
│   ├── datasources/
│   ├── models/
│   └── services/
├── models/
│   └── user.dart
├── presentation/
│   ├── providers/
│   ├── screens/
│   └── widgets/
├── firebase_options.dart
└── main.dart
```

## Validation

Current baseline validation:

```bash
flutter analyze
```

No automated test suite is checked in yet.

## Build

Android APK:

```bash
flutter build apk --release
```

Android App Bundle:

```bash
flutter build appbundle --release
```

## Troubleshooting

- If Firebase fails to initialize, verify the platform config files and
  `lib/firebase_options.dart`
- If sign-up hangs or Firestore-backed features fail, create the Firestore
  database in Firebase Console
- If cached or generated assets behave strangely after changes, run:

```bash
flutter clean
flutter pub get
```

- If map tiles do not load on a fresh install, verify internet access for the
  first tile download

## References

- `SETUP.md` for a full project setup guide
- `setup_firestore.md` for Firestore database setup
- `FIRESTORE_SETUP_COMPLETE.md` for Firestore notes and verification commands
