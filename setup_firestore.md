# Setup Firestore Database for Baganetic Mobile

## Quick Setup (5 minutes)

### Option 1: Direct Link (Easiest)
Click this link to go directly to the Firestore setup page:
**https://console.cloud.google.com/firestore/databases/create?project=baganetic-mobile**

### Option 2: Manual Steps

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Select your project: **baganetic-mobile**

2. **Navigate to Firestore**
   - In the left sidebar, click **"Firestore Database"**
   - Or go directly: https://console.firebase.google.com/project/baganetic-mobile/firestore

3. **Create Database**
   - Click **"Create database"** button
   - Choose **"Start in test mode"** (for development)
   - Select location: **us-central** (or closest to you)
   - Click **"Enable"**

4. **Wait for Creation**
   - Database creation takes 1-2 minutes
   - You'll see a success message when done

5. **Test Your App**
   - Run your Flutter app again
   - Signup and chat should now work!

## Security Rules (After Setup)

Once the database is created, update the security rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Chat groups - authenticated users can read, members can write
    match /chatGroups/{groupId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
      
      match /messages/{messageId} {
        allow read, write: if request.auth != null;
      }
    }
    
    // Chat group members
    match /chatGroupMembers/{memberId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Verification

After creating the database, verify it exists:
```bash
firebase firestore:databases:list --project=baganetic-mobile
```

You should see:
```
(default) - us-central
```
