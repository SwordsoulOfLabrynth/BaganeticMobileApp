# 🚀 Baganetic Mobile - Setup Guide

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: Version 3.10.0 or higher
- **Dart SDK**: Version 3.10.4 or higher  
- **Android Studio** (for Android development) or **Xcode** (for iOS development)
- **Firebase Account**: For authentication and cloud services
- **Git**: For version control

## 🛠️ Step-by-Step Setup

### 1. Environment Setup

#### Install Flutter
```bash
# Flutter is already installed at /tmp/flutter
export PATH="$PATH:/tmp/flutter/bin"

# Verify installation
flutter doctor
```

#### Install IDE
- **VS Code**: Install Flutter and Dart extensions
- **Android Studio**: Install Flutter plugin

### 2. Project Setup

#### Navigate to Project
```bash
cd /app/baganetic_mobile
```

#### Install Dependencies
```bash
flutter pub get
```

Expected output: "Changed 144 dependencies!"

### 3. Firebase Configuration

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add Project"
3. Name it "Baganetic" (or your preferred name)
4. Enable Google Analytics (optional)

#### Add Android App
1. In Firebase Console, click "Add app" → Android
2. Package name: `com.baganetic.baganetic_mobile`
3. Download `google-services.json`
4. Place it at: `/app/baganetic_mobile/android/app/google-services.json`

#### Add iOS App (Optional)
1. In Firebase Console, click "Add app" → iOS
2. Bundle ID: `com.baganetic.baganeticMobile`
3. Download `GoogleService-Info.plist`
4. Place it at: `/app/baganetic_mobile/ios/Runner/GoogleService-Info.plist`

#### Update Firebase Options
Edit `/app/baganetic_mobile/lib/firebase_options.dart`:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ACTUAL_API_KEY',
  appId: 'YOUR_ACTUAL_APP_ID',
  messagingSenderId: 'YOUR_ACTUAL_SENDER_ID',
  projectId: 'YOUR_ACTUAL_PROJECT_ID',
  storageBucket: 'YOUR_ACTUAL_BUCKET',
);
```

#### Enable Firebase Services
In Firebase Console:
1. **Authentication** → Sign-in method → Enable "Email/Password"
2. **Firestore Database** → Create database → Start in test mode
3. **Storage** → Get started → Use test rules

### 4. Project Structure Overview

```
baganetic_mobile/
├── android/              # Android native code
├── ios/                  # iOS native code  
├── lib/                  # Flutter app code
│   ├── core/            # Core utilities, services, theme
│   ├── data/            # Models, datasources
│   ├── presentation/    # Screens, widgets, providers
│   └── main.dart        # App entry point
├── assets/              # Images, fonts, data files
├── test/                # Unit & widget tests
├── pubspec.yaml         # Dependencies
└── README.md            # Documentation
```

### 5. Add Sample Data (Optional)

The app automatically creates 5 sample pagodas on first run:
- Ananda Temple
- Shwezigon Pagoda
- Dhammayangyi Temple
- Thatbyinnyu Temple
- Htilominlo Temple

To add more pagodas, you can:
1. Manually insert via Firebase Console → Firestore
2. Use the admin panel (Phase 2 feature)
3. Import from JSON file

### 6. Running the App

#### Check Device Connection
```bash
# List connected devices
flutter devices
```

#### Run on Android Emulator
```bash
# Start emulator first, then:
flutter run
```

#### Run on iOS Simulator (Mac only)
```bash
# Start simulator, then:
flutter run
```

#### Run with Hot Reload
```bash
flutter run --hot
```

#### Build Release APK
```bash
flutter build apk --release
```

## 🧪 Testing

### Run All Tests
```bash
flutter test
```

### Run Specific Test
```bash
flutter test test/pathfinding_test.dart
```

### Run Widget Tests
```bash
flutter test --tags=widget
```

## 🐛 Troubleshooting

### Common Issues

#### 1. "Firebase not initialized"
**Solution:**
```bash
# Ensure google-services.json is in correct location
ls android/app/google-services.json

# Clean and rebuild
flutter clean
flutter pub get
```

#### 2. "Unresolved reference: Firebase"
**Solution:**
```bash
# Update firebase_options.dart with actual Firebase config
# Rebuild project
flutter clean && flutter pub get
```

#### 3. "Failed to load asset 'assets/images/...'"
**Solution:**
```bash
# Verify pubspec.yaml includes assets
# Ensure image files exist in assets folder
flutter pub get
```

#### 4. "SQLite database locked"
**Solution:**
```bash
# Clear app data
flutter clean

# Uninstall app from device
adb uninstall com.baganetic.baganetic_mobile

# Reinstall
flutter run
```

#### 5. "Map tiles not loading"
**Solution:**
- Check internet connection
- Verify OpenStreetMap is accessible
- Check app permissions for internet access

#### 6. Build fails with "Gradle error"
**Solution:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

## 📱 Device-Specific Setup

### Android

#### Minimum Requirements
- Android 5.0 (API level 21) or higher
- 2GB RAM minimum
- 100MB free storage

#### Permissions Required
- Internet access
- Location (for map features)
- Storage (for trip exports)

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

### iOS

#### Minimum Requirements
- iOS 12.0 or higher
- iPhone 6 or newer
- 100MB free storage

#### Info.plist Permissions
Add to `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby pagodas</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to save trip screenshots</string>
```

## 🔧 Configuration

### App Constants
Edit `lib/core/constants/app_constants.dart`:
```dart
class AppConstants {
  // Customize these values
  static const String appName = 'Baganetic';
  static const double baganLatitude = 21.1717;
  static const double baganLongitude = 94.8589;
  static const double defaultZoom = 13.0;
}
```

### Theme Customization
Edit `lib/core/theme/app_theme.dart`:
```dart
class AppTheme {
  // Customize colors
  static const Color primaryColor = Color(0xFFD4AF37); // Gold
  static const Color secondaryColor = Color(0xFF8B4513); // Brown
  // ... more colors
}
```

## 📊 Database Management

### View Database
```bash
# Android
adb shell
cd /data/data/com.baganetic.baganetic_mobile/databases/
sqlite3 baganetic.db
.tables
SELECT * FROM pagodas;
```

### Reset Database
```dart
// In app, call:
await DatabaseService().clearAllData();
```

## 🚀 Deployment

### Android Play Store

1. **Create keystore**
```bash
keytool -genkey -v -keystore ~/baganetic-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias baganetic
```

2. **Configure signing**
Edit `android/app/build.gradle`:
```gradle
signingConfigs {
    release {
        keyAlias 'baganetic'
        keyPassword 'your_password'
        storeFile file('/path/to/baganetic-key.jks')
        storePassword 'your_password'
    }
}
```

3. **Build release**
```bash
flutter build appbundle --release
```

4. **Upload to Play Console**
- Go to Google Play Console
- Create app → Upload AAB
- Fill in store listing
- Submit for review

### iOS App Store

1. **Configure Xcode**
```bash
open ios/Runner.xcworkspace
```

2. **Set team and bundle ID**
- Select Runner → Signing & Capabilities
- Select your team
- Bundle ID: com.baganetic.baganeticMobile

3. **Build release**
```bash
flutter build ios --release
```

4. **Archive and upload**
- Product → Archive
- Distribute App → App Store Connect
- Upload

## 📈 Performance Optimization

### Reduce App Size
```bash
# Build with code splitting
flutter build apk --split-per-abi --release

# This creates separate APKs for different architectures
```

### Enable R8 Shrinking (Android)
In `android/app/build.gradle`:
```gradle
buildTypes {
    release {
        shrinkResources true
        minifyEnabled true
    }
}
```

## 🔐 Security Best Practices

1. **Never commit sensitive data**
   - Add `.env` to `.gitignore`
   - Use environment variables for API keys
   - Keep Firebase config secure

2. **Enable ProGuard/R8** for Android release builds

3. **Use HTTPS** for all API calls

4. **Implement certificate pinning** for production

5. **Validate user input** on both client and server

## 📞 Support

### Get Help
- **Email**: support@baganetic.com
- **GitHub Issues**: Create an issue with detailed description
- **Discord**: Join our developer community

### Resources
- [Flutter Documentation](https://docs.flutter.dev)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Flutter Map Documentation](https://docs.fleaflet.dev)

## ✅ Verification Checklist

Before deploying to production:

- [ ] Firebase configured correctly
- [ ] All dependencies installed
- [ ] App builds without errors
- [ ] Authentication works
- [ ] Database operations work
- [ ] Map loads pagoda markers
- [ ] Trip planner creates trips
- [ ] Route optimization works
- [ ] Export/share functionality works
- [ ] App works offline
- [ ] Tested on multiple devices
- [ ] Performance is acceptable
- [ ] No memory leaks
- [ ] Security measures implemented

## 🎉 You're Ready!

Your Baganetic mobile app is now set up and ready for development!

**Next Steps:**
1. Customize the sample data with real pagoda information
2. Test all features thoroughly
3. Add more pagodas to the database
4. Implement Phase 2 features (cloud sync, advanced tooling)
5. Deploy to stores

**Happy Coding! 🚀**
