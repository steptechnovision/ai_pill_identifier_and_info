import 'package:ai_medicine_tracker/helper/app_assets.dart';
import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:ai_medicine_tracker/screens/home_screen.dart';
import 'package:ai_medicine_tracker/screens/onboarding_screen.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrlMain;
  late final AnimationController _ctrlPulse;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;
  late final Animation<double> _pulse2Scale;
  late final Animation<double> _pulse2Opacity;

  @override
  void initState() {
    super.initState();

    _ctrlMain = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _ctrlPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _logoScale = CurvedAnimation(
      parent: _ctrlMain,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    ).drive(Tween(begin: 0.25, end: 1.0));

    _logoFade = CurvedAnimation(
      parent: _ctrlMain,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    ).drive(Tween(begin: 0.0, end: 1.0));

    _contentFade = CurvedAnimation(
      parent: _ctrlMain,
      curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
    ).drive(Tween(begin: 0.0, end: 1.0));

    _contentSlide = CurvedAnimation(
      parent: _ctrlMain,
      curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
    ).drive(Tween(begin: const Offset(0, 0.35), end: Offset.zero));

    // First pulse ring
    _pulseScale = _ctrlPulse.drive(
      Tween(begin: 0.75, end: 1.75),
    );
    _pulseOpacity = _ctrlPulse.drive(
      TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.3), weight: 10),
        TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.0), weight: 90),
      ]),
    );

    // Second pulse ring — offset by half a cycle
    _pulse2Scale = CurvedAnimation(
      parent: _ctrlPulse,
      curve: const Interval(0.5, 1.0),
    ).drive(Tween(begin: 0.75, end: 1.75));
    _pulse2Opacity = CurvedAnimation(
      parent: _ctrlPulse,
      curve: const Interval(0.5, 1.0),
    ).drive(TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.25), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.0), weight: 90),
    ]));

    _ctrlMain.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    final onboardingDone = Prefs.isOnboardingDone();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) =>
            onboardingDone ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ctrlMain.dispose();
    _ctrlPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.15),
            radius: 1.1,
            colors: [
              Color(0xFF071209), // very dark green-black
              Color(0xFF000000),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Subtle top glow orb
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        UIConstants.accentGreen.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Center content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo with animated pulse rings
                  AnimatedBuilder(
                    animation: Listenable.merge([_ctrlMain, _ctrlPulse]),
                    builder: (_, __) {
                      final logoSz = 90.r;
                      return SizedBox(
                        width: 180.r,
                        height: 180.r,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulse ring 1
                            Opacity(
                              opacity: _pulseOpacity.value,
                              child: Transform.scale(
                                scale: _pulseScale.value,
                                child: Container(
                                  width: logoSz,
                                  height: logoSz,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: UIConstants.accentGreen,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Pulse ring 2
                            Opacity(
                              opacity: _pulse2Opacity.value,
                              child: Transform.scale(
                                scale: _pulse2Scale.value,
                                child: Container(
                                  width: logoSz,
                                  height: logoSz,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: UIConstants.accentGreen,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Static glow behind logo
                            Container(
                              width: logoSz,
                              height: logoSz,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: UIConstants.accentGreen
                                        .withValues(alpha: 0.22),
                                    blurRadius: 50,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            // Logo circle
                            FadeTransition(
                              opacity: _logoFade,
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: Container(
                                  width: logoSz,
                                  height: logoSz,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        UIConstants.accentGreen
                                            .withValues(alpha: 0.22),
                                        UIConstants.accentGreen
                                            .withValues(alpha: 0.06),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: UIConstants.accentGreen
                                          .withValues(alpha: 0.45),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      AppAssets.appIcon,
                                      width: 44.r,
                                      height: 44.r,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // AI badge
                            Positioned(
                              top: 14.r,
                              right: 14.r,
                              child: FadeTransition(
                                opacity: _logoFade,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1A),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFFD700)
                                          .withValues(alpha: 0.5),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.auto_awesome,
                                      size: 12,
                                      color: Color(0xFFFFD700)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  28.verticalSpace,

                  // App name + tagline
                  FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(
                              colors: [
                                Colors.white,
                                Color(0xFF9EFFC4),
                              ],
                            ).createShader(bounds),
                            blendMode: BlendMode.srcIn,
                            child: AppText(
                              Constants.appName,
                              color: Colors.white,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                          10.verticalSpace,
                          AppText(
                            'Your AI Medicine Assistant',
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13.sp,
                            letterSpacing: 1.5,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom progress bar
            Positioned(
              bottom: 52.h,
              left: 48.w,
              right: 48.w,
              child: FadeTransition(
                opacity: _contentFade,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              UIConstants.accentGreen),
                        ),
                      ),
                    ),
                    12.verticalSpace,
                    AppText(
                      'Loading...',
                      fontSize: 10.sp,
                      color: Colors.white.withValues(alpha: 0.2),
                      letterSpacing: 1.5,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
