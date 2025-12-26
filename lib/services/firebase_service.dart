import 'dart:developer';

import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/services/reminder_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

// 1. BACKGROUND HANDLER (Must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  log("Handling a background message: ${message.messageId}");
}

class FirebaseService {
  static final _firebaseMessaging = FirebaseMessaging.instance;

  // 2. INITIALIZE FIREBASE
  static Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Setup Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Initialize Notifications
    await _initNotifications();
  }

  // 3. SETUP NOTIFICATIONS
  static Future<void> _initNotifications() async {
    // Request Permission (Required for iOS & Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      printLog('User granted permission');

      // Get FCM Token (Send this to your server/console to test)
      final fcmToken = await _firebaseMessaging.getToken();
      printLog('🔥 FCM Token: $fcmToken');

      // Setup Background Handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Setup Foreground Handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        printLog('Got a message whilst in the foreground!');

        if (message.notification != null) {
          ReminderService.instance.showRemoteNotification(
            title: message.notification!.title ?? 'New Message',
            body: message.notification!.body ?? '',
            payload: message.data.toString(), // Optional: pass data if needed
          );
        }
      });
    } else {
      printLog('User declined or has not accepted permission');
    }
  }
}
