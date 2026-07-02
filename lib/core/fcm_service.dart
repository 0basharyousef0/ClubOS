import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'constants.dart';
import 'supabase_client.dart';

class FcmService {
  /// Set by main.dart once Firebase.initializeApp() succeeds. While false
  /// (no google-services config files yet), every method is a safe no-op so
  /// the app runs with in-app notifications only.
  static bool firebaseReady = false;

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static Future<void> init() async {
    if (!firebaseReady) return;
    await _requestPermission();
    _setupForegroundHandler();
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('FCM permission: ${settings.authorizationStatus}');
    }
  }

  static Future<String?> getToken() async {
    if (!firebaseReady) return null;
    return await _messaging.getToken();
  }

  /// Upserts this device's FCM token for the signed-in user.
  /// Called from main.dart on session restore and on every sign-in.
  /// Safe to call repeatedly.
  static Future<void> registerToken() async {
    if (!firebaseReady) return;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final token = await _messaging.getToken();
      if (token == null) return;
      await supabase.from(AppConstants.tableFcmTokens).upsert({
        'user_id': user.id,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');
    } catch (e) {
      // Token registration must never break auth flows.
      if (kDebugMode) debugPrint('FCM registerToken failed: $e');
    }
  }

  /// Removes this device's token (called on sign-out so the user stops
  /// receiving push on a device they've left).
  static Future<void> removeToken() async {
    if (!firebaseReady) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await supabase
          .from(AppConstants.tableFcmTokens)
          .delete()
          .eq('token', token);
    } catch (e) {
      // Token cleanup must never block sign-out.
      if (kDebugMode) debugPrint('FCM removeToken failed: $e');
    }
  }

  static void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('FCM foreground message: ${message.notification?.title}');
      }
    });
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('FCM background message: ${message.notification?.title}');
  }
}
