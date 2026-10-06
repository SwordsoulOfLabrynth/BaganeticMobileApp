# Baganetic iOS Usability & Installation Guide

This document outlines the iOS configuration, installation procedures, and verified usability setup for Baganetic.

---

## 1. Architecture & Platform Readiness

| Component | Status | Details |
| :--- | :--- | :--- |
| **Minimum iOS Target** | iOS 13.0 | Configured in `Podfile`, `project.pbxproj`, and `AppFrameworkInfo.plist`. Compatible with modern Flutter, Firebase Apple SDK 11, and ObjectBox FMTC. |
| **Xcode / Toolchain** | Xcode 16.2 | Configured in CI (`macos-14` runner) to avoid Swift 6 concurrency keyword conflicts while maintaining full iOS 18+ SDK support. |
| **Firebase Integration** | Bundled & Ready | `GoogleService-Info.plist` is registered directly in Xcode `Runner.xcodeproj` resources and `PBXBuildFile`, providing native Firebase Core, Auth, Firestore, and Crashlytics support. |
| **Privacy Manifest** | Compliant | `ios/Runner/PrivacyInfo.xcprivacy` declares `UserDefaults` (`CA92.1`) and `FileTimestamp` (`C617.1`) according to Apple's Spring 2024 privacy policy. |
| **Location Tracking** | Optimized | `DeviceLocationService` uses `AppleSettings` with `ActivityType.otherNavigation` and active streaming (no unintended pauses while exploring pagodas). |
| **Container Sandbox** | Resilient | `AuthProvider` dynamically resolves the current Documents directory to prevent broken paths across iOS updates or iCloud restores. |

---

## 2. iOS Permissions Overview

The following keys are configured in `ios/Runner/Info.plist`:

```xml
<!-- Map and pagoda discovery -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Baganetic uses your location on the map to show where you are among Bagan pagodas. Location is only used while the map is open and is not uploaded to our servers.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Baganetic uses your location on the map to show where you are among Bagan pagodas.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Baganetic uses your location on the map to show where you are among Bagan pagodas.</string>

<!-- Profile photo management -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Baganetic uses your photo library so you can set a profile picture.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Baganetic does not save photos to your library unless you choose to share an image.</string>
<key>NSCameraUsageDescription</key>
<string>Baganetic uses the camera so you can take and upload a profile picture.</string>

<!-- App Store compliance -->
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

---

## 3. How to Install and Use Baganetic on iOS

### Method 1: Sideloadly (Recommended for Testers on Windows or Mac)
*No paid Apple Developer account required. Works with any regular free Apple ID.*

1. Download and install [Sideloadly](https://sideloadly.io/) on your PC or Mac.
2. Download the `Baganetic-v1.0.3.ipa` artifact from GitHub Actions (or your release distribution).
3. Connect your iPhone or iPad to your computer via USB (select "Trust This Computer" if prompted).
4. Drag and drop `Baganetic-v1.0.3.ipa` into Sideloadly.
5. Enter your Apple ID email and click **Start**.
6. Once installation completes:
   - On your iPhone, open **Settings > General > VPN & Device Management**.
   - Tap your Apple ID under Developer App and tap **Trust**.
7. Open **Baganetic** directly from your Home Screen.

---

### Method 2: AltStore / SideStore (On-Device Wireless Install)
1. Set up [AltStore](https://altstore.io/) or [SideStore](https://sidestore.io/).
2. On your iPhone, open the Files app or Safari and tap `Baganetic-v1.0.3.ipa`.
3. Choose **Open in AltStore** (or tap **+** inside AltStore).
4. The app will install and remain active on your device with automatic background refresh.

---

### Method 3: TrollStore (Permanent Installation on iOS 14.0 – 17.0)
If your device has [TrollStore](https://github.com/opa334/TrollStore) installed:
1. Transfer `Baganetic-v1.0.3.ipa` to the device.
2. Tap the IPA and select **Install with TrollStore**.
3. Baganetic runs permanently without any 7-day expiration or certificate limits.

---

### Method 4: Mac Developer / Xcode Workflow
If you have a Mac and Flutter development environment:

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run on connected iPhone or Simulator
flutter run -d <device_id_or_ios>

# 3. Or build standalone IPA:
bash scripts/build_ios_distribution.sh
```

---

### Method 5: Instant Safari PWA ("Add to Home Screen")
For travelers who prefer zero downloads:
1. Open Safari on iPhone or iPad and navigate to `https://baganetic-mobile.web.app/`.
2. Tap the **Share** button (box with an arrow pointing up) at the bottom.
3. Tap **Add to Home Screen**.
4. Tap **Add**. Baganetic runs in standalone full-screen mode just like a native app.

---

## 4. GitHub Actions CI Pipeline

The iOS build is continuously automated via `.github/workflows/ios.yml`:
- **Trigger**: Every push to `main` / `master`, pull requests, and manual `workflow_dispatch`.
- **Outputs**:
  - `baganetic-ios-ipa`: Contains installable `Baganetic-v1.0.3.ipa` for direct sideloading.
  - `baganetic-ios-app`: Contains `Runner.app.tar.gz` for macOS developers.
