# Push Notifications — Setup Guide

The in-app notification center (the bell + the `/notifications` screen) already
works on its own: DB triggers insert rows into `public.notifications`, and the
app reads them. **This guide adds the last piece — delivering those as actual
push notifications to the phone** (even when the app is closed).

## How it works

```
User does X (assign task / post event / …)
        │
        ▼
DB trigger inserts a row into  public.notifications
        │
        ▼
Supabase Database Webhook  (INSERT on notifications)
        │  POST { record: {...} }
        ▼
Edge Function  send-push-notification
        │  looks up fcm_tokens for record.user_id
        │  mints an OAuth token from the service account
        ▼
FCM HTTP v1 API  →  the user's device(s)
```

The Flutter app's only jobs are: initialize Firebase, request permission, and
upload its FCM token to `fcm_tokens` (already coded in `FcmService`).

---

## Step 1 — Apply the database migrations

These create the notification triggers and the `fcm_tokens` table:

```bash
supabase db push
# or apply manually in the SQL editor:
#   supabase/migrations/20260619000000_notification_triggers.sql
#   supabase/migrations/20260619000001_fcm_tokens.sql
```

> Without this, no notifications are created at all (in-app or push).

---

## Step 2 — Create a Firebase project & add config files

1. Go to <https://console.firebase.google.com> → **Add project**.
2. Add an **Android app** (package name must match
   `android/app/build.gradle`'s `applicationId`, e.g. `com.example.clubos`).
   Download **`google-services.json`** → place in **`android/app/`**.
3. Add an **iOS app** (bundle ID must match Xcode). Download
   **`GoogleService-Info.plist`** → add to **`ios/Runner/`** (via Xcode so it's
   in the target).

> ⚠️ **Never commit** `google-services.json` or `GoogleService-Info.plist`
> (already covered by the project's "never commit" rule).

The easiest way to generate the Dart options file is the FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure          # writes lib/firebase_options.dart
```

---

## Step 3 — Turn on push in the Flutter app

`FcmService` (in `lib/core/fcm_service.dart`) is already written with
`init()`, `registerToken()` and `removeToken()`. You just need to call them.
Apply these edits **after** Step 2 (before that, `Firebase.initializeApp()`
would crash on launch):

**`lib/main.dart`**

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/fcm_service.dart';
import 'core/supabase_client.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initSupabase();

  // ── Push notifications ──
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FcmService.init();
  // If a session was restored, register this device immediately.
  if (supabase.auth.currentSession != null) {
    await FcmService.registerToken();
  }

  runApp(const ProviderScope(child: ClubOsApp()));
}
```

**After a successful login** (e.g. in `login_screen.dart`, right after
`signIn(...)` succeeds):

```dart
await FcmService.registerToken();
```

**Before signing out** (everywhere you call `signOut()` — `settings_screen`,
`placeholder_screen`, `logout` paths):

```dart
await FcmService.removeToken();   // stop pushes to this device
await ref.read(authRepositoryProvider).signOut();
```

> Android 13+ shows the OS permission prompt automatically (handled by
> `FcmService.init()`). To display notifications **while the app is open**, add
> `flutter_local_notifications` later — backgrounded/closed pushes already show
> in the system tray without it.

---

## Step 4 — Deploy the Edge Function

```bash
supabase functions deploy send-push-notification
```

(The function lives in `supabase/functions/send-push-notification/index.ts`.)

---

## Step 5 — Give the function your service account

1. Firebase Console → **Project settings → Service accounts →
   Generate new private key**. This downloads a JSON file.
2. Set it as a function secret (keep the quotes — the key contains newlines):

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat ~/Downloads/your-service-account.json)"

# optional extra guard (see Step 6):
supabase secrets set WEBHOOK_SECRET="$(openssl rand -hex 16)"
```

> ⚠️ The service-account JSON is a credential — **never commit it**.
> `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically;
> you don't set those.

---

## Step 6 — Create the Database Webhook

Supabase Dashboard → **Database → Webhooks → Create a new hook**:

- **Table:** `notifications`
- **Events:** `INSERT`
- **Type:** Supabase Edge Function → `send-push-notification`
- **HTTP Headers:**
  - `Authorization: Bearer <YOUR_SERVICE_ROLE_KEY>` (passes the function's JWT
    check)
  - `x-webhook-secret: <the WEBHOOK_SECRET you set>` (only if you set one)

That's it — every new notification row now triggers a push.

---

## Step 7 — iOS only (APNs)

Push on iOS also needs Apple's APNs wired to Firebase:

1. Apple Developer → create an **APNs Auth Key (.p8)**.
2. Firebase Console → Project settings → **Cloud Messaging → Apple app
   configuration** → upload the `.p8` (with Key ID + Team ID).
3. In Xcode, enable **Push Notifications** and **Background Modes → Remote
   notifications** capabilities for the Runner target.

Android needs nothing beyond `google-services.json`.

---

## Step 8 — Test

1. Run the app on a real device (push doesn't work on the iOS simulator), log
   in, and accept the notification prompt. Confirm a row appears in
   `fcm_tokens`.
2. From a second account, assign that user a task (or post an announcement).
3. The device should receive a push, and the in-app bell badge should
   increment.

**Quick function test without the app** (uses an existing token row):

```bash
curl -i -X POST \
  'https://<PROJECT_REF>.supabase.co/functions/v1/send-push-notification' \
  -H 'Authorization: Bearer <SERVICE_ROLE_KEY>' \
  -H 'Content-Type: application/json' \
  -d '{"record":{"user_id":"<A_USER_UUID>","type":"announcement","message":"Test push"}}'
```

Watch logs with `supabase functions logs send-push-notification`.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `{"sent":0,"reason":"no tokens"}` | The user never registered a device — check Step 3 ran and `fcm_tokens` has a row. |
| `FIREBASE_SERVICE_ACCOUNT not configured` | Secret not set / malformed JSON (Step 5). |
| `OAuth token exchange failed` | Wrong/expired service-account key, or `private_key` newlines mangled — re-set the secret from the raw file. |
| Push on Android but not iOS | APNs not configured (Step 7). |
| In-app works, no push | Webhook missing/misconfigured (Step 6), or function not deployed (Step 4). |
| 401 from the function | Webhook `Authorization`/`x-webhook-secret` header doesn't match. |
