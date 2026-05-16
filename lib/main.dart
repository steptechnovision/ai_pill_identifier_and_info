import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:ai_medicine_tracker/screens/splash_screen.dart';
import 'package:ai_medicine_tracker/services/adherence_service.dart';
import 'package:ai_medicine_tracker/services/admob_service.dart';
import 'package:ai_medicine_tracker/services/firebase_service.dart';
import 'package:ai_medicine_tracker/services/reminder_service.dart';
import 'package:ai_medicine_tracker/services/remote_config_service.dart';
import 'package:ai_medicine_tracker/services/subscription_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

bool isForScreenShots = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.initialize();

  await ReminderService.instance.init();
  await AdherenceService.instance.init();
  await FirebaseService.init();

  // Activate App Check — blocks any caller that is not your real signed app.
  // Debug mode uses a debug token (register it in Firebase Console → App Check).
  // Release mode uses Play Integrity (Android) / App Attest (iOS).
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  await RemoteConfigService.init();

  // Init monetization services
  await SubscriptionService.instance.init();
  await AdmobService.instance.init();

  runApp(const MedicineApp());
}

class MedicineApp extends StatefulWidget {
  const MedicineApp({super.key});

  @override
  State<MedicineApp> createState() => _MedicineAppState();
}

class _MedicineAppState extends State<MedicineApp> {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: Constants.appName,
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF1976D2),
            // Blue
            scaffoldBackgroundColor: const Color(0xFF121212),
            // Dark background
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF1976D2),
              secondary: const Color(0xFF43A047),
              // Green
              surface: const Color(0xFF1E1E1E),
              // Cards & surfaces
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1F1F1F),
              foregroundColor: Colors.white,
              centerTitle: true,
              elevation: 1,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E1E1E),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.white70,
              ),
              titleMedium: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              hintStyle: const TextStyle(color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1976D2),
                  width: 2,
                ),
              ),
            ),
          ),
          // here
          navigatorObservers: [observer, FlutterSmartDialog.observer],
          // here
          builder: FlutterSmartDialog.init(),
          home: const SplashScreen(),
        );
      },
    );
  }
}
