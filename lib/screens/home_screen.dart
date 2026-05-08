import 'dart:developer';
import 'dart:math' hide log;

import 'package:flutter/services.dart';

import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/screens/camera_scan_screen.dart';
import 'package:ai_medicine_tracker/screens/medicine_tracker_screen.dart';
import 'package:ai_medicine_tracker/screens/my_medications_screen.dart';
import 'package:ai_medicine_tracker/screens/reminders_screen.dart';
import 'package:ai_medicine_tracker/screens/settings_screen.dart';
import 'package:ai_medicine_tracker/services/admob_service.dart';
import 'package:ai_medicine_tracker/services/subscription_service.dart';
import 'package:ai_medicine_tracker/widgets/banner_ad_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ai_medicine_tracker/screens/paywall_screen.dart';
import 'package:in_app_update/in_app_update.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  bool _wasTrulyPaused = false;
  DateTime? _lastBackPress;

  // Interstitial every 3–6 tab switches (randomised)
  int _tabSwitchCount = 0;
  late int _nextInterstitialAt;

  // Non-const getter so Flutter sees new widget instances on rebuild,
  // which forces each tab state to re-run build() with fresh Pro status.
  List<Widget> get _tabs => const [
    MedicineTrackerScreen(),
    MyMedicationsScreen(),
    CameraScanScreen(),
    RemindersScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _nextInterstitialAt = _randomThreshold();
    WidgetsBinding.instance.addObserver(this);
    SubscriptionService.instance.proChangeNotifier.addListener(_onProChanged);
    AdmobService.instance.tiredOfAdsNotifier.addListener(_onTiredOfAds);
    AdmobService.instance.showColdLaunchAd();
    _checkForUpdate();
  }

  @override
  void dispose() {
    SubscriptionService.instance.proChangeNotifier.removeListener(_onProChanged);
    AdmobService.instance.tiredOfAdsNotifier.removeListener(_onTiredOfAds);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onProChanged() {
    if (mounted) setState(() {});
  }

  void _onTiredOfAds() {
    if (!mounted || SubscriptionService.instance.isPro) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _TiredOfAdsDialog(
        onUpgrade: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaywallScreen()),
          ).then((_) => setState(() {}));
        },
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!mounted) return;
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      log('In-app update check failed: $e');
    }
  }

  int _randomThreshold() => 3 + Random().nextInt(4); // 3, 4, 5, or 6

  void _onTabTap(int index) {
    if (index == _currentIndex) return; // same tab, don't count
    _tabSwitchCount++;
    if (_tabSwitchCount >= _nextInterstitialAt) {
      _tabSwitchCount = 0;
      _nextInterstitialAt = _randomThreshold();
      AdmobService.instance.onNewSearch(); // fires interstitial if cadence met
    }
    setState(() => _currentIndex = index);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasTrulyPaused = true;
    } else if (state == AppLifecycleState.resumed && _wasTrulyPaused) {
      _wasTrulyPaused = false;
      AdmobService.instance.showAppOpenAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // If not on the first tab, go there first
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
            _lastBackPress = null;
          });
          return;
        }
        // On first tab — double press to exit
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Press back again to exit',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF1E1E1E),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: UIConstants.darkBackgroundStart,
        body: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BannerAdWidget(),
        Container(
          decoration: BoxDecoration(
            color: UIConstants.darkBackgroundEnd,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60.h,
              child: Row(
                children: [
                  _navItem(
                      0, Icons.search_rounded, Icons.search_rounded, 'Search'),
                  _navItem(1, Icons.medication_rounded,
                      Icons.medication_outlined, 'My Meds'),
                  _cameraCenterButton(),
                  _navItem(
                      3, Icons.alarm_rounded, Icons.alarm_outlined, 'Reminders'),
                  _navItem(4, Icons.settings_rounded, Icons.settings_outlined,
                      'Settings'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cameraCenterButton() {
    final isSelected = _currentIndex == 2;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabTap(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? [UIConstants.accentGreen, const Color(0xFF00C853)]
                      : [
                          UIConstants.accentGreen.withValues(alpha: 0.7),
                          const Color(0xFF00C853).withValues(alpha: 0.7),
                        ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: UIConstants.accentGreen
                        .withValues(alpha: isSelected ? 0.5 : 0.25),
                    blurRadius: isSelected ? 16 : 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.black, size: 22),
            ),
            3.verticalSpace,
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? UIConstants.accentGreen : Colors.white38,
              ),
              child: const Text('Scan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
      int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? UIConstants.accentGreen.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? UIConstants.accentGreen : Colors.white38,
                size: 22,
              ),
            ),
            2.verticalSpace,
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? UIConstants.accentGreen : Colors.white38,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _TiredOfAdsDialog extends StatelessWidget {
  const _TiredOfAdsDialog({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: UIConstants.accentGreen.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.block_rounded,
                  color: UIConstants.accentGreen, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tired of Ads?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Upgrade to Pro and enjoy an ad-free experience with unlimited features.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UIConstants.accentGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Go Pro — Remove Ads',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Maybe Later',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35), fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
