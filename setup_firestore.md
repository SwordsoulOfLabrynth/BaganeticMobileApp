# Setup Firestore Database for Baganetic Mobile

Use this when you want Firebase-backed features to work in the current mobile
app.

## Firestore Is Required For

- Creating user profile documents after sign-up
- Reading and writing pagoda road reports
- Syncing AI chat history under each signed-in user

Guest-mode browsing does not require Firestore.

## Quick Setup

### Option 1: Firebase Console

1. Open https://console.firebase.google.com/
2. Select the project used by `lib/firebase_options.dart`
3. Open **Firestore Database**
4. Click **Create database**
5. Choose a region and finish setup

### Option 2: CLI Verification

After creation, verify the database exists:

```bash
firebase firestore:databases:list --project=baganetic-mobile
```

## Rules Example For The Current App

This example matches the collections used by the current app:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    match /users/{userId} {
      allow read, write: if isOwner(userId);

      match /aiChatMessages/{messageId} {
        allow read, write: if isOwner(userId);
      }
    }

    match /roadReports/{reportId} {
      allow read: if true;

      allow create: if isSignedIn()
        && request.resource.data.reporterUserId == request.auth.uid;

      allow update, delete: if isSignedIn()
        && resource.data.reporterUserId == request.auth.uid;
    }
  }
}
```

## Notes

- The pagoda catalog itself is currently local data, not Firestore-backed
- If Firestore does not exist yet, sign-up can succeed but profile creation may
  fail silently in the background
- Road reports are readable by everyone in the current app, but only the author
  should be able to modify or delete their own report
