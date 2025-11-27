import 'dart:async';
import 'dart:developer';

import 'package:ai_medicine_tracker/helper/app_assets.dart';
import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/repository/medicine_repository.dart';
import 'package:ai_medicine_tracker/screens/add_reminder_screen.dart';
import 'package:ai_medicine_tracker/screens/medicine_history_screen.dart';
import 'package:ai_medicine_tracker/screens/reminders_screen.dart';
import 'package:ai_medicine_tracker/screens/token_purchase_screen.dart';
import 'package:ai_medicine_tracker/widgets/collapsible_card.dart';
import 'package:ai_medicine_tracker/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicineTrackerScreen extends StatefulWidget {
  const MedicineTrackerScreen({super.key});

  @override
  State<MedicineTrackerScreen> createState() => _MedicineTrackerScreenState();
}

class _MedicineTrackerScreenState extends State<MedicineTrackerScreen> {
  // ---------------------------------------------------------------------------
  // LOGIC SECTION (UNTOUCHED)
  // ---------------------------------------------------------------------------
  final MedicineRepository repo = MedicineRepository();
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  MedicineItem? _currentMedicine;
  List<String> _recentCanonicals = [];
  List<MedicineItem> _chipMedicines = [];
  List<MedicineItem> _filteredChips = [];

  @override
  void initState() {
    super.initState();
    _initLogic();
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
    _recentCanonicals = prefs.getStringList("recent_canonicals") ?? [];
  }

  Future<void> _addToRecentSearches(String canonical) async {
    final prefs = await SharedPreferences.getInstance();
    _recentCanonicals.removeWhere((e) => e == canonical);
    _recentCanonicals.insert(0, canonical);
    if (_recentCanonicals.length > 50) {
      _recentCanonicals = _recentCanonicals.sublist(0, 50);
    }
    await prefs.setStringList("recent_canonicals", _recentCanonicals);
  }

  void _combineMedicines({bool resetFilter = false}) {
    final all = repo.getAllCachedItems();
    all.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    _chipMedicines = all;

    if (resetFilter) {
      _filteredChips = _chipMedicines;
    } else {
      final query = _controller.text.trim().toLowerCase();
      if (query.isEmpty) {
        _filteredChips = _chipMedicines;
      } else {
        _filteredChips = _chipMedicines
            .where((item) => item.originalName.toLowerCase().contains(query))
            .toList();
      }
    }
    setState(() {});
  }

  void _onSearchTextChanged(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredChips = _chipMedicines;
      });
      return;
    }
    setState(() {
      _filteredChips = _chipMedicines
          .where((item) => item.originalName.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _searchMedicine() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentMedicine = null;
    });

    try {
      final medicine = await repo.fetchMedicine(name);
      _currentMedicine = medicine;
      if (medicine.fromCache) {
        Utils.showNoTokenUsed(context);
      } else {
        Utils.showTokenUsed(context);
      }
      await _addToRecentSearches(medicine.canonicalName);
    } catch (e, st) {
      log("❌ Error: $e\n$st");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteChipMedicine(String originalName) async {
    final canonical = originalName.toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    _recentCanonicals.removeWhere((e) => e == canonical);
    await prefs.setStringList("recent_canonicals", _recentCanonicals);
    await repo.deleteMedicine(canonical);
    _combineMedicines();
  }

  // ---------------------------------------------------------------------------
  // IMPROVED UI BUILD METHOD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Using a SafeArea + Gradient Background for a premium feel
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: UIConstants.darkBackgroundStart,
      appBar: AppBar(
        backgroundColor: UIConstants.darkBackgroundStart,
        elevation: 0,
        title: Text(
          Constants.appName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm, color: Colors.white),
            tooltip: 'Reminders',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              UIConstants.darkBackgroundStart,
              UIConstants.darkBackgroundEnd,
            ],
          ),
        ),
        child: Column(
          children: [
            // 1. TOP INFO SECTION (Scrollable if height is small)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildPurchaseButton(),
                    _buildInfoBanner(),
                    SizedBox(height: 16),
                    // Using standard double instead of .h for safety in snippet
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildMedicineChips(),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: UIConstants.accentGreen,
                          ),
                        ),
                      ),
                    // If we have results, they take over the space below
                    if (_currentMedicine != null) _buildResultView(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // --- UI WIDGETS ---

  Widget _buildPurchaseButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TokenPurchaseScreen(currentTokens: 10),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          // ✨ Gradient looks premium but takes less space visually
          gradient: LinearGradient(
            colors: [
              AppColors.appPrimaryRedColor.withValues(alpha: 0.8),
              const Color(0xFF8B0000),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 20),
                SizedBox(width: 10.w),
                const Text(
                  "Get Premium Tokens",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0D3A0D).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.greenAccent,
            size: 16,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              "Search once → Access forever! No tokens needed for previously searched items.",
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.greenAccent,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    // Define a fixed, compact height for both elements
    const double componentHeight = 46.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: CustomTextField(
              hintText: 'Search medicine...',
              prefixIcon: AppAssets.icSearch,
              // Or use Icons.search if asset fails
              controller: _controller,
              showDividerOnSuffixIcon: false,
              onChanged: _onSearchTextChanged,
              isSearchView: true,
              showCancelButton: true,
              // Pass a specific height if you want to control it from outside,
              // otherwise CustomTextField uses default compact height.
            ),
          ),
          const SizedBox(width: 10),
          // Reduced gap
          InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              _searchMedicine();
              _combineMedicines(resetFilter: true);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: componentHeight,
              width: componentHeight, // Square button
              decoration: BoxDecoration(
                // Using a softer color/gradient looks better than solid primary sometimes
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.search_rounded,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 22, // Smaller icon
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineChips() {
    if (_filteredChips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          child: Text(
            "Recent Searches",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Row(
              children: _filteredChips.map((item) {
                return Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 8),
                  child: Material(
                    color: UIConstants.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        _controller.text = item.originalName;
                        _searchMedicine();
                        _combineMedicines(resetFilter: true);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.originalName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () =>
                                  _deleteChipMedicine(item.originalName),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white70,
                                  size: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final item = _currentMedicine!;
    final entries = item.sections.entries.toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: UIConstants.darkBackgroundStart,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: UIConstants.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.science_outlined,
                    color: UIConstants.accentGreen,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.originalName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "AI Analysis Result",
                        style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  ),
                  icon: const Icon(
                    Icons.notification_add_outlined,
                    size: 22,
                    color: UIConstants.accentGreen,
                  ),
                  tooltip: 'Set reminder',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddReminderScreen(
                          initialMedicineName: item.originalName,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Scroll is handled by parent
            itemCount: entries.length,
            separatorBuilder: (c, i) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              final section = entries[index];
              return CollapsibleCard(
                key: ValueKey(section.key),
                title: section.key,
                content: section.value,
                initiallyExpanded: index < 2,
                medicineName: item.originalName,
              );
            },
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 5.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: SizedBox(
              width: double.infinity,
              height: 45.h,
              // ✨ Matches the height of your Search Bar/Inputs
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MedicineHistoryScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  // ✨ Soft background fill (matches your text fields)
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  // ✨ Much softer border color
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  // ✨ Softer rounded corners (matches cards)
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // ✨ Splash effect when tapped
                  overlayColor: Colors.white.withValues(alpha: 0.1),
                ),
                icon: Icon(
                  Icons.history_rounded, // Rounded icon looks friendlier
                  size: 20,
                  color: Colors.white.withValues(
                    alpha: 0.7,
                  ), // Slightly dimmed icon
                ),
                label: Text(
                  "View History",
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          Text(
            "*This app provides AI-generated info. Consult a doctor before taking any medication.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9.sp, color: Colors.grey, height: 1),
          ),
        ],
      ),
    );
  }
}
