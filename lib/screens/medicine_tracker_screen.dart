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
  final MedicineRepository repo = MedicineRepository();
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  /// Instead of map, store the actual typed model
  MedicineItem? _currentMedicine;

  /// Recent canonical names
  List<String> _recentCanonicals = [];

  /// Chips to display (MedicineItem)
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

  // -------------------------------------------------------------
  // RECENT SEARCHES
  // -------------------------------------------------------------
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    _recentCanonicals = prefs.getStringList("recent_canonicals") ?? [];
  }

  Future<void> _addToRecentSearches(String canonical) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove duplicates
    _recentCanonicals.removeWhere((e) => e == canonical);

    // Add on top
    _recentCanonicals.insert(0, canonical);

    // Keep limit
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
      _filteredChips = _chipMedicines; // Always show all
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

  // -------------------------------------------------------------
  // SEARCH SUGGESTIONS (case-insensitive)
  // -------------------------------------------------------------
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

  // -------------------------------------------------------------
  // PERFORM SEARCH (NO duplicate API calls)
  // -------------------------------------------------------------
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
      // 🔔 Notify user if no token was used
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Constants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm),
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
      body: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TokenPurchaseScreen(currentTokens: 10),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.appPrimaryRedColor,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: const Text(
                "Purchase",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12.w),
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0D3A0D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.lock_open, color: Colors.greenAccent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Search once → Access forever!\nNo token used on previously searched medicines ✔️",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.greenAccent,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 8.h),

          // SEARCH ROW (UNTOUCHED)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomTextField(
                        hintText: 'Search medicine...',
                        prefixIcon: AppAssets.icSearch,
                        controller: _controller,
                        showDividerOnSuffixIcon: false,
                        onChanged: _onSearchTextChanged,
                        isSearchView: true,
                        showCancelButton: true, // cross icon remains
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    _searchMedicine();
                    _combineMedicines(resetFilter: true);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(70),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 5.h),
          _buildMedicineChips(),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),

          if (_currentMedicine != null) Expanded(child: _buildResultView()),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MedicineHistoryScreen(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.appPrimaryRedColor,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
                child: const Text(
                  "View History",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "*This app provides AI-generated info. Consult a doctor before taking any medication.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final item = _currentMedicine!;
    final entries = item.sections.entries.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Results for: ${item.originalName}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_alert,
                  size: 20,
                  color: Colors.greenAccent,
                ),
                tooltip: 'Set reminder for this medicine',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddReminderScreen(initialMedicineName: item.originalName),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: entries.asMap().entries.map((entry) {
              final index = entry.key;
              final section = entry.value;

              return CollapsibleCard(
                key: ValueKey(section.key),
                title: section.key,
                content: section.value,
                initiallyExpanded: index < 2,
                medicineName: item.originalName,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineChips() {
    if (_filteredChips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filteredChips.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: EdgeInsets.only(right: 6.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12, width: 0.8),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        _controller.text = item.originalName;
                        _searchMedicine();
                        _combineMedicines(resetFilter: true);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          item.originalName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _deleteChipMedicine(item.originalName),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(alpha: 0.8),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
