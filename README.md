# 🏛️ Baganetic Mobile - Flutter App

**Baganetic** is a comprehensive mobile application for exploring Bagan's ancient pagodas with **offline-first** architecture, interactive maps, and intelligent trip planning.

## ✨ Features

### 📱 Core Features (MVP)
- **Pagodas Directory**: Browse, search, and filter 2000+ pagodas
- **Categories**: Temple, Pagoda, Stupa, Monastery
- **Search & Filter**: Find pagodas by name or description
- **Favorites**: Save your favorite pagodas
- **Pagoda Details**: Comprehensive information with images
- **Interactive Map**: OpenStreetMap with pagoda markers
- **Trip Planner** ⭐ (Killer Feature):
  - Create custom itineraries
  - Add multiple pagodas
  - A* pathfinding for optimal routes
  - Route optimization (nearest neighbor)
  - Distance & duration calculation
  - Reorder stops with drag-and-drop
  - Export/share trip screenshots
- **Firebase Authentication**: Secure login/signup
- **Offline-First**: SQLite local database

### 🔮 Phase 2 (Future)
- AI Chatbot (LLM-powered with provider abstraction)
- Cloud sync with Firestore
- Group trip planning
- Multilingual support (Myanmar)

## 🏗️ Architecture

### Clean Architecture
```
lib/
├── core/
│   ├── constants/     # App constants
│   ├── theme/         # App theme
│   ├── utils/         # Helper functions, pathfinding
│   └── services/      # Firebase, Database, LLM services
├── data/
│   ├── models/        # Data models (Pagoda, Trip, User)
│   └── datasources/   # Local & remote data sources
├── presentation/
│   ├── providers/     # State management (Provider)
│   ├── screens/       # UI screens
│   └── widgets/       # Reusable widgets
└── main.dart
```

### Tech Stack
- **Framework**: Flutter 3.38.5 with Dart
- **State Management**: Provider
- **Local Database**: SQLite (sqflite)
- **Auth**: Firebase Authentication
- **Cloud**: Cloud Firestore (for sync)
- **Maps**: flutter_map with OpenStreetMap
- **Algorithm**: A* pathfinding

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.10.0 or higher
- Dart SDK 3.10.4 or higher
- Android Studio / VS Code
- Firebase account (for authentication)

### Installation

1. **Clone the repository**
```bash
cd /app/baganetic_mobile
```

2. **Install dependencies**
```bash
export PATH="$PATH:/tmp/flutter/bin"
flutter pub get
```

3. **Configure Firebase**
- Create a Firebase project at https://console.firebase.google.com
- Add Android/iOS apps to your Firebase project
- Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
- Place them in the appropriate directories:
  - Android: `android/app/google-services.json`
  - iOS: `ios/Runner/GoogleService-Info.plist`
- Update `lib/firebase_options.dart` with your Firebase configuration

4. **Setup Emergent LLM Key (for chatbot)**
- Get your Emergent LLM key from the environment
- The app uses provider abstraction supporting OpenAI, Gemini, and Claude

5. **Run the app**
```bash
flutter run
```

## 📱 App Structure

### Screens
1. **Splash Screen**: App initialization
2. **Login/Signup**: Firebase authentication
3. **Home Screen**: Bottom navigation with 4 tabs
   - Pagodas List
   - Map
   - Trips
   - Profile
4. **Pagoda Detail**: Full pagoda information
5. **Create Trip**: Trip planner with route optimization
6. **Trip Detail**: View itinerary with map and export

### Database Schema (SQLite)

**pagodas**
```sql
id, name, description, category, latitude, longitude, 
imageUrl, images, historicalInfo, architecturalStyle, 
yearBuilt, isFavorite
```

**trips**
```sql
id, name, description, date, createdAt, updatedAt
```

**trip_stops**
```sql
id, tripId, pagodaId, pagodaName, latitude, longitude, 
orderIndex, notes, distanceToNext
```

**favorites**
```sql
pagodaId, addedAt
```

## 🧮 A* Pathfinding Algorithm

The app implements the A* algorithm for finding optimal routes between pagodas:

```dart
// Simplified pseudocode
function findPath(start, goal, allPagodas):
  openSet = {start}
  closedSet = {}
  
  while openSet is not empty:
    current = node in openSet with lowest f(n) = g(n) + h(n)
    
    if current == goal:
      return reconstructPath(current)
    
    for each neighbor of current:
      if neighbor in closedSet:
        continue
      
      tentativeG = g(current) + distance(current, neighbor)
      
      if tentativeG < g(neighbor):
        neighbor.parent = current
        g(neighbor) = tentativeG
        h(neighbor) = haversineDistance(neighbor, goal)
        
        if neighbor not in openSet:
          add neighbor to openSet
  
  return []
```

**Key Features:**
- Uses Haversine formula for accurate GPS distance calculation
- Considers neighbors within 5km radius
- Optimal for pagoda network (graph-based)
- Fallback to nearest neighbor for multiple stops

## 🎯 Trip Planner (Killer Feature)

The Trip Planner is the standout feature:

### Features:
1. **Create Trips**: Add pagodas to your itinerary
2. **Optimize Route**: 
   - A* for 2 pagodas (optimal path)
   - Nearest neighbor for 3+ pagodas
3. **Reorder Stops**: Drag and drop to customize
4. **Statistics**:
   - Total distance (km)
   - Estimated duration (minutes)
   - Number of stops
5. **Export/Share**:
   - Screenshot of trip map + itinerary
   - Share via social media, email, etc.
   - Save to device

### Usage Flow:
```
1. Tap "Create Trip" button
2. Enter trip name, description, and date
3. Add pagodas from list
4. Tap "Optimize" to calculate best route
5. Reorder stops if needed
6. Save trip
7. View trip details with interactive map
8. Export/share trip screenshot
```

## 🔐 Authentication

Firebase Authentication with email/password:
- Secure user registration
- Login with email/password
- Password reset functionality
- Session management
- User profile with favorites

## 💾 Offline-First Architecture

The app works completely offline:

1. **Initial Load**: Downloads pagoda data from Firebase/API
2. **Local Storage**: Saves to SQLite database
3. **Offline Mode**: All features work without internet
4. **Sync**: Syncs favorites and trips when online

### Data Flow:
```
Firebase (Cloud) <--sync--> SQLite (Local) <--> App UI
                              ↑
                         Always reads
                         from local first
```

## 🧪 Testing

### Run tests
```bash
flutter test
```

### Test Coverage
- Unit tests for pathfinding algorithm
- Widget tests for UI components
- Integration tests for complete flows

## 📦 Building for Production

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 🎨 Design System

### Colors
- **Primary**: Gold (#D4AF37)
- **Secondary**: Brown (#8B4513)
- **Accent**: Orange (#E67E22)
- **Success**: Green (#27AE60)
- **Error**: Red (#E74C3C)

### Typography
- **Font**: Poppins
- **Weights**: Regular (400), Medium (500), SemiBold (600), Bold (700)

## 🔧 Configuration

### Environment Variables
Create `.env` file (optional):
```
FIREBASE_API_KEY=your_api_key
EMERGENT_LLM_KEY=your_emergent_key
```

### App Settings
Edit `lib/core/constants/app_constants.dart`:
```dart
class AppConstants {
  static const String appName = 'Baganetic';
  static const double baganLatitude = 21.1717;
  static const double baganLongitude = 94.8589;
  // ... more settings
}
```

## 🐛 Troubleshooting

### Common Issues

1. **Firebase not initialized**
   - Ensure `google-services.json` is in correct location
   - Run `flutter clean && flutter pub get`

2. **Map not loading**
   - Check internet connection for tile downloads
   - Verify OpenStreetMap tiles are accessible

3. **Database errors**
   - Clear app data and reinstall
   - Check SQLite permissions

4. **Build errors**
   - Run `flutter clean`
   - Delete `pubspec.lock` and run `flutter pub get`
   - Update Flutter: `flutter upgrade`

## 📚 Documentation

### Code Documentation
- All classes and functions are documented with dartdoc comments
- Generate docs: `dart doc .`

### API Documentation
- Firebase Auth API: https://firebase.google.com/docs/auth
- Firestore API: https://firebase.google.com/docs/firestore
- Flutter Map: https://docs.fleaflet.dev

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file

## 🙏 Acknowledgments

- Bagan Archaeological Museum for historical data
- OpenStreetMap for map tiles
- Flutter community for packages
- Firebase for backend services

## 📞 Support

For issues and questions:
- Create an issue on GitHub
- Email: support@baganetic.com

---

**Made with ❤️ for exploring the ancient wonders of Bagan**

**Flutter + Dart | Offline-First | Trip Planning | A* Pathfinding**
