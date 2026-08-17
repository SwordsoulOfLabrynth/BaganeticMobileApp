# Baganetic AI proxy

This Cloudflare Worker keeps `NVIDIA_API_KEY` outside the Flutter APK. It only
accepts requests from signed-in Baganetic Firebase users and sends the same
limited Bagan context used by the former Firebase callable function.

## Deploy on the Workers Free plan

```powershell
cd cloudflare/ai-proxy
npm install
npx wrangler login
npx wrangler secret put NVIDIA_API_KEY
npx wrangler deploy
```

Copy the deployed `https://...workers.dev` URL, add `/v1/chat`, then build the
mobile app with the non-secret endpoint:

```powershell
flutter build apk --release --dart-define=AI_PROXY_URL=https://YOUR-WORKER.workers.dev/v1/chat
```

Never add the NVIDIA key to Flutter source, a Dart define, Git, or an APK.

The Worker verifies Firebase ID tokens and has a lightweight per-user request
limit. It is suitable for the project demo/free tier; production-scale abuse
protection needs Cloudflare's durable rate-limiting resources.
