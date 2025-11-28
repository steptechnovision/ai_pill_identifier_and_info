import 'dart:io';

import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:ai_medicine_tracker/screens/medicine_tracker_screen.dart';
import 'package:ai_medicine_tracker/services/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Purchases.setLogLevel(LogLevel.debug);

  late PurchasesConfiguration configuration;
  await Prefs.initialize();
  if (Platform.isAndroid) {
    configuration = PurchasesConfiguration("goog_utOaJTDNmzZSOBnQOmereRGyWsK");
  } else {
    configuration = PurchasesConfiguration("YOUR_IOS_PUBLIC_API_KEY");
  }

  await Purchases.configure(configuration);

  // 🔔 Initialize reminders
  await ReminderService.instance.init();

  runApp(const MedicineApp());
}

class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      builder: (context, child) {
        return MaterialApp(
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
          navigatorObservers: [FlutterSmartDialog.observer],
          // here
          builder: FlutterSmartDialog.init(),
          home: const MedicineTrackerScreen(),
        );
      },
    );
  }
}
