import 'package:ai_medicine_tracker/helper/app_assets.dart';
import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/repository/medicine_repository.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:ai_medicine_tracker/widgets/collapsible_card.dart';
import 'package:ai_medicine_tracker/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MedicineHistoryScreen extends StatefulWidget {
  const MedicineHistoryScreen({super.key});

  @override
  State<MedicineHistoryScreen> createState() => _MedicineHistoryScreenState();
}

class _MedicineHistoryScreenState extends State<MedicineHistoryScreen> {
  // ---------------------------------------------------------------------------
  // LOGIC (UNTOUCHED)
  // ---------------------------------------------------------------------------
  final MedicineRepository repo = MedicineRepository();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<MedicineItem> _history = [];
  List<MedicineItem> _filteredHistory = [];

  MedicineItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await repo.ensureLoaded();
    final all = repo.getAllCachedItems();

    // Latest first
    all.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    _history = all;
    _filteredHistory = all;

    setState(() => _isLoading = false);
  }

  void _searchHistory(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredHistory = _history
          .where((item) => item.originalName.toLowerCase().contains(q))
          .toList();
    });
  }

  String _groupTitle(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return "Today";
    }
    if (now.difference(date).inDays <= 7) {
      return "This Week";
    }
    return "Earlier";
  }

  Future<void> _deleteFromHistory(MedicineItem item) async {
    await repo.deleteMedicine(item.canonicalName);

    setState(() {
      _history.remove(item);
      _filteredHistory.remove(item);
      if (_selectedItem == item) _selectedItem = null;
    });

    Utils.showToast(context, message: "Removed from history 🗑");
  }

  Future<bool> _confirmDelete(MedicineItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          // Dark Theme Surface
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: AppText(
            "Remove from History?",
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          content: AppText(
            "Are you sure you want to delete '${item.originalName}'? This action cannot be undone.",
            color: Colors.white70,
            maxLines: 20,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: AppText("Cancel", color: Colors.white54),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Confirm
              child: const AppText(
                "Delete",
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  // ---------------------------------------------------------------------------
  // IMPROVED UI BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedItem == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedItem != null) {
          setState(() => _selectedItem = null);
        }
      },
      child: Scaffold(
        backgroundColor: UIConstants.darkBackgroundStart,
        appBar: AppBar(
          backgroundColor: UIConstants.darkBackgroundStart,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              if (_selectedItem != null) {
                setState(() => _selectedItem = null);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: AppText(
            _selectedItem == null ? "History" : "Details",
            color: Colors.white,
            fontSize: 18.sp,
            maxLines: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: UIConstants.accentGreen,
                ),
              )
            : _selectedItem == null
            ? _buildHistoryList()
            : _buildDetails(_selectedItem!),
      ),
    );
  }

  // 📌 LIST VIEW
  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const AppText("No history found.", color: Colors.white38),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 🔍 Search bar (Compact)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          child: CustomTextField(
            hintText: "Search history…",
            prefixIcon: AppAssets.icSearch,
            controller: _searchController,
            showDividerOnSuffixIcon: false,
            onChanged: _searchHistory,
            isSearchView: true,
            showCancelButton: true,
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: _filteredHistory.length,
            itemBuilder: (_, index) {
              final item = _filteredHistory[index];
              final title = _groupTitle(item.lastUsedAt);

              final showHeader =
                  index == 0 ||
                  title != _groupTitle(_filteredHistory[index - 1].lastUsedAt);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader)
                    Padding(
                      padding: EdgeInsets.fromLTRB(10.w, 12.h, 8.w, 4.h),
                      child: AppText(
                        title.toUpperCase(),
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11.sp,
                        maxLines: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),

                  _buildHistoryCard(item),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // 📌 INDIVIDUAL CARD ITEM
  Widget _buildHistoryCard(MedicineItem item) {
    return Dismissible(
      key: ValueKey(item.canonicalName),
      // Unique Key is required
      direction: DismissDirection.endToStart,
      // Swipe right-to-left

      // 1. CONFIRM BEFORE SWIPE
      confirmDismiss: (direction) async {
        return await _confirmDelete(item);
      },

      // 2. ACTION ON SWIPE COMPLETE
      onDismissed: (direction) {
        _deleteFromHistory(item);
      },

      // 3. RED BACKGROUND BEHIND CARD
      background: Container(
        margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.redAccent,
          size: 28,
        ),
      ),

      // 4. ACTUAL CARD CONTENT
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04), // Soft Fill
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _selectedItem = item),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              child: Row(
                children: [
                  // Soft Icon Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: UIConstants.accentGreen.withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.medication_rounded,
                      color: UIConstants.accentGreen,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 10.w),

                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          item.originalName,
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                          maxLines: 20,
                          color: Colors.white,
                        ),
                        SizedBox(height: 1.h),
                        AppText(
                          "Tap to view details",
                          fontSize: 12.sp,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),

                  // Delete Action (Subtle)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: "Remove from history",
                    // 5. CONFIRM BEFORE CLICK DELETE
                    onPressed: () async {
                      final confirm = await _confirmDelete(item);
                      if (confirm) {
                        _deleteFromHistory(item);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 📌 DETAILS VIEW (Consistent with Main Screen)
  Widget _buildDetails(MedicineItem item) {
    final entries = item.sections.entries.toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // 🔹 Same Header as Result View
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: UIConstants.accentGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.science_rounded,
                    color: UIConstants.accentGreen,
                    size: 24,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        item.originalName,
                        color: Colors.white,
                        fontSize: 20.sp,
                        maxLines: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: AppText(
                          "Saved in History",
                          color: Colors.white70,
                          fontSize: 11.sp,
                          maxLines: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 10),

          // 🔹 Collapsible Cards
          ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (c, i) => SizedBox(height: 8.h),
            itemBuilder: (_, index) {
              final e = entries[index];
              return CollapsibleCard(
                key: ValueKey(e.key),
                title: e.key,
                content: e.value,
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
}
