import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/models/family_member.dart';
import 'package:ai_medicine_tracker/screens/paywall_screen.dart';
import 'package:ai_medicine_tracker/services/admob_service.dart';
import 'package:ai_medicine_tracker/services/subscription_service.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:ai_medicine_tracker/widgets/banner_ad_widget.dart';
import 'package:ai_medicine_tracker/widgets/native_ad_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  List<FamilyMember> _family = [];

  static const List<Color> _colors = [
    Color(0xFF00E676), Color(0xFF2979FF), Color(0xFFFF6D00),
    Color(0xFFD500F9), Color(0xFFFF1744), Color(0xFF00B8D4),
    Color(0xFFFFD600), Color(0xFF69F0AE),
  ];

  bool get _isPro => SubscriptionService.instance.isPro;

  @override
  void initState() {
    super.initState();
    _load();
    // Show interstitial when entering this screen
    AdmobService.instance.onNewSearch();
  }

  void _load() => setState(() => _family = FamilyMember.loadAll());

  int get _memberLimit => _isPro ? 20 : 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      appBar: AppBar(
        backgroundColor: UIConstants.darkBackgroundStart,
        elevation: 0,
        title: AppText(
          'Family Members',
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded,
                color: UIConstants.accentGreen),
            onPressed: _addMember,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _family.isEmpty ? _buildEmpty() : _buildList(),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: UIConstants.accentGreen.withValues(alpha: 0.08),
                border: Border.all(
                    color: UIConstants.accentGreen.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.group_rounded,
                  color: UIConstants.accentGreen, size: 40),
            ),
            24.verticalSpace,
            AppText(
              'Add Family Members',
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              textAlign: TextAlign.center,
            ),
            12.verticalSpace,
            AppText(
              'Track medications and reminders for your family members separately. Free plan supports up to 2 members.',
              fontSize: 13.sp,
              color: Colors.white54,
              textAlign: TextAlign.center,
              lineHeight: 1.5,
              maxLines: 5,
            ),
            28.verticalSpace,
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _addMember,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UIConstants.accentGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: AppText(
                  'Add First Member',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = <Widget>[];

    // Limit info banner
    items.add(_buildLimitBanner());
    items.add(16.verticalSpace);

    for (int i = 0; i < _family.length; i++) {
      items.add(_buildCard(_family[i]));
      if ((i + 1) % 2 == 0) items.add(const NativeAdCard());
    }

    // Add button at end if below limit
    if (_family.length < _memberLimit) {
      items.add(12.verticalSpace);
      items.add(_buildAddButton());
    }

    items.add(24.verticalSpace);

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      children: items,
    );
  }

  Widget _buildLimitBanner() {
    final used = _family.length;
    final limit = _memberLimit;
    final remaining = limit - used;
    final color = remaining > 0 ? UIConstants.accentGreen : Colors.orange;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            remaining > 0 ? Icons.group_rounded : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          10.horizontalSpace,
          Expanded(
            child: AppText(
              remaining > 0
                  ? '$used of $limit members used · $remaining remaining'
                  : _isPro
                      ? 'Maximum 5 members reached (Pro)'
                      : 'Free limit reached (2/2) · Upgrade for 5 members',
              fontSize: 12.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!_isPro && remaining == 0) ...[
            8.horizontalSpace,
            GestureDetector(
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PaywallScreen()));
                setState(() {});
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AppText('Upgrade',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(FamilyMember m) {
    final color = _colors[m.colorIndex % _colors.length];
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Center(
              child: AppText(
                m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          14.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(m.name,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
                3.verticalSpace,
                AppText(
                  'Added ${_formatDate(m.createdAt)}',
                  fontSize: 11.sp,
                  color: Colors.white30,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.white24, size: 20),
            onPressed: () => _deleteMember(m),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _addMember,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: UIConstants.accentGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: UIConstants.accentGreen.withValues(alpha: 0.25),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_rounded,
                color: UIConstants.accentGreen, size: 18),
            10.horizontalSpace,
            AppText('Add Family Member',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: UIConstants.accentGreen),
          ],
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _addMember() async {
    if (_family.length >= _memberLimit) {
      if (!_isPro) {
        Utils.showMessage(
          context,
          'Free plan supports up to 2 members. Upgrade for 5.',
          isError: true,
        );
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
        setState(() {});
      }
      return;
    }

    final ctrl = TextEditingController();
    int colorIdx = _family.length % _colors.length;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Add Family Member',
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
                16.verticalSpace,
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Name (e.g. Mom, Dad, Child)',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 12.h),
                  ),
                ),
                16.verticalSpace,
                AppText('Color', fontSize: 12.sp, color: Colors.white38),
                10.verticalSpace,
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    _colors.length,
                    (i) => GestureDetector(
                      onTap: () => setLocal(() => colorIdx = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _colors[i],
                          shape: BoxShape.circle,
                          border: colorIdx == i
                              ? Border.all(color: Colors.white, width: 2.5)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                20.verticalSpace,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const AppText('Cancel', color: Colors.white38),
                      ),
                    ),
                    12.horizontalSpace,
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final n = ctrl.text.trim();
                          if (n.isNotEmpty) Navigator.pop(ctx, n);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UIConstants.accentGreen,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: AppText('Add',
                            fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Don't dispose ctrl here — the dialog may still be animating out.
    // It is a local variable and will be GC'd after this scope.
    if (name == null) return;
    await FamilyMember.add(name, colorIdx);
    _load();
  }

  Future<void> _deleteMember(FamilyMember m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: UIConstants.darkBackgroundEnd,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppText('Remove ${m.name}?',
            fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.bold),
        content: AppText(
            'Their medications and reminders will stay but will be unlinked.',
            fontSize: 13.sp,
            color: Colors.white54),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Cancel', color: Colors.white38)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Remove', color: UIConstants.accentRed)),
        ],
      ),
    );
    if (confirmed != true) return;
    await FamilyMember.remove(m.id);
    _load();
  }
}
