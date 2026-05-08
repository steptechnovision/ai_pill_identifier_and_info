import 'dart:math';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  bool _wasTrulyPaused = false;

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
    // Show app open ad once per cold launch.
    // HomeScreen is only reachable after onboarding is done, so no need
    // to check onboarding status here.
    AdmobService.instance.showColdLaunchAd();
  }

  @override
  void dispose() {
    SubscriptionService.instance.proChangeNotifier.removeListener(_onProChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onProChanged() {
    if (mounted) setState(() {});
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
    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _buildBottomNav(),
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
