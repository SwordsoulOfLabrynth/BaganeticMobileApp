# Android release signing

Release builds must use your own upload keystore. The project intentionally
rejects release builds until `android/key.properties` is configured.

1. Generate an upload key:

```bash
keytool -genkeypair -v -keystore keystore/baganetic-upload.jks -alias baganetic -keyalg RSA -keysize 2048 -validity 10000
```

2. Copy `android/key.properties.example` to `android/key.properties` and enter
   the actual relative keystore path, alias, and passwords.
3. Keep the keystore, `key.properties`, and its passwords outside Git.
4. Build with `flutter build appbundle --release` for Play Store upload.

Back up the keystore securely. Losing it prevents future updates to the same
Android app signing identity.
