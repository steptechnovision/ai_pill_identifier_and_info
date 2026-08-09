import 'package:ai_medicine_tracker/helper/app_assets.dart';
import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/repository/medicine_repository.dart';
import 'package:ai_medicine_tracker/services/admob_service.dart';
import 'package:ai_medicine_tracker/services/pdf_export_service.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:ai_medicine_tracker/widgets/collapsible_card.dart';
import 'package:ai_medicine_tracker/widgets/custom_text_field.dart';
import 'package:ai_medicine_tracker/widgets/native_ad_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MedicineHistoryScreen extends StatefulWidget {
  const MedicineHistoryScreen({super.key});

  @override
  State<MedicineHistoryScreen> createState() => _MedicineHistoryScreenState();
}

class _MedicineHistoryScreenState extends State<MedicineHistoryScreen> {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    await repo.ensureLoaded();
    final all = repo.getAllCachedItems();
    all.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    if (mounted) {
      setState(() {
        _history = all;
        _filteredHistory = all;
        _isLoading = false;
      });
    }
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
    if (timestamp == 0) return 'Today';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    if (now.difference(date).inDays <= 7) return 'This Week';
    return 'Earlier';
  }

  String _relativeDate(int timestamp) {
    if (timestamp == 0) return 'Today';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
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

  Future<void> _deleteFromHistory(MedicineItem item) async {
    await repo.deleteMedicine(item.canonicalName);
    setState(() {
      _history.remove(item);
      _filteredHistory.remove(item);
      if (_selectedItem == item) _selectedItem = null;
    });
    if (mounted) Utils.showToast(context, message: 'Removed from history');
  }

  Future<bool> _confirmDelete(MedicineItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 26),
              ),
              16.verticalSpace,
              AppText('Remove from History?',
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              10.verticalSpace,
              AppText(
                '"${item.originalName}" will be permanently removed.',
                fontSize: 13.sp,
                color: Colors.white54,
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
              20.verticalSpace,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: AppText('Cancel',
                          fontSize: 14.sp, color: Colors.white54),
                    ),
                  ),
                  12.horizontalSpace,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: AppText('Remove',
                          fontSize: 14.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed ?? false;
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedItem == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedItem != null) {
          setState(() => _selectedItem = null);
        }
      },
      child: Scaffold(
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
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: UIConstants.accentGreen, strokeWidth: 2),
                        )
                      : _selectedItem == null
                          ? _buildHistoryList()
                          : _buildDetailView(_selectedItem!),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────

  Widget _buildHeader() {
    final isDetail = _selectedItem != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 20.w, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white54, size: 20),
            onPressed: () {
              if (isDetail) {
                setState(() => _selectedItem = null);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  isDetail ? _selectedItem!.originalName : 'Search History',
                  fontSize: isDetail ? 16.sp : 19.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  maxLines: 1,
                ),
                if (!isDetail)
                  AppText(
                    '${_history.length} medicine${_history.length == 1 ? '' : 's'} saved',
                    fontSize: 11.sp,
                    color: Colors.white38,
                  ),
                if (isDetail)
                  AppText(
                    'Saved in history',
                    fontSize: 11.sp,
                    color: Colors.white38,
                  ),
              ],
            ),
          ),
          if (isDetail)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: UIConstants.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 10, color: UIConstants.accentGreen),
                  4.horizontalSpace,
                  AppText('AI Analysis',
                      fontSize: 10.sp,
                      color: UIConstants.accentGreen,
                      fontWeight: FontWeight.w600),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── History list ──────────────────────────────────────

  Widget _buildHistoryList() {
    if (_history.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
          child: CustomTextField(
            hintText: 'Search history…',
            prefixIcon: AppAssets.icSearch,
            controller: _searchController,
            showDividerOnSuffixIcon: false,
            onChanged: _searchHistory,
            isSearchView: true,
            showCancelButton: true,
          ),
        ),
        if (_filteredHistory.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 40, color: Colors.white24),
                  16.verticalSpace,
                  AppText('No results found',
                      fontSize: 15.sp, color: Colors.white38),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
              itemCount: _filteredHistory.length,
              itemBuilder: (_, index) {
                final item = _filteredHistory[index];
                final title = _groupTitle(item.lastUsedAt);
                final showHeader = index == 0 ||
                    title !=
                        _groupTitle(_filteredHistory[index - 1].lastUsedAt);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeader) _buildGroupHeader(title),
                    _buildHistoryCard(item),
                    // Native ad every 5 items
                    if ((index + 1) % 5 == 0) const NativeAdCard(),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Empty state ───────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  UIConstants.accentGreen.withValues(alpha: 0.12),
                  UIConstants.accentGreen.withValues(alpha: 0.03),
                ],
              ),
              border: Border.all(
                  color: UIConstants.accentGreen.withValues(alpha: 0.18)),
            ),
            child: Icon(Icons.history_rounded,
                size: 36,
                color: UIConstants.accentGreen.withValues(alpha: 0.5)),
          ),
          24.verticalSpace,
          AppText('No history yet',
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white),
          10.verticalSpace,
          AppText(
            'Medicines you search will appear\nhere for quick access.',
            fontSize: 13.sp,
            color: Colors.white38,
            lineHeight: 1.6,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Group header ──────────────────────────────────────

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, bottom: 8.h),
      child: Row(
        children: [
          AppText(
            title.toUpperCase(),
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white30,
            letterSpacing: 1.0,
          ),
          12.horizontalSpace,
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }

  // ── History card ──────────────────────────────────────

  Widget _buildHistoryCard(MedicineItem item) {
    return Dismissible(
      key: ValueKey(item.canonicalName),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(item),
      onDismissed: (_) => _deleteFromHistory(item),
      background: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 22),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _selectedItem = item),
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          UIConstants.accentGreen.withValues(alpha: 0.18),
                          UIConstants.accentGreen.withValues(alpha: 0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medication_rounded,
                        color: UIConstants.accentGreen, size: 18),
                  ),
                  12.horizontalSpace,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          item.originalName,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          maxLines: 1,
                        ),
                        4.verticalSpace,
                        AppText(
                          _relativeDate(item.lastUsedAt),
                          fontSize: 11.sp,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.2), size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Detail view ───────────────────────────────────────

  Widget _buildDetailView(MedicineItem item) {
    final entries = item.sections.entries.toList();

    // Build flat list: section cards + native ad every 4 items
    final List<Widget> sectionWidgets = [];
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      sectionWidgets.add(CollapsibleCard(
        key: ValueKey(e.key),
        title: e.key,
        content: e.value,
        initiallyExpanded: i < 2,
        medicineName: item.originalName,
      ));
      if ((i + 1) % 4 == 0 && i < entries.length - 1) {
        sectionWidgets.add(const NativeAdCard());
      }
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact medicine header
          Container(
            margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
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
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        maxLines: 1,
                      ),
                      3.verticalSpace,
                      Row(
                        children: [
                          const Icon(Icons.history_rounded,
                              size: 9, color: Colors.white38),
                          4.horizontalSpace,
                          Flexible(
                            child: AppText(
                              'Last viewed ${_relativeDate(item.lastUsedAt)}',
                              fontSize: 10.sp,
                              color: Colors.white38,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
                      color: Colors.blueAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        size: 15, color: Colors.blueAccent),
                  ),
                ),
                8.horizontalSpace,
                GestureDetector(
                  onTap: () async {
                    if (await _confirmDelete(item)) {
                      _deleteFromHistory(item);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 15, color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
          10.verticalSpace,
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
      ),
    );
  }
}
