import 'dart:developer';

import 'package:ai_medicine_tracker/helper/app_assets.dart';
import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/main.dart';
import 'package:ai_medicine_tracker/repository/medicine_repository.dart';
import 'package:ai_medicine_tracker/screens/add_reminder_screen.dart';
import 'package:ai_medicine_tracker/helper/indian_brand_database.dart';
import 'package:ai_medicine_tracker/screens/cannabis_interactions_screen.dart';
import 'package:ai_medicine_tracker/screens/medicine_history_screen.dart';
import 'package:ai_medicine_tracker/screens/paywall_screen.dart';
import 'package:ai_medicine_tracker/screens/token_purchase_screen.dart';
import 'package:ai_medicine_tracker/services/admob_service.dart';
import 'package:ai_medicine_tracker/services/daily_limit_service.dart';
import 'package:ai_medicine_tracker/services/pdf_export_service.dart';
import 'package:ai_medicine_tracker/services/subscription_service.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:ai_medicine_tracker/widgets/collapsible_card.dart';
import 'package:ai_medicine_tracker/widgets/native_ad_card.dart';
import 'package:ai_medicine_tracker/widgets/custom_text_field.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicineTrackerScreen extends StatefulWidget {
  const MedicineTrackerScreen({super.key});

  @override
  State<MedicineTrackerScreen> createState() => _MedicineTrackerScreenState();
}

class _MedicineTrackerScreenState extends State<MedicineTrackerScreen> {
  final MedicineRepository repo = MedicineRepository();
  final TextEditingController _controller = TextEditingController();
  final ValueNotifier _isLoading = ValueNotifier<bool>(false);

  MedicineItem? _currentMedicine;
  List<String> _recentCanonicals = [];
  List<MedicineItem> _chipMedicines = [];
  List<MedicineItem> _filteredChips = [];
  List<String> _brandSuggestions = [];
  bool _noMedicineFound = false;

  @override
  void initState() {
    super.initState();
    SubscriptionService.instance.proChangeNotifier.addListener(_onProChanged);
    _initLogic();
  }

  @override
  void dispose() {
    SubscriptionService.instance.proChangeNotifier.removeListener(_onProChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onProChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initLogic() async {
    await repo.ensureLoaded();
    await _loadRecentSearches();
    _combineMedicines();
    _filteredChips = _chipMedicines;
    setState(() {});
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    _recentCanonicals = prefs.getStringList('recent_canonicals') ?? [];
  }

  Future<void> _addToRecentSearches(String canonical) async {
    final prefs = await SharedPreferences.getInstance();
    _recentCanonicals.removeWhere((e) => e == canonical);
    _recentCanonicals.insert(0, canonical);
    if (_recentCanonicals.length > 50) {
      _recentCanonicals = _recentCanonicals.sublist(0, 50);
    }
    await prefs.setStringList('recent_canonicals', _recentCanonicals);
  }

  void _combineMedicines({bool resetFilter = false}) {
    final all = repo.getAllCachedItems();
    all.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    _chipMedicines = all;
    final query = _controller.text.trim().toLowerCase();
    if (resetFilter || query.isEmpty) {
      _filteredChips = _chipMedicines;
    } else {
      _filteredChips = _chipMedicines
          .where((item) => item.originalName.toLowerCase().contains(query))
          .toList();
    }
    setState(() {});
  }

  void _onSearchTextChanged(String value) {
    final query = value.trim().toLowerCase();
    final cachedNames =
        _chipMedicines.map((m) => m.originalName.toLowerCase()).toSet();
    setState(() {
      _filteredChips = query.isEmpty
          ? _chipMedicines
          : _chipMedicines
              .where((item) => item.originalName.toLowerCase().contains(query))
              .toList();
      _brandSuggestions = query.isEmpty
          ? []
          : IndianBrandDatabase.matchingBrands(query)
              .where((b) => !cachedNames.contains(b.toLowerCase()))
              .toList();
    });
  }

  Future<void> _searchMedicine() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      Utils.showMessage(context, 'Enter medicine name to search', isError: true);
      return;
    }

    final lang = Prefs.getLanguage();
    final isCacheHit = repo.cacheContains(name.toLowerCase(), language: lang);
    final isPro = SubscriptionService.instance.isPro;
    final tokens = Prefs.getTokens();

    if (!isCacheHit) {
      final online = await Utils.checkInternetWithLoading();
      if (!online) {
        _isLoading.value = false;
        if (!mounted) return;
        Utils.showMessage(context, 'No internet connection.', isError: true);
        return;
      }

      if (isPro) {
        if (DailyLimitService.instance.isLimitReached(ApiFeature.search)) {
          _showProLimitReachedDialog(ApiFeature.search);
          return;
        }
      } else if (tokens <= 0) {
        if (DailyLimitService.instance.isLimitReached(ApiFeature.search)) {
          _showLimitReachedDialog();
          return;
        }
      }
    }

    _isLoading.value = true;
    setState(() {
      _noMedicineFound = false;
      _currentMedicine = null;
    });

    try {
      final medicine = await repo.fetchMedicine(name, language: lang);
      _currentMedicine = medicine;

      if (!mounted) return;
      if (medicine.fromCache) {
        Utils.showNoTokenUsed(context);
      } else if (isPro) {
        await DailyLimitService.instance.record(ApiFeature.search);
        if (!mounted) return;
        setState(() {});
      } else if (tokens > 0) {
        await Prefs.deductToken();
        if (!mounted) return;
        setState(() {});
        Utils.showTokenUsed(context);
      } else {
        await DailyLimitService.instance.record(ApiFeature.search);
        if (!mounted) return;
        setState(() {});
      }

      await _addToRecentSearches(medicine.canonicalName);
      if (!medicine.fromCache) {
        AdmobService.instance.onNewSearch();
        _maybeAskForReview();
      }
    } catch (e, st) {
      log('❌ Error: $e\n$st');
      if (!isCacheHit && isPro) {
        await DailyLimitService.instance.record(ApiFeature.search);
      } else if (!isCacheHit && tokens > 0) {
        await Prefs.deductToken();
      } else if (!isCacheHit) {
        await DailyLimitService.instance.record(ApiFeature.search);
      }
      if (!mounted) return;
      setState(() {
        _noMedicineFound = true;
        _currentMedicine = null;
      });
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _maybeAskForReview() async {
    if (Prefs.isReviewAsked()) return;
    await Prefs.incrementReviewSearchCount();
    if (Prefs.getReviewSearchCount() < 5) return;
    await Prefs.markReviewAsked();
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) review.requestReview();
    } catch (e) {
      log('In-app review failed: $e');
    }
  }

  void _showLimitReachedDialog() {
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
                'You\'ve used your ${Constants.freeDailySearchLimit} free search for today.\nCome back tomorrow or use tokens/Pro to search more.',
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
                    elevation: 0,
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

  void _showProLimitReachedDialog(ApiFeature feature) {
    final limit = DailyLimitService.instance.getLimit(feature);
    final label = feature == ApiFeature.search ? 'searches' : 'interaction checks';
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
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.lock_clock_rounded, size: 36, color: Colors.blueAccent),
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
                'You\'ve used all $limit $label for today.\nThis resets at midnight.',
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
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UIConstants.accentGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: AppText('Got it', fontSize: 14.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteChipMedicine(String originalName) async {
    final canonical = originalName.toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    _recentCanonicals.removeWhere((e) => e == canonical);
    await prefs.setStringList('recent_canonicals', _recentCanonicals);
    await repo.deleteMedicine(canonical);
    _combineMedicines();
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

  Future<void> _exportPdf(MedicineItem item) async {
    await AdmobService.instance.showInterstitialAndWait();
    if (!mounted) return;
    Utils.showLoading(message: 'Generating PDF…');
    try {
      await PdfExportService.exportMedicineInfo(item);
    } catch (_) {
      if (mounted) {
        Utils.showMessage(context, 'Could not generate PDF. Try again.',
            isError: true);
      }
    } finally {
      await Utils.hideLoading();
    }
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPro = SubscriptionService.instance.isPro;
    final tokens = Prefs.getTokens();

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
        child: SafeArea(
          child: Column(
            children: [
              if (!isForScreenShots) _buildHeader(isPro, tokens),
              _buildSearchBar(isPro, tokens),
              if (!isForScreenShots) _buildBanner(isPro, tokens),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildMedicineChips(),
                      _buildBrandSuggestions(),
                      ValueListenableBuilder(
                        valueListenable: _isLoading,
                        builder: (_, value, __) => value
                            ? Padding(
                                padding: EdgeInsets.symmetric(vertical: 56.h),
                                child: Column(
                                  children: [
                                    const SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: CircularProgressIndicator(
                                        color: UIConstants.accentGreen,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    16.verticalSpace,
                                    AppText(
                                      'Analyzing medicine...',
                                      fontSize: 13.sp,
                                      color: Colors.white38,
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (_noMedicineFound)
                        buildNoMedicineFound()
                      else if (_currentMedicine != null)
                        _buildResultView()
                      else if (_filteredChips.isEmpty)
                        _buildEmptyState(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildHistoryBar(),
    );
  }

  // ── Header ────────────────────────────────────────────

  Widget _buildHeader(bool isPro, int tokens) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 16.w, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  UIConstants.accentGreen.withValues(alpha: 0.2),
                  UIConstants.accentGreen.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                  color: UIConstants.accentGreen.withValues(alpha: 0.35)),
            ),
            child: Center(
              child: Image.asset(AppAssets.appIcon, width: 20, height: 20),
            ),
          ),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Colors.white, Color(0xFF9EFFC4)],
                  ).createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: AppText(
                    Constants.appName,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    maxLines: 1,
                  ),
                ),
                AppText(
                  'AI Medicine Assistant',
                  fontSize: 10.sp,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
          _buildStatusChip(isPro, tokens),
        ],
      ),
    );
  }

  // ── Status chip ───────────────────────────────────────

  Widget _buildStatusChip(bool isPro, int tokens) {
    if (isPro) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: UIConstants.accentGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: UIConstants.accentGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded,
                color: UIConstants.accentGreen, size: 13),
            4.horizontalSpace,
            AppText('Pro',
                fontSize: 12.sp,
                color: UIConstants.accentGreen,
                fontWeight: FontWeight.bold),
          ],
        ),
      );
    }
    if (tokens > 0) {
      return GestureDetector(
        onTap: _openPurchaseScreen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 13),
              4.horizontalSpace,
              AppText('$tokens',
                  fontSize: 12.sp,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold),
            ],
          ),
        ),
      );
    }
    final remaining = DailyLimitService.instance.remainingToday();
    return GestureDetector(
      onTap: remaining == 0 ? _showLimitReachedDialog : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: remaining > 0
              ? Colors.white.withValues(alpha: 0.06)
              : UIConstants.accentRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: remaining > 0
                ? Colors.white12
                : UIConstants.accentRed.withValues(alpha: 0.3),
          ),
        ),
        child: AppText(
          '$remaining left',
          fontSize: 12.sp,
          color: remaining > 0 ? Colors.white54 : UIConstants.accentRed,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────

  Widget _buildSearchBar(bool isPro, int tokens) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: UIConstants.accentGreen.withValues(alpha: 0.06),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CustomTextField(
                hintText: 'e.g. Paracetamol, Aspirin...',
                prefixIcon: AppAssets.icSearch,
                controller: _controller,
                showDividerOnSuffixIcon: false,
                onChanged: _onSearchTextChanged,
                isSearchView: true,
                showCancelButton: true,
              ),
            ),
          ),
          12.horizontalSpace,
          InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              _searchMedicine();
              _combineMedicines(resetFilter: true);
            },
            onLongPress: () {
              FirebaseCrashlytics.instance.crash();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    UIConstants.accentGreen,
                    UIConstants.accentGreen.withValues(alpha: 0.78),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: UIConstants.accentGreen.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.search_rounded,
                  color: Colors.black, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status banner ─────────────────────────────────────

  Widget _buildBanner(bool isPro, int tokens) {
    if (isPro) {
      return Container(
        margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: UIConstants.accentGreen.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: UIConstants.accentGreen.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.all_inclusive_rounded,
                color: UIConstants.accentGreen, size: 14),
            8.horizontalSpace,
            Expanded(
              child: AppText(
                'Pro · unlimited searches, no ads, full access',
                fontSize: 11.sp,
                color: UIConstants.accentGreen,
              ),
            ),
            const Icon(Icons.verified_rounded,
                color: UIConstants.accentGreen, size: 12),
          ],
        ),
      );
    }
    if (tokens > 0) {
      return GestureDetector(
        onTap: _openPurchaseScreen,
        child: Container(
          margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.amber.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.stars_rounded,
                  color: Colors.amber, size: 14),
              8.horizontalSpace,
              Expanded(
                child: AppText(
                  '$tokens credits · tap to buy more',
                  fontSize: 11.sp,
                  color: Colors.amber.shade200,
                ),
              ),
              Icon(Icons.add_circle_outline_rounded,
                  color: Colors.amber.withValues(alpha: 0.6), size: 14),
            ],
          ),
        ),
      );
    }
    final remaining = DailyLimitService.instance.remainingToday();
    final color =
        remaining > 0 ? Colors.lightBlueAccent : UIConstants.accentRed;
    return GestureDetector(
      onTap: remaining == 0 ? _showLimitReachedDialog : null,
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(
              remaining > 0
                  ? Icons.hourglass_top_rounded
                  : Icons.lock_clock_rounded,
              color: color,
              size: 14,
            ),
            8.horizontalSpace,
            Expanded(
              child: AppText(
                remaining > 0
                    ? '$remaining free search${remaining == 1 ? '' : 'es'} left today'
                    : 'Daily limit reached · upgrade plan now',
                fontSize: 11.sp,
                color: color,
              ),
            ),
            if (remaining == 0) ...[
              4.horizontalSpace,
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.6), size: 14),
            ],
          ],
        ),
      ),
    );
  }

  // ── Indian brand suggestions ──────────────────────────

  Widget _buildBrandSuggestions() {
    if (_brandSuggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
          child: Row(
            children: [
              const Icon(Icons.local_pharmacy_rounded,
                  size: 14, color: Colors.orangeAccent),
              6.horizontalSpace,
              AppText(
                'Indian Brands',
                color: Colors.orangeAccent,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: _brandSuggestions.map((brand) {
                final generic = IndianBrandDatabase.resolveGeneric(brand) ?? '';
                return Container(
                  margin: EdgeInsets.only(right: 8.w),
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _controller.text = brand;
                      _searchMedicine();
                      _combineMedicines(resetFilter: true);
                    },
                    child: Container(
                      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.orangeAccent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_pharmacy_rounded,
                              size: 12, color: Colors.orangeAccent),
                          6.horizontalSpace,
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppText(brand,
                                  fontSize: 13.sp, color: Colors.white),
                              if (generic.isNotEmpty)
                                AppText(generic,
                                    fontSize: 10.sp,
                                    color: Colors.white38),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        10.verticalSpace,
      ],
    );
  }

  // ── Recent searches ───────────────────────────────────

  Widget _buildMedicineChips() {
    if (_filteredChips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
          child: Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 14, color: Colors.white38),
              6.horizontalSpace,
              AppText(
                'Recent Searches',
                color: Colors.white38,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: _filteredChips.map((item) {
                return Container(
                  margin: EdgeInsets.only(right: 8.w),
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _controller.text = item.originalName;
                      _searchMedicine();
                      _combineMedicines(resetFilter: true);
                    },
                    child: Container(
                      padding:
                          EdgeInsets.fromLTRB(12.w, 8.h, 8.w, 8.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.35)),
                          6.horizontalSpace,
                          AppText(
                            item.originalName,
                            fontSize: 13.sp,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                          8.horizontalSpace,
                          GestureDetector(
                            onTap: () =>
                                _deleteChipMedicine(item.originalName),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: Icon(Icons.close_rounded,
                                  color: Colors.white38, size: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        10.verticalSpace,
      ],
    );
  }

  // ── Empty state ───────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.fromLTRB(32.w, 52.h, 32.w, 0),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  UIConstants.accentGreen.withValues(alpha: 0.14),
                  UIConstants.accentGreen.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(
                  color: UIConstants.accentGreen.withValues(alpha: 0.2)),
            ),
            child: Icon(
              Icons.medical_information_outlined,
              size: 36,
              color: UIConstants.accentGreen.withValues(alpha: 0.55),
            ),
          ),
          24.verticalSpace,
          AppText(
            'Search any medicine',
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            textAlign: TextAlign.center,
          ),
          12.verticalSpace,
          AppText(
            'Get instant AI-powered insights on side effects, dosage, interactions, and more.',
            fontSize: 13.sp,
            color: Colors.white38,
            lineHeight: 1.6,
            maxLines: 4,
            textAlign: TextAlign.center,
          ),
          28.verticalSpace,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: ['💊 Side Effects', '📋 Dosage', '⚠️ Interactions', '💡 Usage Tips', '🔒 Warnings']
                .map(
                  (t) => Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: AppText(t,
                        fontSize: 12.sp, color: Colors.white54),
                  ),
                )
                .toList(),
          ),
          32.verticalSpace,
          _buildCannabisFeatureCard(),
        ],
      ),
    );
  }

  Widget _buildCannabisFeatureCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const CannabisInteractionsScreen()),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_florist_rounded,
                  color: Colors.green, size: 22),
            ),
            14.horizontalSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText('Cannabis & CBD Interactions',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  4.verticalSpace,
                  AppText(
                      'Check if your medicine interacts with Cannabis or CBD',
                      fontSize: 11.sp,
                      color: Colors.white54,
                      lineHeight: 1.4,
                      maxLines: 3),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  // ── No medicine found ─────────────────────────────────

  Widget buildNoMedicineFound() {
    return Padding(
      padding: EdgeInsets.fromLTRB(32.w, 48.h, 32.w, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UIConstants.accentRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                  color: UIConstants.accentRed.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.search_off_rounded,
                size: 34,
                color: UIConstants.accentRed.withValues(alpha: 0.8)),
          ),
          16.verticalSpace,
          AppText(
            'No matching medicine',
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
          10.verticalSpace,
          AppText(
            'We couldn\'t find any medicine matching your search. Try a different keyword or check the spelling.',
            textAlign: TextAlign.center,
            color: Colors.white38,
            fontSize: 13.sp,
            maxLines: 5,
            lineHeight: 1.55,
          ),
        ],
      ),
    );
  }

  // ── Result view ───────────────────────────────────────

  Widget _buildResultView() {
    final item = _currentMedicine!;
    final entries = item.sections.entries.toList();

    // Build flat list: section cards + native ad every 4 items
    final List<Widget> sectionWidgets = [];
    for (int i = 0; i < entries.length; i++) {
      final section = entries[i];
      sectionWidgets.add(CollapsibleCard(
        key: ValueKey(section.key),
        title: section.key,
        content: section.value,
        initiallyExpanded: i < 2,
        medicineName: item.originalName,
      ));
      if ((i + 1) % 4 == 0 && i < entries.length - 1) {
        sectionWidgets.add(const NativeAdCard());
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact medicine header
        Container(
          margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: UIConstants.accentGreen.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      UIConstants.accentGreen.withValues(alpha: 0.2),
                      UIConstants.accentGreen.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.science_rounded,
                    color: UIConstants.accentGreen, size: 17),
              ),
              10.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      item.originalName,
                      color: Colors.white,
                      fontSize: 15.sp,
                      maxLines: 1,
                      fontWeight: FontWeight.w700,
                    ),
                    3.verticalSpace,
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 9, color: UIConstants.accentGreen),
                        4.horizontalSpace,
                        AppText('AI Analysis',
                            fontSize: 10.sp,
                            color: UIConstants.accentGreen,
                            fontWeight: FontWeight.w600),
                        8.horizontalSpace,
                        Container(width: 1, height: 10, color: Colors.white12),
                        8.horizontalSpace,
                        AppText('${entries.length} sections',
                            fontSize: 10.sp, color: Colors.white30),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _exportPdf(item),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      size: 16, color: Colors.blueAccent),
                ),
              ),
              6.horizontalSpace,
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddReminderScreen(initialMedicineName: item.originalName),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: UIConstants.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      size: 16, color: UIConstants.accentGreen),
                ),
              ),
            ],
          ),
        ),
        10.verticalSpace,
        // Sections with native ads injected
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: sectionWidgets
                .map((w) => Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: w,
                    ))
                .toList(),
          ),
        ),
        16.verticalSpace,
      ],
    );
  }



  // ── History bar ───────────────────────────────────────

  Widget _buildHistoryBar() {
    return Container(
      color: UIConstants.darkBackgroundEnd,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MedicineHistoryScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.history_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.5)),
              label: AppText(
                'View Full History',
                fontSize: 13.sp,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isForScreenShots) ...[
            4.verticalSpace,
            AppText(
              'Disclaimer: AI-generated info for educational purposes only. Always consult a doctor.',
              textAlign: TextAlign.center,
              fontSize: 9.sp,
              color: Colors.white24,
              lineHeight: 1.3,
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}
