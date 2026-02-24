# Setup Firestore Database for Baganetic Mobile

## Quick Setup (5 minutes)

### Option 1: Direct Link
Use this link to open Firestore setup directly:
**https://console.cloud.google.com/firestore/databases/create?project=baganetic-mobile**

### Option 2: Manual Steps
1. Go to https://console.firebase.google.com/ and open project **baganetic-mobile**.
2. Open **Firestore Database** in the left menu.
3. Click **Create database**.
4. Choose **Start in test mode** (development only), then select region.
5. Click **Enable** and wait for setup to finish.

## Security Rules (After Setup)

Apply rules that match the current mobile app scope:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    match /users/{userId} {
      allow read, write: if isSignedIn() && request.auth.uid == userId;
    }
  }
}
```

## Verification

```bash
firebase firestore:databases:list --project=baganetic-mobile
```
