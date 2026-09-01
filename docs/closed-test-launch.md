# Baganetic closed-test launch checklist

## What is already live

- Public privacy policy: https://baganetic-mobile.web.app/privacy.html
- Public account-deletion request: https://baganetic-mobile.web.app/account-deletion.html
- Public terms: https://baganetic-mobile.web.app/terms.html
- Firestore rules have been deployed to the `baganetic-mobile` database.

## Required owner actions before uploading to Google Play

1. Upgrade the Firebase project to Blaze and set a budget alert and Cloud Run spend cap.
2. In Firebase Storage, select **Get Started** to create the default storage bucket, then deploy `storage.rules`.
3. Set the `NVIDIA_API_KEY` Firebase Functions secret and deploy the Functions. This makes AI replies, complete account deletion, and trusted community counters live.
4. In Play Console, complete the App content and Data safety forms using the app’s real configured services. Do not claim that location is uploaded: it is used locally for the map. Review Firebase SDK disclosures for Authentication, Firestore, Storage, Crashlytics, and any enabled analytics before submitting.
5. Create the closed tester list and give testers the opt-in link, the test scenarios, and a feedback channel.

## Tester scenarios

- First launch, onboarding, guest pagoda browsing, search, and travel discovery.
- Fresh map download with internet, then repeat the same Bagan area offline.
- GPS allowed, denied, and permanently denied.
- Email sign-up, sign-in, password reset, account deletion, and profile image upload.
- Community post, comment, and vote; verify counters update after a short delay.
- AI assistant success, rate limit, and unavailable-service error.
- Text scaling and landscape on at least two Android phones.

## Production gate

Do not apply for production access until the Firebase steps and real-device test scenarios pass. If this is a new personal Play developer account, keep at least 12 testers opted in continuously for 14 days before requesting production access.
