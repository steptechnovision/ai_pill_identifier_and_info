import 'dart:async';

import 'package:ai_medicine_tracker/helper/app_assets.dart';
import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'medicine_tracker_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    _startAnimation();
    _initializeApp();
  }

  /// 1. Trigger the visual animation
  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _animate = true;
    });
  }

  /// 2. Load your data (Prefs, API, etc.)
  Future<void> _initializeApp() async {
    // Simulate loading time (e.g., waiting for SharedPrefs, RevenueCat, Internet Check)
    // Replace this duration with your actual await logic later
    final minDisplayTime = Future.delayed(const Duration(seconds: 3));

    // Example: await Prefs.init();
    // Example: await Purchases.configure(...);

    await minDisplayTime; // Ensure splash shows for at least 3 seconds

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const MedicineTrackerScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B), // Deep dark background
      body: Stack(
        children: [
          // BACKGROUND GRADIENT
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E1E1E), Color(0xFF000000)],
              ),
            ),
          ),

          // CENTER CONTENT
          Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 1000),
              opacity: _animate ? 1.0 : 0.0,
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutBack,
                transform: Matrix4.translationValues(0, _animate ? 0 : 20, 0),
                margin: EdgeInsets.symmetric(horizontal: 14.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),
                    24.verticalSpace,
                    AppText(
                      Constants.appName,
                      color: Colors.white,
                      fontSize: 28.sp,
                      maxLines: 1000,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    8.verticalSpace,
                    AppText(
                      "Instant Medical Insights",
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14.sp,
                      maxLines: 1000,
                      letterSpacing: 0.5,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // BOTTOM LOADING INDICATOR
          Positioned(
            bottom: 50.h,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 1000),
                opacity: _animate ? 1.0 : 0.0,
                child: Column(
                  children: [
                    SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎨 Custom "Medicine + AI" Logo Composition
  Widget _buildLogo() {
    return SizedBox(
      width: 120.r,
      height: 120.r,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect
          Container(
            width: 100.r,
            height: 100.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ), // Main Circle
          Container(
            width: 90.r,
            height: 90.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.greenAccent.withValues(alpha: 0.2),
                  Colors.greenAccent.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Image.asset(AppAssets.appIcon, width: 42.r, height: 42.r),
          ), // AI Sparkle (Top Right)
          Positioned(
            top: 15.h,
            right: 15.w,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome, // Sparkle icon
                size: 14,
                color: Color(0xFFFFD700), // Gold
              ),
            ),
          ),
        ],
      ),
    );
  }
}
