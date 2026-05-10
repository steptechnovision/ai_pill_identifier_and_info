import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/language_config.dart';
import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:ai_medicine_tracker/models/user_medication.dart';
import 'package:ai_medicine_tracker/screens/home_screen.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  // Page 0 — user type
  String _userType = 'patient';

  // Page 1 — my medications quick-add
  final TextEditingController _medController = TextEditingController();
  final List<String> _addedMeds = [];

  // Page 2 — language selection
  String _selectedLang = 'en';

  @override
  void dispose() {
    _pageController.dispose();
    _medController.dispose();
    super.dispose();
  }

  void _next() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_page < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _skip() {
    FocusManager.instance.primaryFocus?.unfocus();
    _finish();
  }

  Future<void> _finish() async {
    await Prefs.setUserType(_userType);
    await Prefs.setLanguage(_selectedLang);
    await Prefs.setOnboardingDone();

    // Persist any medications the user added
    if (_addedMeds.isNotEmpty) {
      for (final name in _addedMeds) {
        await UserMedication.add(UserMedication(
          id: 'med_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}',
          name: name,
          addedAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _addMed() {
    final name = _medController.text.trim();
    if (name.isEmpty || _addedMeds.contains(name)) return;
    setState(() => _addedMeds.add(name));
    _medController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      body: SafeArea(
        child: Column(
          children: [
            // progress dots
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? UIConstants.accentGreen
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPageLanguage(),
                  _buildPage3(),
                ],
              ),
            ),

            // bottom buttons
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConstants.accentGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: AppText(
                        _page == 3 ? 'Get Started' : 'Continue',
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                  if (_page < 3) ...[
                    8.verticalSpace,
                    TextButton(
                      onPressed: _skip,
                      child: AppText(
                        'Skip',
                        color: Colors.white38,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Who are you? ─────────────────────────────
  Widget _buildPage1() {
    final options = [
      ('patient', Icons.person_outline_rounded, 'Patient',
          'I manage my own medications'),
      ('caregiver', Icons.favorite_border_rounded, 'Caregiver',
          'I manage medications for family'),
      ('professional', Icons.local_hospital_outlined, 'Healthcare Professional',
          'I work in medicine / pharmacy'),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          24.verticalSpace,
          AppText(
            'Welcome! 👋',
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          8.verticalSpace,
          AppText(
            'Who are you?',
            fontSize: 16.sp,
            color: Colors.white60,
          ),
          32.verticalSpace,
          ...options.map((o) {
            final selected = _userType == o.$1;
            return GestureDetector(
              onTap: () => setState(() => _userType = o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: 12.h),
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: selected
                      ? UIConstants.accentGreen.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? UIConstants.accentGreen.withValues(alpha: 0.5)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(o.$2,
                        color: selected
                            ? UIConstants.accentGreen
                            : Colors.white38,
                        size: 24),
                    16.horizontalSpace,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(o.$3,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                          AppText(o.$4,
                              fontSize: 12.sp,
                              color: Colors.white54),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          color: UIConstants.accentGreen, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Page 2: Add medications ──────────────────────────
  Widget _buildPage2() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          24.verticalSpace,
          AppText(
            'Your Medications 💊',
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          8.verticalSpace,
          AppText(
            'Add medicines you take regularly.\nThis helps personalise your experience.',
            fontSize: 14.sp,
            color: Colors.white54,
            lineHeight: 1.5,
            maxLines: 5,
          ),
          24.verticalSpace,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _medController,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _addMed(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Paracetamol, Metformin...',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 12.h),
                  ),
                ),
              ),
              12.horizontalSpace,
              GestureDetector(
                onTap: _addMed,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: UIConstants.accentGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
          16.verticalSpace,
          if (_addedMeds.isEmpty)
            Center(
              child: AppText(
                'No medications added yet.\nYou can always add them later.',
                textAlign: TextAlign.center,
                color: Colors.white24,
                fontSize: 13.sp,
                lineHeight: 1.5,
                maxLines: 5,
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _addedMeds.length,
                itemBuilder: (_, i) => Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.symmetric(
                      horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.medication_rounded,
                          color: UIConstants.accentGreen, size: 18),
                      10.horizontalSpace,
                      Expanded(
                          child: AppText(_addedMeds[i],
                              color: Colors.white, fontSize: 14.sp)),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _addedMeds.removeAt(i)),
                        child: const Icon(Icons.close,
                            color: Colors.white38, size: 18),
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

  // ── Page 2: Language selection ───────────────────────
  Widget _buildPageLanguage() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          24.verticalSpace,
          AppText(
            'Choose Language 🌐',
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          8.verticalSpace,
          AppText(
            'AI responses will be in your preferred language.\nMedicine names stay in English.',
            fontSize: 14.sp,
            color: Colors.white54,
            lineHeight: 1.5,
            maxLines: 5,
          ),
          24.verticalSpace,
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: AppLanguage.supported.map((lang) {
                final selected = _selectedLang == lang.code;
                return GestureDetector(
                  onTap: () => setState(() => _selectedLang = lang.code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 13.h),
                    decoration: BoxDecoration(
                      color: selected
                          ? UIConstants.accentGreen.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? UIConstants.accentGreen.withValues(alpha: 0.5)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(lang.native,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                              if (lang.code != 'en')
                                AppText(lang.name,
                                    fontSize: 12.sp,
                                    color: Colors.white38),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle_rounded,
                              color: UIConstants.accentGreen, size: 20)
                        else
                          const Icon(Icons.radio_button_unchecked_rounded,
                              color: Colors.white24, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 3: Value promise ────────────────────────────
  Widget _buildPage3() {
    final features = [
      (Icons.auto_awesome_rounded, 'AI Medicine Analysis',
          'Instant info on any medicine — side effects, dosage, interactions'),
      (Icons.camera_alt_rounded, 'Camera Pill Scanner',
          'Scan any pill or tablet — AI identifies it instantly'),
      (Icons.warning_amber_rounded, 'Drug Interaction Checker',
          'Know if your medicines are safe to take together'),
      (Icons.alarm_rounded, 'Smart Reminders',
          'Never miss a dose with personalised reminders'),
      (Icons.medication_rounded, 'My Medications',
          'Track your personal medication list for you and your family'),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          24.verticalSpace,
          AppText(
            "You're all set! 🎉",
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          8.verticalSpace,
          AppText(
            "Here's what's waiting for you:",
            fontSize: 15.sp,
            color: Colors.white54,
          ),
          28.verticalSpace,
          ...features.map((f) => Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: UIConstants.accentGreen
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(f.$1, color: UIConstants.accentGreen, size: 20),
                    ),
                    14.horizontalSpace,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(f.$2,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                          4.verticalSpace,
                          AppText(f.$3,
                              fontSize: 12.sp,
                              color: Colors.white54,
                              lineHeight: 1.4,
                              maxLines: 5),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
