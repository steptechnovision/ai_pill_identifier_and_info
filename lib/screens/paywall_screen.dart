import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/services/subscription_service.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helper/constant.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _sub = SubscriptionService.instance;

  List<ProductDetails> _products = [];
  bool _loading = true;
  String _selectedId = Constants.subAnnualId;
  String? _purchasing;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _products = _sub.products;
        _loading = false;
      });
    }
  }

  ProductDetails? get _selectedProduct {
    try {
      return _products.firstWhere((p) => p.id == _selectedId);
    } catch (_) {
      return _products.isNotEmpty ? _products.first : null;
    }
  }

  Future<void> _purchase() async {
    final product = _selectedProduct;
    if (product == null) {
      if (mounted) {
        Utils.showMessage(
          context,
          'Could not connect to Play Store. Please check your connection and try again.',
          isError: true,
        );
      }
      return;
    }
    setState(() => _purchasing = product.id);
    try {
      await _sub.purchase(product);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        Utils.showMessage(context, 'Purchase failed. Please try again.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _purchasing = null);
    }
  }

  Future<void> _restore() async {
    Utils.showLoading(message: 'Restoring...');
    await _sub.restorePurchases();
    await Utils.hideLoading();
    if (mounted) {
      Utils.showMessage(context, 'Purchases restored!', success: true);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Fixed top: close + social proof ──────────
            _buildTopBar(),
            _buildSocialProof(),

            // ── Scrollable content ────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(22.w, 10.h, 22.w, 12.h),
                child: Column(
                  children: [
                    _buildHeader(),
                    18.verticalSpace,
                    _buildFeatureList(),
                    18.verticalSpace,
                    _buildTrialNote(),
                    14.verticalSpace,
                  ],
                ),
              ),
            ),

            // ── Fixed bottom: plans + CTA ─────────────────
            _buildFixedBottom(bottomPad),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────
  Widget _buildTopBar() {
    return Align(
      alignment: Alignment.topRight,
      child: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // ── Social proof (fixed, below close) ────────────────
  Widget _buildSocialProof() {
    return Container(
      margin: EdgeInsets.fromLTRB(22.w, 0, 22.w, 4.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.12),
            Colors.amber.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.amber, size: 18),
          10.horizontalSpace,
          Expanded(
            child: AppText(
              '50,000+ people trust Pro to keep their family safe every day.',
              fontSize: 12.sp,
              color: Colors.amber.shade200,
              lineHeight: 1.4,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Scrollable header ────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                UIConstants.accentGreen.withValues(alpha: 0.2),
                UIConstants.accentGreen.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
                color: UIConstants.accentGreen.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: UIConstants.accentGreen.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.stars_rounded,
              color: UIConstants.accentGreen, size: 28),
        ),
        6.verticalSpace,
        AppText(
          'Unlock Pro',
          fontSize: 22.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        6.verticalSpace,
        AppText(
          'Unlimited medicine searches, drug interaction\nchecks, and 30 scan tokens every month.',
          textAlign: TextAlign.center,
          fontSize: 13.sp,
          color: Colors.white54,
          lineHeight: 1.55,
          maxLines: 5,
        ),
      ],
    );
  }

  // ── Feature list ─────────────────────────────────────
  Widget _buildFeatureList() {
    final features = [
      (Icons.all_inclusive_rounded, 'Unlimited AI Medicine Analysis',
          '30 searches/day — 10× more than free'),
      (Icons.warning_amber_rounded, 'Drug Interaction Checker',
          '20 checks/day — keep your family safe'),
      (Icons.camera_alt_rounded, '30 Camera Scan Tokens / Month',
          'Scan pills, capsules, and labels with AI'),
      (Icons.medication_liquid_rounded, 'My Medications List',
          'Build your personal medication profile'),
      (Icons.alarm_rounded, 'Unlimited Reminders',
          'Never miss a dose again'),
      (Icons.history_rounded, 'Full Search History',
          'All your medicines, always accessible'),
    ];

    return Column(
      children: features.map((f) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: UIConstants.accentGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: UIConstants.accentGreen.withValues(alpha: 0.2)),
                ),
                child: Icon(f.$1, color: UIConstants.accentGreen, size: 15),
              ),
              14.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(f.$2,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    3.verticalSpace,
                    AppText(f.$3, fontSize: 11.sp, color: Colors.white38),
                  ],
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: UIConstants.accentGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Trial note ───────────────────────────────────────
  Widget _buildTrialNote() {
    final days = _sub.annualTrialDays;
    if (days <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: UIConstants.accentGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: UIConstants.accentGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration_rounded,
              color: UIConstants.accentGreen, size: 16),
          8.horizontalSpace,
          AppText(
            'Annual plan includes a $days-day free trial.\nCancel before it ends — no charge.',
            fontSize: 11.sp,
            color: UIConstants.accentGreen.withValues(alpha: 0.8),
            lineHeight: 1.5,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Fixed bottom ──────────────────────────────────────
  Widget _buildFixedBottom(double bottomPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, bottomPad + 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Plan selection cards
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: const CircularProgressIndicator(
                  color: UIConstants.accentGreen, strokeWidth: 2),
            )
          else ...[
            _buildPriceCard(
              id: Constants.subAnnualId,
              price: _sub.annualRegularPrice.isNotEmpty
                  ? _sub.annualRegularPrice
                  : (_products
                          .where((p) => p.id == Constants.subAnnualId)
                          .firstOrNull
                          ?.price ??
                      Constants.subAnnualFallbackPrice),
              isAnnual: true,
              trialDays: _sub.annualTrialDays,
            ),
            8.verticalSpace,
            _buildPriceCard(
              id: Constants.subMonthlyId,
              price: _products
                      .where((p) => p.id == Constants.subMonthlyId)
                      .firstOrNull
                      ?.price ??
                  Constants.subMonthlyFallbackPrice,
              isAnnual: false,
            ),
            16.verticalSpace,
          ],

          // CTA button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _purchasing != null ? null : _purchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: UIConstants.accentGreen,
                foregroundColor: Colors.black,
                disabledBackgroundColor:
                    UIConstants.accentGreen.withValues(alpha: 0.3),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _purchasing != null
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.black),
                    )
                  : AppText(
                      _selectedId == Constants.subAnnualId && _sub.annualTrialDays > 0
                          ? 'Start Free ${_sub.annualTrialDays}-Day Trial'
                          : 'Subscribe Now',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
            ),
          ),
          10.verticalSpace,

          // Cancel anytime + links
          AppText(
            _selectedId == Constants.subAnnualId && _sub.annualTrialDays > 0
                ? 'Cancel anytime · Auto-renews after ${_sub.annualTrialDays}-day trial'
                : 'Cancel anytime · Billed monthly',
            fontSize: 11.sp,
            color: Colors.white30,
            textAlign: TextAlign.center,
          ),
          4.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _restore,
                child: AppText('Restore',
                    fontSize: 11.sp, color: Colors.white38),
              ),
              AppText('·', color: Colors.white24, fontSize: 11.sp),
              TextButton(
                onPressed: () =>
                    launchUrl(Uri.parse(Constants.privacyPolicyUrl)),
                child: AppText('Privacy',
                    fontSize: 11.sp, color: Colors.white38),
              ),
              AppText('·', color: Colors.white24, fontSize: 11.sp),
              TextButton(
                onPressed: () =>
                    launchUrl(Uri.parse(Constants.termsAndConditionUrl)),
                child: AppText('Terms',
                    fontSize: 11.sp, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Price selection card ──────────────────────────────
  Widget _buildPriceCard({
    required String id,
    required String price,
    required bool isAnnual,
    int trialDays = 0,
  }) {
    final isSelected = _selectedId == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected
              ? UIConstants.accentGreen.withValues(alpha: 0.09)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? UIConstants.accentGreen.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? UIConstants.accentGreen
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? UIConstants.accentGreen
                      : Colors.white30,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
            14.horizontalSpace,
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppText(
                        isAnnual ? 'Annual Plan' : 'Monthly Plan',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      if (isAnnual) ...[
                        6.horizontalSpace,
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: UIConstants.accentGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: AppText('BEST VALUE',
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.black),
                        ),
                      ],
                    ],
                  ),
                  4.verticalSpace,
                  AppText(
                    isAnnual && trialDays > 0
                        ? '$trialDays-day free trial · then $price/year'
                        : isAnnual
                            ? 'Best annual value'
                            : 'Cancel anytime',
                    fontSize: 11.sp,
                    color: isAnnual ? UIConstants.accentGreen : Colors.white38,
                  ),
                ],
              ),
            ),
            // Price
            AppText(
              price,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
