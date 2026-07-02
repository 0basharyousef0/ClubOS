import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/fcm_service.dart';
import 'core/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initSupabase();

  await _initPushNotifications();

  runApp(const ProviderScope(child: ClubOsApp()));
}

/// Initializes Firebase + FCM. Reads the native config files
/// (google-services.json / GoogleService-Info.plist), so until those are
/// added this fails and the app runs with in-app notifications only.
Future<void> _initPushNotifications() async {
  try {
    await Firebase.initializeApp();
    FcmService.firebaseReady = true;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase not configured — push disabled: $e');
    }
    return;
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FcmService.init();

  // Register the device for the restored session (if any), and again on
  // every sign-in (covers login and signup on this device).
  if (supabase.auth.currentSession != null) {
    await FcmService.registerToken();
  }
  supabase.auth.onAuthStateChange.listen((state) {
    if (state.event == AuthChangeEvent.signedIn) {
      FcmService.registerToken();
    }
  });
}

class ClubOsApp extends StatelessWidget {
  const ClubOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ClubOS',
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
