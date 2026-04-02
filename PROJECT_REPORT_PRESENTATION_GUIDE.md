# Baganetic Project Master Guide

Repository snapshot date: 2026-04-01

## 1. Project Identity

- Project name: Baganetic
- Academic title: Smart Route & Info Guide for Bagan Pagodas
- Project type: Flutter mobile application with an admin web portal
- Domain: Intelligent tourism, cultural heritage navigation, offline mobile computing
- Main purpose: Help users explore Bagan pagodas through offline-friendly browsing, route finding, trip planning, community knowledge sharing, and optional AI assistance

## 2. Executive Summary

Baganetic is a cross-platform Flutter application designed for tourists and general users exploring the Bagan archaeological zone. The project focuses on an offline-first user experience because internet connectivity in travel areas can be unstable. The app combines a local pagoda catalog, map-based exploration, route generation, trip planning, favorites, bilingual support, Firebase authentication, community interaction, and an optional AI assistant.

The current repository also includes an admin portal for managing pagoda catalog data and reviewing synced user, trip, and community information. This makes the project more than a simple mobile app; it is a small tourism information system with both user-facing and administrative components.

## 3. Problem Statement

Bagan is a large cultural heritage area with many important pagodas spread across a wide region. Visitors often face these problems:

- It is difficult to navigate efficiently between pagodas.
- Internet connectivity may be unreliable while traveling.
- Tourists need both cultural information and practical route guidance.
- Traditional map apps are not specialized for pagoda-focused travel.
- Travelers may want trip planning, saved places, and local tips in one place.

Baganetic addresses these problems by providing pagoda-focused navigation and information with strong local/offline support.

## 4. Main Objectives

The current codebase supports these core objectives:

1. Build a mobile-first tourism app for Bagan pagoda exploration.
2. Support offline-first access to pagoda data and route generation.
3. Provide map-based browsing and shortest-path style route support.
4. Let users create, edit, optimize, and save pagoda trips.
5. Provide pagoda details including historical and visitor information.
6. Support user accounts, favorites, and cloud-synced trip data.
7. Offer bilingual access in English and Myanmar.
8. Add a community layer for posts, comments, and upvotes.
9. Add an optional context-aware AI assistant for travel guidance.

## 5. Current Implemented Scope

### 5.1 Mobile App Features Confirmed In Code

- Home screen with featured pagodas and quick actions
- Pagoda list with search and category filtering
- Pagoda detail pages with image galleries, historical notes, visitor information, and unique features
- Favorites for signed-in users
- Map browsing with pagoda markers
- Offline tile caching for map data after first download
- Offline routing support using bundled graph data
- Shortest-path style route finding between selected pagodas
- Trip planner with:
  - pagoda selection
  - stop reordering
  - route optimization
  - distance estimation
  - trip detail view
  - screenshot export
  - share support
- Firebase email/password authentication
- Guest mode for non-authenticated use
- Community feed with:
  - posts
  - questions and tips
  - tag filtering
  - comments
  - upvotes
- AI chat screen with pagoda, trip, and community context
- English and Myanmar localization
- Responsive layouts for mobile, tablet, and desktop-sized screens

### 5.2 Admin Portal Features Confirmed In Code

The `admin/` folder contains a web-based admin console with:

- Admin login UI
- Dashboard with app statistics
- Pagoda management
- User overview
- Trip overview
- Community post moderation/inspection
- Pagoda create/edit modal
- Firestore-backed data snapshot and sync views

## 6. Features Planned In Earlier Documents But Not Fully Present In The Current UI

Earlier outline documents mention several larger modules. Based on the current repository, these should be described as future scope or planned work, not as fully completed features:

- Hotels and restaurants discovery
- Group chat or trip rooms
- Live location sharing
- Safety and emergency toolkit
- Real-time GPS navigation workflow
- Full road-reporting user interface

There is some supporting groundwork for road reports and AI context handling, but those modules are not exposed as complete end-user flows in the current mobile UI.

## 7. Technical Stack

### 7.1 Frontend / App Layer

- Flutter
- Dart SDK 3.10.x
- Provider for state management
- Material Design-based UI

### 7.2 Map And Routing

- `flutter_map`
- OpenStreetMap tile source
- `flutter_map_tile_caching`
- `latlong2`
- Custom offline route service
- Graph-based route support plus fallback route generation

### 7.3 Local Data Layer

- SQLite via `sqflite`
- `sqflite_common_ffi` for desktop compatibility
- Bundled JSON asset files
- Shared preferences for app settings such as language

### 7.4 Cloud / Backend Services

- Firebase Core
- Firebase Authentication
- Cloud Firestore

### 7.5 AI Integration

- Direct NVIDIA API call from Flutter
- Default model: `meta/llama-3.1-8b-instruct`

### 7.6 Utility Packages

- `http`
- `uuid`
- `screenshot`
- `share_plus`
- `path_provider`
- `intl`

## 8. Architecture Overview

The project follows a layered Flutter structure:

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
│   ├── repositories/
│   └── services/
├── models/
├── presentation/
│   ├── providers/
│   ├── screens/
│   └── widgets/
├── firebase_options.dart
└── main.dart
```

### 8.1 Layer Responsibilities

- `presentation/`: UI screens, widgets, and Provider-based state management
- `data/`: models, local datasource, and services for pagoda/community data
- `core/services/`: Firebase, offline map, offline route, AI chatbot, logging
- `core/utils/`: helper functions, responsive utilities, auth gating, pathfinding support

### 8.2 Main App Flow

1. App initializes Firebase if available.
2. SQLite/local storage is initialized.
3. Offline map tile caching backend is initialized.
4. Offline graph sync service starts.
5. Providers load pagoda, trip, auth, community, and language state.
6. Home screen becomes the default entry point.

## 9. Navigation Structure

The current main navigation tabs are:

1. Home
2. Pagodas
3. Map / Trips
4. Community
5. Profile

Additional screens include:

- Login screen
- Pagoda detail screen
- Create trip screen
- Trip detail screen
- Community post detail screen
- Create community post screen
- AI chat screen

## 10. Data Assets And Project Facts

These values were confirmed from the repository:

- Pagoda dataset file: `assets/data/sample_pagodas.json`
- Total pagoda records: 19
- Temple records: 10
- Pagoda records: 9
- Pagoda image folders: 19
- Offline road graph file: `assets/data/offline_graph.json`
- Offline road graph nodes: 7035
- Offline road graph edges: 7344
- Derived pagoda route graph file: `assets/data/pagoda_route_graph.json`
- Derived pagoda route graph nodes: 19
- Derived pagoda route graph edges: 29

This means the application uses both:

- a large road-level graph for route building
- a smaller pagoda-level route graph for pagoda-to-pagoda planning

## 11. Offline-First Strategy

Offline-first behavior is one of the strongest technical points of the project.

### 11.1 What Works Offline

- Local pagoda catalog
- Bundled pagoda images
- Stored favorites and trips in local SQLite
- Offline route graph loading
- Map tiles after they have been cached
- Local fallback AI history storage

### 11.2 Offline Design Decisions

- Pagoda content is seeded from bundled JSON assets
- SQLite is used for local persistence
- Map tiles are prefetched and cached locally
- Route generation reads from bundled graph data
- Firestore features degrade gracefully when Firebase is unavailable

### 11.3 Offline Limitations

- First-time tile download requires internet
- AI replies require a valid NVIDIA API key and internet access
- Cloud sync features need Firebase and Firestore

## 12. Authentication And User Roles

### 12.1 Guest User

Guest users can:

- open the app
- browse pagodas
- view map content
- inspect pagoda details

Guest users cannot fully use features that need ownership or sync, such as:

- favorites
- saved trips
- AI chat history sync
- post interaction that requires identity

### 12.2 Signed-In User

Signed-in users can:

- create an account with email and password
- sign in and sign out
- update display name
- save favorites
- create and manage trips
- use community interactions
- use the AI assistant
- sync selected data with Firestore

### 12.3 Admin

The admin portal provides administrative access for:

- dashboard review
- pagoda catalog management
- user/trip/community oversight

## 13. Firebase And Cloud Integration

Firebase is optional for launch, but required for several important features.

### 13.1 Firebase Is Used For

- email/password authentication
- user profile documents
- trip synchronization
- favorite synchronization
- AI chat message synchronization
- admin data views through the web admin panel

### 13.2 Firestore Notes

The repository already includes:

- `firestore.rules`
- `firestore.indexes.json`
- setup notes in `setup_firestore.md`
- setup summary in `FIRESTORE_SETUP_COMPLETE.md`

## 14. AI Assistant

The app includes an optional AI assistant that is grounded by project data.

### 14.1 AI Characteristics

- available only for signed-in users
- uses direct NVIDIA API calls
- can include pagoda context
- can include trip context
- can include community post context
- stores synced history in Firestore when available
- stores local fallback chat history in SQLite

### 14.2 AI Strength

This is not just a generic chatbot. The prompt-building flow is designed to include project-specific context from pagodas, trips, and community content, which makes the assistant more relevant to Bagan tourism use cases.

### 14.3 AI Constraints

- disabled unless `NVIDIA_API_KEY` is provided
- still depends on network availability
- should be described as optional, not core offline functionality

## 15. Trip Planning And Routing Logic

Trip planning is one of the most important functional modules in the project.

### 15.1 Trip Features

- create trip
- edit trip
- reorder pagoda stops
- optimize route order
- compute distance between stops
- show trip route on map
- export trip as image
- share trip

### 15.2 Routing Logic

The codebase uses:

- graph-aware distance estimation
- route building from offline graph data
- A*-style pathfinding support for pagoda-to-pagoda travel
- fallback route generation when graph routing is unavailable

### 15.3 Supporting Tooling

The repository contains a graph-generation script:

- `tool/generate_pagoda_route_graph.py`

This script helps produce pagoda routing artifacts from the dataset and topology sources.

## 16. Community Module

The community module adds social value to the application.

### 16.1 Current Community Features

- create tip posts
- create question posts
- search posts
- filter by type
- filter by tag
- sort by latest or helpful
- comment on posts
- upvote posts

### 16.2 Community Value

This gives the app a collaborative tourism dimension. Users can share advice and travel experiences, which improves usefulness beyond static content.

## 17. Localization And Accessibility

The project supports English and Myanmar:

- `assets/languages/en.json`
- `assets/languages/my.json`

This is important because the application targets both local and international users. The Myanmar localization file is extensive, which indicates serious effort toward bilingual support.

## 18. Admin Portal Summary

The admin portal is a significant extension of the project and is useful in presentations because it shows system-level thinking.

### 18.1 What The Admin Portal Demonstrates

- the system is manageable, not only user-facing
- data can be curated and monitored
- pagoda entries can be maintained through an interface
- user activity and community content can be reviewed

### 18.2 Admin Sections

- Dashboard
- Pagodas
- Users
- Trips
- Community

## 19. Strengths Of The Project

- Clear real-world use case tied to Bagan tourism
- Strong offline-first design
- Good combination of cultural content and technical navigation
- Cross-platform development with Flutter
- Practical local/cloud hybrid architecture
- Useful bilingual support
- Community and AI make the app more than a static catalog
- Admin portal improves maintainability and scalability

## 20. Current Limitations

- No automated test suite is currently checked in
- Some ambitious outline features are not yet fully implemented in the mobile UI
- AI depends on external API configuration
- Firebase-backed features depend on proper project setup
- Offline maps still require first-time internet download
- The project currently looks strongest on Android/mobile-first use, even though Flutter supports wider targets

## 21. Recommended Future Work

These are reasonable future enhancements that match the current repository direction:

1. Add a full nearby places module for hotels, restaurants, ATMs, and services.
2. Add real GPS tracking and live user location navigation.
3. Add complete road-report creation and viewing workflows in the mobile app.
4. Add stronger admin moderation features and role management.
5. Add analytics and evaluation dashboards.
6. Add automated widget, integration, and unit tests.
7. Improve trip optimization with richer constraints such as time, distance, and priority.
8. Add downloadable regional offline map packs.
9. Add image upload support for community posts.
10. Extend the system to other heritage regions in Myanmar.

## 22. Report-Ready Abstract

Baganetic, also titled Smart Route & Info Guide for Bagan Pagodas, is a Flutter-based intelligent tourism mobile application developed to support cultural exploration in the Bagan archaeological area. The system addresses practical travel challenges such as large geographic coverage, unreliable internet connectivity, and the need for both navigation and historical information in a single platform. The application combines a local pagoda dataset, offline-friendly map browsing, graph-based route generation, trip planning, favorites, Firebase authentication, community interaction, bilingual localization, and an optional AI assistant. The project also includes an admin web portal for managing catalog data and reviewing user-generated activity. Overall, the system demonstrates how offline-first mobile design, local data persistence, cloud synchronization, and context-aware assistance can be combined to create a practical tourism support platform for heritage environments.

## 23. Report-Ready Problem Statement

Tourists visiting Bagan often face difficulties navigating efficiently among many culturally significant pagodas spread across a large area. In addition, unstable internet access can reduce the usefulness of conventional navigation and tourism apps. There is therefore a need for a mobile application that provides pagoda-focused guidance, local information access, trip planning, and selective offline functionality in a way that is practical for real travel conditions.

## 24. Report-Ready Objectives Section

You can reuse the following wording:

1. To develop a mobile application for exploring Bagan pagodas.
2. To provide offline-friendly map access and route support.
3. To organize pagoda information in a searchable and user-friendly form.
4. To support personal trip planning and route optimization.
5. To integrate user accounts, favorites, and cloud synchronization.
6. To provide bilingual access in English and Myanmar.
7. To enrich the system through community interaction and optional AI assistance.

## 25. Methodology / Implementation Summary

The project was implemented using Flutter and Dart with Provider for state management. Local data persistence is handled through SQLite and bundled JSON assets, while Firebase Authentication and Cloud Firestore support cloud-based features when configured. OpenStreetMap is used for map rendering, and cached tiles improve offline usability. Routing support is built on graph-based data structures and offline graph files. The user interface is divided into pagoda browsing, map/trip planning, community interaction, and profile management modules. An additional admin web portal supports content management and system monitoring.

## 26. Suggested Presentation Outline

Use this as a slide sequence:

1. Title slide
   - Baganetic
   - Smart Route & Info Guide for Bagan Pagodas
2. Problem background
   - Bagan is large
   - internet can be unreliable
   - tourists need focused cultural navigation
3. Project objectives
4. System overview
   - mobile app
   - offline data
   - Firebase cloud features
   - admin portal
5. Main features
   - pagoda catalog
   - map and routing
   - trip planning
   - favorites
   - community
   - AI assistant
6. Technical architecture
   - Flutter + Provider
   - SQLite + JSON
   - Firebase
   - offline graph
7. Offline-first design
8. Admin portal
9. Strengths, limitations, and future work
10. Demo and conclusion

## 27. Demo Flow For Presentation

If you need a clean live demo, use this order:

1. Open Home screen and show featured pagodas.
2. Open Pagodas tab and demonstrate search/filter.
3. Open one pagoda detail page and explain historical/visitor information.
4. Open Map tab and show pagoda markers.
5. Demonstrate shortest path mode between two pagodas.
6. Create or open a trip and show route optimization.
7. Open Community tab and show posts/tags/comments.
8. Show Profile tab and explain favorites, trips, and language switching.
9. If configured, open AI chat and ask a Bagan-related question.
10. Show the admin portal as the management side of the system.

## 28. Viva / Presentation Talking Points

If someone asks "What is special about this project?", strong answers are:

- It is not only a tourism information app; it combines offline navigation, planning, community, and administration.
- It is specialized for Bagan rather than being a generic map app.
- It uses local data and offline graph support, which is important for real travel conditions.
- It balances local storage and cloud synchronization instead of depending only on the internet.
- It supports both end users and administrators.

If someone asks "What are the main innovations?", strong answers are:

- offline-first tourism support for a heritage site
- pagoda-focused route planning
- bilingual travel guidance
- context-aware AI assistant
- integrated admin portal

## 29. Setup And Build Notes

### 29.1 Basic Run

```bash
flutter pub get
flutter run
```

### 29.2 Run With AI

```bash
flutter run --dart-define-from-file=config/dart_defines.local.env
```

### 29.3 Validate

```bash
flutter analyze
```

### 29.4 Release Builds

```bash
flutter build apk --release
flutter build appbundle --release
```

## 30. Documentation References Inside The Repository

- `README.md`
- `SETUP.md`
- `setup_firestore.md`
- `FIRESTORE_SETUP_COMPLETE.md`
- `project_outline.md`
- `evaluation_matrix.md`
- `tool/generate_pagoda_route_graph.py`

## 31. Final Conclusion

Baganetic is a well-scoped intelligent tourism project centered on Bagan pagoda exploration. Its strongest qualities are its offline-first direction, focused cultural domain, structured mobile architecture, and hybrid use of local and cloud data. The project already demonstrates meaningful practical value through pagoda browsing, route support, trip planning, localization, and community interaction. With a few planned modules completed and stronger automated testing added, it can grow from a strong academic prototype into a more production-ready tourism platform.
