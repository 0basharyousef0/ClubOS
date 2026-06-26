import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'constants.dart';
import 'supabase_client.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
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
    return await _messaging.getToken();
  }

  /// Upserts this device's FCM token for the signed-in user.
  ///
  /// Dormant until Firebase is initialized (see main.dart) and a
  /// google-services config is added — call this right after a successful
  /// login once push is enabled. Safe to call repeatedly.
  static Future<void> registerToken() async {
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
  }

  /// Removes this device's token (call on sign-out so the user stops
  /// receiving push on a device they've left).
  static Future<void> removeToken() async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await supabase
        .from(AppConstants.tableFcmTokens)
        .delete()
        .eq('token', token);
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
