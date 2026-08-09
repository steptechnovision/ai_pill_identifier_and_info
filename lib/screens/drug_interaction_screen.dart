import 'dart:developer';

import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/models/drug_interaction.dart';
import 'package:ai_medicine_tracker/models/user_medication.dart';
import 'package:ai_medicine_tracker/screens/paywall_screen.dart';
import 'package:ai_medicine_tracker/screens/token_purchase_screen.dart';
import 'package:ai_medicine_tracker/services/admob_service.dart';
import 'package:ai_medicine_tracker/services/ai_service.dart';
import 'package:ai_medicine_tracker/services/daily_limit_service.dart';
import 'package:ai_medicine_tracker/services/subscription_service.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:ai_medicine_tracker/widgets/banner_ad_widget.dart';
import 'package:ai_medicine_tracker/widgets/native_ad_card.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DrugInteractionScreen extends StatefulWidget {
  final List<String>? preloadedMeds;

  const DrugInteractionScreen({super.key, this.preloadedMeds});

  @override
  State<DrugInteractionScreen> createState() => _DrugInteractionScreenState();
}

class _DrugInteractionScreenState extends State<DrugInteractionScreen> {
  final _textCtrl = TextEditingController();
  final List<String> _drugs = [];
  DrugInteractionResult? _result;
  bool _loading = false;
  bool _includeSupplements = false;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedMeds != null && widget.preloadedMeds!.isNotEmpty) {
      _drugs.addAll(widget.preloadedMeds!.take(8));
    } else {
      final meds = UserMedication.loadAll();
      if (meds.isNotEmpty) {
        for (final m in meds.take(2)) {
          _drugs.add(m.name);
        }
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _addDrug() {
    final name = _textCtrl.text.trim();
    if (name.isEmpty || _drugs.contains(name)) return;
    if (_drugs.length >= 8) {
      Utils.showMessage(context, 'Maximum 8 drugs at once.', isError: true);
      return;
    }
    setState(() => _drugs.add(name));
    _textCtrl.clear();
  }

  Future<void> _check() async {
    if (_drugs.length < 2) {
      Utils.showMessage(
          context, 'Add at least 2 medications to check.', isError: true);
      return;
    }

    final isPro = SubscriptionService.instance.isPro;

    if (!isPro) {
      _showFreeUserInteractionDialog();
      return;
    }

    if (DailyLimitService.instance.isLimitReached(ApiFeature.interaction)) {
      _showInteractionLimitDialog();
      return;
    }

    await _performCheck(spendTokens: false);
  }

  Future<void> _performCheck({required bool spendTokens}) async {
    final online = await Utils.checkInternetWithLoading();
    if (!mounted) return;
    if (!online) {
      // No AI call was made — refund the tokens spent to start this check.
      if (spendTokens) await Prefs.addTokens(Constants.tokenCostInteraction);
      if (!mounted) return;
      setState(() {});
      Utils.showMessage(
          context, 'No internet connection. Your tokens were not used.',
          isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final data = await AIService.instance.checkDrugInteractions(
        _drugs,
        includeSupplements: _includeSupplements,
      );
      setState(() => _result = DrugInteractionResult.fromJson(data));

      if (!spendTokens) {
        await DailyLimitService.instance.record(ApiFeature.interaction);
      }
      if (mounted) setState(() {});

      AdmobService.instance.onNewSearch();
    } on FirebaseFunctionsException catch (e, st) {
      log('❌ Interaction function error: ${e.code} ${e.message}\n$st');
      // Refund ONLY when the AI never ran (no cost to us). Keep the charge on
      // ambiguous failures where OpenAI may already have been billed.
      final refunded = spendTokens && AIService.isNoCostFailure(e);
      if (refunded) await Prefs.addTokens(Constants.tokenCostInteraction);
      if (mounted) {
        setState(() {});
        Utils.showMessage(
            context,
            refunded
                ? '${AIService.friendlyError(e)} Your tokens were not used.'
                : AIService.friendlyError(e),
            isError: true);
      }
    } catch (e, st) {
      log('❌ Interaction check failed: $e\n$st');
      // Unknown failure — the AI may have run and been billed, so no refund.
      if (mounted) {
        setState(() {});
        Utils.showMessage(context, 'Check failed. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFreeUserInteractionDialog() {
    final tokens = Prefs.getTokens();
    final hasEnough = tokens >= Constants.tokenCostInteraction;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.medication_liquid_rounded, size: 36, color: Colors.purpleAccent),
              ),
              20.verticalSpace,
              AppText(
                'Premium Feature',
                textAlign: TextAlign.center,
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
              12.verticalSpace,
              AppText(
                'Drug interaction checking requires a Pro subscription or ${Constants.tokenCostInteraction} tokens per check.',
                textAlign: TextAlign.center,
                color: Colors.white54,
                fontSize: 13.sp,
                lineHeight: 1.55,
                maxLines: 5,
              ),
              24.verticalSpace,
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UIConstants.accentGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.stars_rounded, size: 18),
                  label: AppText('Upgrade to Pro', fontSize: 14.sp, fontWeight: FontWeight.bold),
                ),
              ),
              10.verticalSpace,
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (hasEnough) {
                      final ok = await Prefs.deductTokens(Constants.tokenCostInteraction);
                      if (ok && mounted) {
                        setState(() {});
                        await _performCheck(spendTokens: true);
                      }
                    } else {
                      if (mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseTokenScreen()));
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(hasEnough ? Icons.toll_rounded : Icons.add_circle_outline_rounded, size: 18),
                  label: AppText(
                    hasEnough
                        ? 'Use ${Constants.tokenCostInteraction} Tokens  ($tokens available)'
                        : 'Buy Tokens  (need ${Constants.tokenCostInteraction})',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              10.verticalSpace,
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: AppText('Maybe later', fontSize: 12.sp, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInteractionLimitDialog() {
    final limit = DailyLimitService.instance.getLimit(ApiFeature.interaction);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.lock_clock_rounded, size: 36, color: Colors.amber),
              ),
              20.verticalSpace,
              AppText(
                'Daily Limit Reached',
                textAlign: TextAlign.center,
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
              12.verticalSpace,
              AppText(
                'You\'ve used all $limit interaction checks for today.\nResets at midnight.',
                textAlign: TextAlign.center,
                color: Colors.white54,
                fontSize: 13.sp,
                lineHeight: 1.55,
                maxLines: 5,
              ),
              24.verticalSpace,
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: AppText('Got it', fontSize: 14.sp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final used = DailyLimitService.instance.getUsed(ApiFeature.interaction);
    final limit = DailyLimitService.instance.getLimit(ApiFeature.interaction);
    final atLimit = used >= limit;
    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      appBar: AppBar(
        backgroundColor: UIConstants.darkBackgroundStart,
        elevation: 0,
        title: AppText(
          'Drug Interactions',
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: atLimit
                  ? Colors.red.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: atLimit
                    ? Colors.red.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: AppText(
              '$used/$limit today',
              fontSize: 11.sp,
              color: atLimit ? Colors.redAccent : Colors.white54,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildChecker()),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildChecker() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputRow(),
          if (_drugs.isNotEmpty) ...[
            16.verticalSpace,
            _buildDrugChips(),
          ],
          16.verticalSpace,
          _buildSupplementToggle(),
          12.verticalSpace,
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _check,
              style: ElevatedButton.styleFrom(
                backgroundColor: UIConstants.accentGreen,
                foregroundColor: Colors.black,
                disabledBackgroundColor:
                    UIConstants.accentGreen.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.black),
                    )
                  : AppText(
                      'Check Interactions',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
            ),
          ),
          if (_result != null) ...[
            24.verticalSpace,
            _buildResult(_result!),
          ],
          24.verticalSpace,
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textCtrl,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _addDrug(),
            decoration: InputDecoration(
              hintText: 'e.g. Aspirin, Warfarin...',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.medication_rounded,
                  color: Colors.white38, size: 18),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            ),
          ),
        ),
        10.horizontalSpace,
        GestureDetector(
          onTap: _addDrug,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: UIConstants.accentGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add, color: Colors.black, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildDrugChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _drugs
          .map((d) => Chip(
                label: AppText(d, fontSize: 13.sp, color: Colors.white),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                side: BorderSide(
                    color: UIConstants.accentGreen.withValues(alpha: 0.4)),
                deleteIcon: const Icon(Icons.close_rounded,
                    size: 16, color: Colors.white38),
                onDeleted: () => setState(() => _drugs.remove(d)),
              ))
          .toList(),
    );
  }

  Widget _buildSupplementToggle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.teal, size: 15),
          ),
          10.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Include Supplements & Herbs',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
                2.verticalSpace,
                AppText(
                  'Also check vitamins, herbal supplements, and natural remedies',
                  fontSize: 11.sp,
                  color: Colors.white38,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: _includeSupplements,
              activeTrackColor: Colors.teal,
              activeThumbColor: Colors.white,
              inactiveTrackColor: Colors.white10,
              inactiveThumbColor: Colors.grey,
              onChanged: (v) => setState(() => _includeSupplements = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(DrugInteractionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRiskBanner(result),
        16.verticalSpace,
        if (result.summary.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Summary',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white54),
                8.verticalSpace,
                AppText(result.summary,
                    fontSize: 13.sp, color: Colors.white70, lineHeight: 1.5, maxLines: 20),
              ],
            ),
          ),
          16.verticalSpace,
        ],
        if (result.hasInteractions) ...[
          AppText('Interactions Found',
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white),
          12.verticalSpace,
          ...result.interactions.expand((p) => [
            _buildInteractionCard(p),
            if (result.interactions.indexOf(p) % 2 == 1) const NativeAdCard(),
          ]),
        ] else
          _buildNoInteractionCard(),
        16.verticalSpace,
        AppText(
          'ⓘ This AI analysis is for informational purposes only. Always consult your doctor or pharmacist.',
          fontSize: 10.sp,
          color: Colors.white24,
          textAlign: TextAlign.center,
          lineHeight: 1.4,
          maxLines: 5,
        ),
      ],
    );
  }

  Widget _buildRiskBanner(DrugInteractionResult result) {
    final (color, icon, label) = switch (result.overallRisk) {
      'High' => (UIConstants.accentRed, Icons.dangerous_rounded, 'High Risk'),
      'Medium' => (Colors.orange, Icons.warning_amber_rounded, 'Moderate Risk'),
      'Low' => (Colors.amber, Icons.info_outline_rounded, 'Low Risk'),
      _ => (UIConstants.accentGreen, Icons.check_circle_outline_rounded, 'No Significant Risk'),
    };

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          14.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Overall Risk',
                    fontSize: 11.sp, color: color.withValues(alpha: 0.7)),
                AppText(label,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionCard(InteractionPair pair) {
    final (color, label) = switch (pair.severity) {
      'Major' => (UIConstants.accentRed, 'MAJOR'),
      'Moderate' => (Colors.orange, 'MODERATE'),
      _ => (Colors.amber, 'MINOR'),
    };

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: AppText(label,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              12.horizontalSpace,
              Expanded(
                child: AppText(
                  '${pair.drug1} + ${pair.drug2}',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          10.verticalSpace,
          AppText(pair.description,
              fontSize: 12.sp, color: Colors.white60, lineHeight: 1.5, maxLines: 10),
          if (pair.action.isNotEmpty) ...[
            10.verticalSpace,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bolt_rounded, color: color, size: 14),
                6.horizontalSpace,
                Expanded(
                  child: AppText(pair.action,
                      fontSize: 12.sp,
                      color: color,
                      lineHeight: 1.4,
                      maxLines: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoInteractionCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: UIConstants.accentGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: UIConstants.accentGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: UIConstants.accentGreen, size: 28),
          14.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('No Significant Interactions',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                4.verticalSpace,
                AppText(
                  'These medications appear safe to take together based on available data.',
                  fontSize: 12.sp,
                  color: Colors.white54,
                  lineHeight: 1.4,
                  maxLines: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
