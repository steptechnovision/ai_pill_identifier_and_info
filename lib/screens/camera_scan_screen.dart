import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/repository/medicine_repository.dart';
import 'package:ai_medicine_tracker/screens/paywall_screen.dart';
import 'package:ai_medicine_tracker/screens/token_purchase_screen.dart';
import 'package:ai_medicine_tracker/services/ai_service.dart';
import 'package:ai_medicine_tracker/services/subscription_service.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_review/in_app_review.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  File? _image;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _medicineName;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Refresh the credit chip instantly when the balance changes elsewhere
    // (e.g. a purchase made on the Search tab while this tab is kept alive in
    // the IndexedStack, or Pro monthly credits being granted).
    Prefs.tokensNotifier.addListener(_onTokensChanged);
    SubscriptionService.instance.proChangeNotifier.addListener(_onTokensChanged);
  }

  @override
  void dispose() {
    Prefs.tokensNotifier.removeListener(_onTokensChanged);
    SubscriptionService.instance.proChangeNotifier.removeListener(_onTokensChanged);
    super.dispose();
  }

  void _onTokensChanged() {
    if (mounted) setState(() {});
  }

  // ── Pick image ────────────────────────────────────────

  static const int _tokensPerScan = 5;

  Future<void> _pickImage(ImageSource source) async {
    // 5 tokens per scan for everyone — protects against API cost losses.
    // Tokens are NOT deducted here; they are charged inside _analyze() only
    // once we are actually calling the AI, and refunded if that call fails.
    final tokens = Prefs.getTokens();
    if (tokens < _tokensPerScan) {
      if (mounted) _showCreditsDialog();
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked == null) return;

      setState(() {
        _image = File(picked.path);
        _result = null;
        _medicineName = null;
      });
      await _analyze();
    } catch (e) {
      if (mounted) {
        Utils.showMessage(context, 'Could not access camera/gallery.',
            isError: true);
      }
    }
  }

  void _showCreditsDialog() {
    final current = Prefs.getTokens();
    final isPro = SubscriptionService.instance.isPro;
    final isInTrial = SubscriptionService.instance.isInTrial;
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
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
                child: const Icon(Icons.toll_rounded, size: 36, color: Colors.amber),
              ),
              20.verticalSpace,
              AppText(
                'Need More Credits',
                textAlign: TextAlign.center,
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
              12.verticalSpace,
              AppText(
                isInTrial
                    ? 'Camera scan costs $_tokensPerScan credits per scan. You have $current credit${current == 1 ? '' : 's'} for your free trial.\nYour ${Constants.proMonthlyTokens} monthly scan credits unlock when your trial ends — or buy a pack to scan now.'
                    : isPro
                        ? 'Camera scan costs $_tokensPerScan credits per scan. You have $current credit${current == 1 ? '' : 's'}.\nYour Pro monthly credits refresh next month — or buy a pack to scan now.'
                        : 'Camera scan costs $_tokensPerScan credits per scan. You have $current credit${current == 1 ? '' : 's'}.\nUpgrade to Pro for monthly credits, or buy a pack to scan now.',
                textAlign: TextAlign.center,
                color: Colors.white54,
                fontSize: 13.sp,
                lineHeight: 1.55,
                maxLines: 5,
              ),
              24.verticalSpace,
              // Only offer "Upgrade to Pro" to non-Pro users. A Pro user who ran
              // out of monthly scan credits should just be able to buy a pack.
              if (!isPro) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PaywallScreen()),
                      ).then((_) => setState(() {}));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UIConstants.accentGreen,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.stars_rounded, size: 18),
                    label: AppText('Upgrade to Pro', fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                ),
                10.verticalSpace,
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openPurchaseScreen();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: AppText('Buy Credits', fontSize: 14.sp, color: Colors.amber, fontWeight: FontWeight.w600),
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

  void _openPurchaseScreen() async {
    final online = await Utils.checkInternetWithLoading();
    if (!online) {
      if (!mounted) return;
      Utils.showMessage(context, 'No internet connection.', isError: true);
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PurchaseTokenScreen()),
    ).then((_) => setState(() {}));
  }

  Future<void> _maybeAskForReview() async {
    if (Prefs.isReviewAsked()) return;
    await Prefs.incrementReviewSearchCount();
    if (Prefs.getReviewSearchCount() < 3) return;
    await Prefs.markReviewAsked();
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) review.requestReview();
    } catch (e) {
      log('In-app review failed: $e');
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;

    final online = await Utils.checkInternetWithLoading();
    if (!mounted) return;
    if (!online) {
      // No AI call was made — no tokens have been spent.
      Utils.showMessage(context, 'No internet connection.', isError: true);
      return;
    }

    // Re-check balance and charge only now that we are actually calling the AI.
    if (Prefs.getTokens() < _tokensPerScan) {
      if (mounted) _showCreditsDialog();
      return;
    }
    await Prefs.deductTokens(_tokensPerScan);
    if (mounted) setState(() {}); // refresh the credit chip

    setState(() => _loading = true);

    try {
      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final json = await AIService.instance.scanPill(base64Image);

      final detectedName = json['medicineName'] as String? ?? 'Unknown';
      if (detectedName != 'Unknown') {
        MedicineRepository().storeCameraResult(detectedName, json);
        _maybeAskForReview();
      }
      if (mounted) {
        setState(() {
          _medicineName = detectedName;
          _result = json;
        });
      }
    } on FirebaseFunctionsException catch (e, st) {
      log('❌ Camera scan function error: ${e.code} ${e.message}\n$st');
      // Refund ONLY when the AI never ran (no cost to us). Keep the charge on
      // ambiguous failures where the vision call may already have been billed.
      final refunded = AIService.isNoCostFailure(e);
      if (refunded) await Prefs.addTokens(_tokensPerScan);
      if (mounted) {
        setState(() {});
        Utils.showMessage(
            context,
            refunded
                ? '${AIService.friendlyError(e)} Your credits were not used.'
                : AIService.friendlyError(e),
            isError: true);
      }
    } catch (e, st) {
      log('❌ Camera scan failed: $e\n$st');
      // Unknown failure — the AI may have run and been billed, so no refund.
      if (mounted) {
        setState(() {});
        Utils.showMessage(
            context, 'Analysis failed. Try a clearer, well-lit photo.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.28, 1.0],
            colors: [
              Color(0xFF071209),
              Color(0xFF121212),
              Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: SafeArea(child: _buildScanner()),
      ),
    );
  }

  // ── Scanner UI ────────────────────────────────────────

  Widget _buildScanner() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
            child: Column(
              children: [
                _buildTrialBanner(),
                _buildImageArea(),
                16.verticalSpace,
                _buildActionButtons(),
                if (_loading) ...[
                  32.verticalSpace,
                  _buildAnalyzingIndicator(),
                ],
                if (_result != null && !_loading) ...[
                  24.verticalSpace,
                  _buildResultSection(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final tokens = Prefs.getTokens();
    final enough = tokens >= _tokensPerScan;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: UIConstants.accentGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: UIConstants.accentGreen.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.camera_alt_rounded,
                color: UIConstants.accentGreen, size: 18),
          ),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Camera Scan',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                AppText(
                  '$_tokensPerScan credits per scan · Tap balance to buy',
                  fontSize: 11.sp,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showCreditsDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (enough ? Colors.amber : Colors.redAccent)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: (enough ? Colors.amber : Colors.redAccent)
                        .withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.toll_rounded,
                      color: enough ? Colors.amber : Colors.redAccent, size: 12),
                  5.horizontalSpace,
                  AppText('$tokens credits',
                      fontSize: 11.sp,
                      color: enough ? Colors.amber : Colors.redAccent),
                  4.horizontalSpace,
                  Icon(Icons.add_circle_outline_rounded,
                      color: (enough ? Colors.amber : Colors.redAccent).withValues(alpha: 0.7),
                      size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBanner() {
    if (!SubscriptionService.instance.isInTrial) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: UIConstants.accentGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: UIConstants.accentGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration_rounded,
              color: UIConstants.accentGreen, size: 16),
          10.horizontalSpace,
          Expanded(
            child: AppText(
              'Free trial: 1 free scan now. Your ${Constants.proMonthlyTokens} monthly scan credits unlock when your trial ends.',
              fontSize: 11.5.sp,
              color: UIConstants.accentGreen.withValues(alpha: 0.9),
              lineHeight: 1.4,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageArea() {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.camera),
      child: Container(
        width: double.infinity,
        height: 220.h,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _image != null
                ? UIConstants.accentGreen.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: _image != null ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: _image != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_image!, fit: BoxFit.cover),
                    if (!_loading)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () => _pickImage(ImageSource.camera),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.refresh_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            UIConstants.accentGreen.withValues(alpha: 0.15),
                            UIConstants.accentGreen.withValues(alpha: 0.03),
                          ],
                        ),
                        border: Border.all(
                            color:
                                UIConstants.accentGreen.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: UIConstants.accentGreen, size: 36),
                    ),
                    16.verticalSpace,
                    AppText(
                      'Tap to take a photo',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                    6.verticalSpace,
                    AppText(
                      'or choose from gallery below',
                      fontSize: 12.sp,
                      color: Colors.white38,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            onTap: () => _pickImage(ImageSource.camera),
            primary: true,
          ),
        ),
        12.horizontalSpace,
        Expanded(
          child: _actionBtn(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            onTap: () => _pickImage(ImageSource.gallery),
            primary: false,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool primary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          gradient: primary
              ? LinearGradient(
                  colors: [
                    UIConstants.accentGreen,
                    UIConstants.accentGreen.withValues(alpha: 0.75),
                  ],
                )
              : null,
          color: primary ? null : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: UIConstants.accentGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: primary ? Colors.black : Colors.white70, size: 18),
            8.horizontalSpace,
            AppText(
              label,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: primary ? Colors.black : Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingIndicator() {
    return Column(
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            color: UIConstants.accentGreen,
            strokeWidth: 2.5,
          ),
        ),
        16.verticalSpace,
        AppText(
          'Analyzing pill...',
          fontSize: 14.sp,
          color: Colors.white54,
        ),
        6.verticalSpace,
        AppText(
          'AI Vision is identifying your medicine',
          fontSize: 11.sp,
          color: Colors.white30,
        ),
      ],
    );
  }

  Widget _buildResultSection() {
    final result = _result!;
    final name = _medicineName ?? 'Unknown';
    final isUnknown = name == 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Medicine name header card
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isUnknown
                  ? [
                      Colors.amber.withValues(alpha: 0.12),
                      Colors.amber.withValues(alpha: 0.04),
                    ]
                  : [
                      UIConstants.accentGreen.withValues(alpha: 0.12),
                      UIConstants.accentGreen.withValues(alpha: 0.04),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnknown
                  ? Colors.amber.withValues(alpha: 0.3)
                  : UIConstants.accentGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isUnknown ? Colors.amber : UIConstants.accentGreen)
                          .withValues(alpha: 0.2),
                      (isUnknown ? Colors.amber : UIConstants.accentGreen)
                          .withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Icon(
                  isUnknown
                      ? Icons.help_outline_rounded
                      : Icons.medication_rounded,
                  color: isUnknown ? Colors.amber : UIConstants.accentGreen,
                  size: 22,
                ),
              ),
              14.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            UIConstants.accentGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: AppText(
                        'AI Analysis',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: UIConstants.accentGreen,
                      ),
                    ),
                    6.verticalSpace,
                    AppText(
                      name,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (isUnknown) ...[
          16.verticalSpace,
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Colors.amber, size: 16),
                10.horizontalSpace,
                Expanded(
                  child: AppText(
                    'Could not identify the pill. Try a clearer photo with better lighting.',
                    fontSize: 12.sp,
                    color: Colors.amber.shade200,
                    lineHeight: 1.5,
                    maxLines: 4,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          16.verticalSpace,
          ..._buildInfoCards(result),
        ],
      ],
    );
  }

  List<Widget> _buildInfoCards(Map<String, dynamic> data) {
    const sections = [
      ('Usage', Icons.medical_services_rounded, Colors.blue),
      ('Benefits', Icons.favorite_rounded, UIConstants.accentGreen),
      ('Dosage', Icons.numbers_rounded, Colors.purple),
      ('SideEffects', Icons.warning_amber_rounded, Colors.orange),
      ('Precautions', Icons.shield_rounded, Colors.amber),
      ('Interactions', Icons.compare_arrows_rounded, Colors.redAccent),
      ('Storage', Icons.inventory_2_rounded, Colors.blueGrey),
      ('Warnings', Icons.report_rounded, Colors.red),
      ('FAQs', Icons.quiz_rounded, Colors.teal),
    ];

    return sections
        .map((s) {
          final (key, icon, color) = s;
          final items = (data[key] as List?)
                  ?.map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList() ??
              [];
          if (items.isEmpty) return const SizedBox.shrink();
          return _InfoCard(
            title: _sectionLabel(key),
            icon: icon,
            color: color,
            items: items,
          );
        })
        .whereType<_InfoCard>()
        .toList();
  }

  String _sectionLabel(String key) => switch (key) {
        'SideEffects' => 'Side Effects',
        'WhoCanTake' => 'Who Can Take',
        'ExtraInformation' => 'Extra Information',
        _ => key,
      };
}

class _InfoCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon,
                        color: widget.color, size: 15),
                  ),
                  10.horizontalSpace,
                  Expanded(
                    child: AppText(
                      widget.title,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: AppText(
                      '${widget.items.length}',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: widget.color,
                    ),
                  ),
                  8.horizontalSpace,
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.05)),
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.items
                      .map((item) => Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: widget.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                8.horizontalSpace,
                                Expanded(
                                  child: AppText(
                                    item,
                                    fontSize: 12.sp,
                                    color: Colors.white70,
                                    lineHeight: 1.5,
                                    maxLines: 20,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
