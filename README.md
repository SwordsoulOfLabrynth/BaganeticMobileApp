# Baganetic Mobile (Flutter App)

Baganetic is a mobile app for exploring Bagan pagodas with an offline-first
experience, pagoda information, and trip planning.

Project status: Mid-term prototype. Implemented features are stable; advanced
modules are planned and not yet integrated into the UI.

## Implemented Features
- Pagodas directory with categories, search, and filters
- Pagoda detail pages with local image assets
- Favorites stored locally
- Interactive map (OpenStreetMap via flutter_map) with offline tile caching
- Trip planner: create trips, reorder stops, and optimize routes
  - A* routing for two stops
  - Nearest-neighbor ordering for three or more stops
- Route rendering on the map using an offline graph with fallback routing
- Local database (SQLite) for pagodas, trips, and favorites
- Firebase email/password authentication plus guest mode
- Signed-in AI travel assistant grounded with pagoda, trip, and road context
- Pagoda-linked road safety reports
- Bilingual UI (English and Myanmar)

## Future Work
- Community tips and Q/A feed
- Safety and emergency toolkit
- Cloud sync for trips and favorites
- GPS live tracking and turn-by-turn guidance
- Admin tools for managing pagoda/POI data

## Tech Stack
- Flutter SDK (Dart >= 3.10.1 per pubspec)
- State management: Provider
- Local database: SQLite (sqflite)
- Auth: Firebase Authentication
- Maps: flutter_map with OpenStreetMap tiles
- Offline tiles: flutter_map_tile_caching
- Routing: A* (pagoda graph) + offline route graph rendering
- AI chat: direct NVIDIA API call from Flutter for demo builds
- Sharing: screenshot + share_plus

## Requirements
- Flutter SDK with Dart 3.10.1 or higher
- Android Studio / VS Code

## Setup

Install dependencies:
```bash
flutter pub get
```

Firebase (optional for auth):
- Android: place `google-services.json` in `android/app/`
- iOS: place `GoogleService-Info.plist` in `ios/Runner/`
- Ensure `lib/firebase_options.dart` matches your Firebase project.
- If Firebase is not configured, the app still works in guest mode.

Run the app:
```bash
flutter run
```

Run with AI enabled:
```bash
flutter run --dart-define=NVIDIA_API_KEY=your_nvidia_key --dart-define=NVIDIA_MODEL=meta/llama-3.1-8b-instruct
```

Without `NVIDIA_API_KEY`, the rest of the app still works but AI chat stays disabled.

Use a local ignored config file for team development:
1. Copy `config/dart_defines.example.env` to `config/dart_defines.local.env`
2. Set your own `NVIDIA_API_KEY`
3. Run from the command line with:
```bash
flutter run --dart-define-from-file=config/dart_defines.local.env
```
4. Or use the IDE Run icon:
   Android Studio uses the shared `main.dart` run configuration in `.idea/runConfigurations/main_dart.xml`
   VS Code can use the `main.dart (Local AI)` launch config in `.vscode/launch.json`

Hot reload still works for normal code changes. If you change `NVIDIA_API_KEY` or `NVIDIA_MODEL`, stop and run again because `String.fromEnvironment` values are loaded at app start.

## Data and Offline Behavior
- Sample pagoda data lives in `assets/data/sample_pagodas.json` and is loaded
  into SQLite on first launch.
- Offline route graph is bundled in `assets/data/offline_graph.json`.
  `AppConstants.offlineGraphUrl` is empty by default; set it to a hosted JSON
  if you want periodic graph updates.
- Map tiles are cached locally. The first launch needs internet to download
  tiles; cached areas are available offline afterward.

## App Structure
Screens included:
1. Splash
2. Login / Signup (optional, guest mode supported)
3. Home (tabs: Home, Pagodas, Map, Profile)
4. Pagoda Detail
5. Create Trip
6. Trip Detail

## Architecture
```
lib/
├── core/
│   ├── constants/     # App constants
│   ├── localization/  # Localization helpers
│   ├── services/      # Firebase, offline routing, and planned services
│   ├── theme/         # App theme
│   └── utils/         # Helpers, pathfinding
├── data/
│   ├── datasources/   # Local database + migrations
│   ├── models/        # Pagoda, Trip, User
│   └── services/      # Data loading utilities
├── presentation/
│   ├── providers/     # State management (Provider)
│   ├── screens/       # UI screens
│   └── widgets/       # Reusable widgets
└── main.dart
```

Note: Some services (cloud sync helpers) are scaffolding for planned
features and are not wired into the current UI.

## Database Schema (SQLite)

**pagodas**
```
id, name, description, category, latitude, longitude,
imageUrl, images, historicalInfo, architecturalStyle,
yearBuilt, isFavorite
```

**trips**
```
id, name, description, date, createdAt, updatedAt
```

**trip_stops**
```
id, tripId, pagodaId, pagodaName, latitude, longitude,
orderIndex, notes, distanceToNext
```

**favorites**
```
pagodaId, addedAt
```

## Routing Logic
- Trip optimization uses A* for two pagodas and nearest-neighbor for three or more.
- Map route rendering uses the offline graph when available, with curved fallback
  when a graph path is not found.

## Localization
- Language files are in `assets/languages/en.json` and `assets/languages/my.json`.
- Language can be switched from the Profile screen.

## Testing
No automated tests are included yet.

## Building for Production

Android APK:
```bash
flutter build apk --release
```

Android App Bundle:
```bash
flutter build appbundle --release
```

## Troubleshooting
- Firebase not initialized: ensure Firebase config files are in place, or use
  guest mode.
- Map tiles not loading: check connectivity for initial tile download.
- Database issues: clear app data and reinstall.

## Acknowledgments
- OpenStreetMap contributors
- Flutter community packages
