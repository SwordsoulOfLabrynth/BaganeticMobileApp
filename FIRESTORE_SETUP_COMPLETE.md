# Firestore Setup Notes

Firestore is the backend used by the current app for:

- User profile documents under `users`
- Nested AI chat history under `users/{uid}/aiChatMessages`
- Pagoda road reports under `roadReports`

## Expected Outcome

Once Firestore is configured correctly:

- Sign-up can create the user profile document
- Signed-in users can submit and delete their own road reports
- Signed-in users can sync AI chat history

## Rules Reminder

Use rules that match the current app scope. A safe baseline is:

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

## Verification

```bash
firebase firestore:databases:list --project=baganetic-mobile
```

If Firestore-backed flows still fail after setup:

1. Confirm the project in `lib/firebase_options.dart`
2. Confirm Email/Password auth is enabled
3. Confirm the Firestore database exists
4. Confirm published rules match the collections above
