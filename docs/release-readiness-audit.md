# Baganetic release-readiness audit

Audit date: 1 September 2026

## Outcome

The Android application code has a verified signed release APK and the checked
Flutter test suite passes. Production Firebase features are not ready to ship
until the external Firebase setup items below are completed.

## Fixed in this audit

| Priority | Finding | Resolution |
| --- | --- | --- |
| P0 | Map tiles were prefetched but the map used Flutter Map's default network tile provider, so the offline cache could not serve map tiles. | The map now uses `FMTCTileProvider` with the Bagan cache store. The map also tells travellers when their first tile download is required, in progress, partial, or failed, and provides a retry action. |
| P0 | Any signed-in client could directly change a community post's vote and comment totals. | Firestore rules now keep aggregate totals immutable to clients. Trusted Firestore triggers maintain totals after comment and vote document events. |
| P1 | The Functions dependency tree had moderate known vulnerabilities. | Updated to Node 22, `firebase-admin` 14.3.0, and `firebase-functions` 7.3.2 with a lockfile. The latest dependency graph still reports seven upstream moderate advisories without a non-breaking npm fix. |
| P2 | The Android app-ID template TODO was still present. | Removed the stale comment; the package remains `com.baganetic.baganetic_mobile`. |
| P2 | An unrelated Saudi Arabia presentation PDF was tracked in the app repository. | Removed only `Cream and Brown Minimalist Welcome to Saudi Arabia Presentation.pdf` from the current working tree. Git history was not rewritten. |

## Verified

- `flutter analyze --no-pub`: no issues.
- `flutter test`: 48 tests pass, including new coverage for offline-map state,
  permanent location-permission denial, migration defaults/data preservation,
  and the community-counter ownership contract.
- The release APK was built from local Dart defines and verified as an APK
  Signature Scheme v2 signed artifact.
- APK package metadata: `com.baganetic.baganetic_mobile`, version `1.0.3`,
  version code `4`.
- Route/ferry, cached-Bagan coverage, permission denied/granted/service-off,
  localization, and existing content contracts remain covered by the suite.

## Release blockers outside this repository

1. Firebase Functions are not deployed in project `baganetic-mobile`. This
   blocks AI replies, account deletion, and the trusted community counter
   updates added in this audit.
2. Firebase CLI authentication has expired, so Functions dry-run validation
   cannot proceed until the project owner reauthenticates with `firebase login
   --reauth`.
3. Firebase Storage has not been initialized for the project. Enable it in the
   Firebase Console before shipping profile-image upload support.
4. No Android device or emulator was attached during this audit, so install,
   fresh-offline-map, GPS, text-scaling, and landscape smoke tests still need a
   real-device pass.

## Handoff

Release APK: `build/app/outputs/flutter-apk/app-release.apk`

SHA-256: `0A8640E273F954981931995226560C3783E394CE4FAF65DB735B9B43B91CD654`

Before publishing, reauthenticate Firebase, initialize Storage, then deploy
the Functions, Firestore rules, and Storage rules together. Install the APK on
an Android device and complete the four device checks above.
