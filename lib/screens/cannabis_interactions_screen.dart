import 'dart:convert';
import 'dart:developer';

import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/services/admob_service.dart';
import 'package:ai_medicine_tracker/services/daily_limit_service.dart';
import 'package:ai_medicine_tracker/services/subscription_service.dart';
import 'package:ai_medicine_tracker/screens/paywall_screen.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:ai_medicine_tracker/widgets/banner_ad_widget.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CannabisInteractionsScreen extends StatefulWidget {
  const CannabisInteractionsScreen({super.key});

  @override
  State<CannabisInteractionsScreen> createState() =>
      _CannabisInteractionsScreenState();
}

class _CannabisInteractionsScreenState
    extends State<CannabisInteractionsScreen> {
  final _ctrl = TextEditingController();
  _CannabisResult? _result;
  bool _loading = false;
  static int _checkCount = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      Utils.showMessage(context, 'Enter a medicine name first.', isError: true);
      return;
    }

    if (DailyLimitService.instance.isLimitReached(ApiFeature.interaction)) {
      _showLimitDialog();
      return;
    }

    final online = await Utils.checkInternetWithLoading();
    if (!mounted) return;
    if (!online) {
      Utils.showMessage(context, 'No internet connection.', isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final dio = Dio();
      final response = await dio.post(
        Constants.openAiApi,
        options: Options(
          headers: {
            'Authorization': Constants.openAiAuthorizationKey,
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 45),
        ),
        data: Constants.getCannabisInteractionRequest(name),
      );

      var content =
          response.data['choices'][0]['message']['content'] as String;
      content = content.replaceAll('```json', '').replaceAll('```', '').trim();

      final json = jsonDecode(content) as Map<String, dynamic>;
      setState(() => _result = _CannabisResult.fromJson(json, name));

      await DailyLimitService.instance.record(ApiFeature.interaction);

      _checkCount++;
      if (_checkCount % 3 == 0) {
        AdmobService.instance.onNewSearch();
      }
    } on DioException catch (e, st) {
      log('❌ Cannabis check error: ${e.response?.data ?? e.message}\n$st');
      if (mounted) {
        Utils.showMessage(context, 'Check failed. Please try again.',
            isError: true);
      }
    } catch (e, st) {
      log('❌ Cannabis check failed: $e\n$st');
      if (mounted) {
        Utils.showMessage(context, 'Check failed. Please try again.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showLimitDialog() {
    final isPro = SubscriptionService.instance.isPro;
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
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.lock_clock_rounded,
                    size: 36, color: Colors.amber),
              ),
              20.verticalSpace,
              AppText(
                isPro ? 'Daily Limit Reached' : 'Free Limit Reached',
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              12.verticalSpace,
              AppText(
                isPro
                    ? 'You\'ve used all $limit interaction checks for today. Resets at midnight.'
                    : 'Free plan allows $limit checks/day. Upgrade to Pro for ${ DailyLimitService.instance.getLimit(ApiFeature.interaction) == Constants.freeDailyInteractionLimit ? Constants.proDailyInteractionLimit : limit } checks/day.',
                fontSize: 13.sp,
                color: Colors.white54,
                textAlign: TextAlign.center,
                lineHeight: 1.5,
                maxLines: 5,
              ),
              20.verticalSpace,
              if (!isPro)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PaywallScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UIConstants.accentGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Upgrade to Pro',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              8.verticalSpace,
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: AppText('Close', color: Colors.white38,
                    fontSize: 13.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      appBar: AppBar(
        backgroundColor: UIConstants.darkBackgroundStart,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
        title: AppText('Cannabis & CBD Interactions',
            fontSize: 17.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: 16.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoBanner(),
                  20.verticalSpace,
                  _buildSearchField(),
                  20.verticalSpace,
                  if (_loading) _buildLoader(),
                  if (_result != null) _buildResult(_result!),
                  if (!_loading && _result == null) _buildEmptyState(),
                ],
              ),
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.green, size: 20),
          12.horizontalSpace,
          Expanded(
            child: AppText(
              'Check if your medicine interacts with Cannabis (THC) or CBD. Uses your daily interaction check limit.',
              fontSize: 12.sp,
              color: Colors.white60,
              lineHeight: 1.5,
              maxLines: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('Medicine Name',
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white70),
        8.verticalSpace,
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _check(),
                decoration: InputDecoration(
                  hintText: 'e.g. Atorvastatin, Warfarin, Crocin...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 14.h),
                ),
              ),
            ),
            12.horizontalSpace,
            GestureDetector(
              onTap: _check,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.search_rounded,
                    color: Colors.green, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Colors.green),
            16.verticalSpace,
            AppText('Checking interactions…',
                fontSize: 13.sp, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_florist_rounded,
                  color: Colors.green, size: 40),
            ),
            20.verticalSpace,
            AppText(
              'Enter a medicine name above\nto check its interactions\nwith Cannabis & CBD',
              fontSize: 14.sp,
              color: Colors.white38,
              textAlign: TextAlign.center,
              lineHeight: 1.6,
              maxLines: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(_CannabisResult result) {
    final riskColor = _riskColor(result.riskLevel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: riskColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: riskColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: Icon(_riskIcon(result.riskLevel),
                    color: riskColor, size: 22),
              ),
              14.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(result.medicineName,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    4.verticalSpace,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: AppText('${result.riskLevel} Risk',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: riskColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        16.verticalSpace,

        // Summary
        if (result.summary.isNotEmpty) ...[
          _buildSection(
            icon: Icons.summarize_rounded,
            title: 'Summary',
            color: Colors.blueAccent,
            items: [result.summary],
          ),
          14.verticalSpace,
        ],

        // THC Interactions
        if (result.thcInteractions.isNotEmpty) ...[
          _buildSection(
            icon: Icons.spa_rounded,
            title: 'Cannabis (THC) Interactions',
            color: Colors.orangeAccent,
            items: result.thcInteractions,
          ),
          14.verticalSpace,
        ],

        // CBD Interactions
        if (result.cbdInteractions.isNotEmpty) ...[
          _buildSection(
            icon: Icons.local_florist_rounded,
            title: 'CBD Interactions',
            color: Colors.green,
            items: result.cbdInteractions,
          ),
          14.verticalSpace,
        ],

        // Mechanism
        if (result.mechanism.isNotEmpty) ...[
          _buildSection(
            icon: Icons.biotech_rounded,
            title: 'How It Works',
            color: Colors.purpleAccent,
            items: result.mechanism,
          ),
          14.verticalSpace,
        ],

        // Recommendations
        if (result.recommendations.isNotEmpty) ...[
          _buildSection(
            icon: Icons.recommend_rounded,
            title: 'Recommendations',
            color: UIConstants.accentGreen,
            items: result.recommendations,
          ),
          14.verticalSpace,
        ],

        // Disclaimer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: AppText(
            'Disclaimer: This information is AI-generated for educational purposes only. Always consult your doctor or pharmacist before combining any medicine with cannabis or CBD.',
            fontSize: 10.sp,
            color: Colors.white38,
            lineHeight: 1.5,
            maxLines: 10,
          ),
        ),
        20.verticalSpace,
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              8.horizontalSpace,
              AppText(title,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ],
          ),
          10.verticalSpace,
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, color: color, size: 5),
                    8.horizontalSpace,
                    Expanded(
                      child: AppText(item,
                          fontSize: 12.sp,
                          color: Colors.white70,
                          lineHeight: 1.5,
                          maxLines: 10),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Color _riskColor(String level) {
    switch (level.toLowerCase()) {
      case 'major':
        return Colors.redAccent;
      case 'moderate':
        return Colors.orangeAccent;
      case 'minor':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  IconData _riskIcon(String level) {
    switch (level.toLowerCase()) {
      case 'major':
        return Icons.dangerous_rounded;
      case 'moderate':
        return Icons.warning_amber_rounded;
      case 'minor':
        return Icons.info_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }
}

class _CannabisResult {
  final String medicineName;
  final String riskLevel;
  final List<String> thcInteractions;
  final List<String> cbdInteractions;
  final List<String> mechanism;
  final List<String> recommendations;
  final String summary;

  _CannabisResult({
    required this.medicineName,
    required this.riskLevel,
    required this.thcInteractions,
    required this.cbdInteractions,
    required this.mechanism,
    required this.recommendations,
    required this.summary,
  });

  factory _CannabisResult.fromJson(Map<String, dynamic> json, String name) {
    List<String> toList(String key) {
      final v = json[key];
      if (v is List) return v.map((e) => '$e').toList();
      if (v is String) return [v];
      return [];
    }

    return _CannabisResult(
      medicineName: name,
      riskLevel: json['risk_level'] as String? ?? 'Unknown',
      thcInteractions: toList('thc_interactions'),
      cbdInteractions: toList('cbd_interactions'),
      mechanism: toList('mechanism'),
      recommendations: toList('recommendations'),
      summary: json['summary'] as String? ?? '',
    );
  }
}
