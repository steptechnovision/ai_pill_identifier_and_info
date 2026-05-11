import 'dart:async';

import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/models/family_member.dart';
import 'package:ai_medicine_tracker/services/adherence_service.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:ai_medicine_tracker/widgets/native_ad_card.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/medicine_reminder.dart';
import '../services/reminder_service.dart';
import 'add_reminder_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _notifGranted = true;
  List<MedicineReminder> _reminders = [];
  List<FamilyMember> _family = [];
  String? _selectedMemberId; // null = "Me"
  StreamSubscription<void>? _changeSub;
  StreamSubscription<void>? _adherenceSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _checkNotifPermission();
    _changeSub = ReminderService.instance.onChanged.listen((_) => _load());
    _adherenceSub =
        AdherenceService.instance.onChanged.listen((_) => setState(() {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkNotifPermission();
  }

  Future<void> _checkNotifPermission() async {
    final granted = await ReminderService.instance.areNotificationsEnabled();
    if (mounted) setState(() => _notifGranted = granted);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changeSub?.cancel();
    _adherenceSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final list = ReminderService.instance.getReminders();
    final family = FamilyMember.loadAll();
    if (mounted) {
      setState(() {
        _reminders = list;
        _family = family;
        _isLoading = false;
      });
    }
  }

  List<MedicineReminder> get _filteredReminders => _reminders
      .where((r) => r.familyMemberId == _selectedMemberId)
      .toList();

  int _getStreak() {
    final activeIds = _filteredReminders
        .where((r) => r.enabled)
        .map((r) => r.id)
        .toList();
    return AdherenceService.instance.getStreak(activeIds);
  }

  Future<void> _toggleTaken(MedicineReminder r) async {
    final taken = AdherenceService.instance.isTakenToday(r.id);
    if (taken) {
      await AdherenceService.instance.unmarkTaken(r.id);
    } else {
      await AdherenceService.instance.markTaken(r.id);
    }
    setState(() {});
  }

  Future<void> _openAdd({String? initialMedicine}) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(
          initialMedicineName: initialMedicine,
          familyMemberId: _selectedMemberId,
        ),
      ),
    );
    if (added == true) _load();
  }

  Future<void> _openEdit(MedicineReminder reminder) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(existingReminder: reminder),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _toggle(MedicineReminder r, bool enabled) async {
    await ReminderService.instance.toggleEnabled(r, enabled);
  }

  Future<void> _delete(MedicineReminder r) async {
    await ReminderService.instance.deleteReminder(r);
  }

  // ── Next reminder helper ──────────────────────────────

  String? _nextReminderLabel() {
    final enabled = _reminders.where((r) => r.enabled).toList();
    if (enabled.isEmpty) return null;

    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;

    MedicineReminder? next;
    int minDiff = 1440;

    for (final r in enabled) {
      final rMin = r.hour * 60 + r.minute;
      int diff = rMin - nowMin;
      if (diff <= 0) diff += 1440;
      if (diff < minDiff) {
        minDiff = diff;
        next = r;
      }
    }

    if (next == null) return null;

    String when;
    if (minDiff < 60) {
      when = 'in ${minDiff}m';
    } else {
      final h = minDiff ~/ 60;
      final m = minDiff % 60;
      when = m == 0 ? 'in ${h}h' : 'in ${h}h ${m}m';
    }
    return '${next.medicineName} · $when';
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReminders;
    final activeCount = filtered.where((r) => r.enabled).length;

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
              _buildHeader(activeCount),
              if (!_notifGranted) _buildNotifPermissionBanner(),
              if (_family.isNotEmpty) _buildPersonSelector(),
              if (!_isLoading && filtered.isNotEmpty) ...[
                _buildStreakBanner(),
                _buildNextReminderBanner(),
              ],
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: UIConstants.accentGreen, strokeWidth: 2),
                      )
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : _buildList(filtered),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  // ── Notification permission banner ────────────────────

  Widget _buildNotifPermissionBanner() {
    return GestureDetector(
      onTap: () async {
        await AppSettings.openAppSettings(type: AppSettingsType.notification);
        _checkNotifPermission();
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_off_rounded,
                color: Colors.amber, size: 18),
            10.horizontalSpace,
            Expanded(
              child: AppText(
                'Notifications are disabled. Reminders won\'t fire until you enable them. Tap to open Settings.',
                fontSize: 12.sp,
                color: Colors.amber,
                lineHeight: 1.4,
                maxLines: 4,
              ),
            ),
            8.horizontalSpace,
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.amber, size: 12),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────

  Widget _buildHeader(int activeCount) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
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
            child: const Icon(Icons.alarm_rounded,
                color: UIConstants.accentGreen, size: 18),
          ),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Reminders',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                AppText(
                  activeCount == 0
                      ? 'No active reminders'
                      : '$activeCount active reminder${activeCount == 1 ? '' : 's'}',
                  fontSize: 11.sp,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Person selector ──────────────────────────────────

  Widget _buildPersonSelector() {
    return SizedBox(
      height: 38.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _personChip(null, 'Me'),
          ..._family.map((m) => _personChip(m.id, m.name)),
        ],
      ),
    );
  }

  Widget _personChip(String? memberId, String label) {
    final isSelected = _selectedMemberId == memberId;
    return GestureDetector(
      onTap: () => setState(() => _selectedMemberId = memberId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(right: 8.w, bottom: 4.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? UIConstants.accentGreen.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? UIConstants.accentGreen.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: AppText(
          label,
          fontSize: 12.sp,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          color: isSelected ? UIConstants.accentGreen : Colors.white54,
        ),
      ),
    );
  }

  // ── Streak banner ─────────────────────────────────────

  Widget _buildStreakBanner() {
    final streak = _getStreak();
    if (streak == 0) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          8.horizontalSpace,
          AppText(
            '$streak day streak — keep it up!',
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: Colors.orange.shade200,
          ),
        ],
      ),
    );
  }

  // ── Next reminder banner ──────────────────────────────

  Widget _buildNextReminderBanner() {
    final label = _nextReminderLabel();
    if (label == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: UIConstants.accentGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: UIConstants.accentGreen.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded,
              color: UIConstants.accentGreen, size: 14),
          8.horizontalSpace,
          AppText(
            'Next up: $label',
            fontSize: 12.sp,
            color: UIConstants.accentGreen,
          ),
        ],
      ),
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
            child: Icon(Icons.alarm_add_rounded,
                size: 36,
                color: UIConstants.accentGreen.withValues(alpha: 0.5)),
          ),
          24.verticalSpace,
          AppText(
            'No reminders yet',
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          10.verticalSpace,
          AppText(
            'Add your medicines and never miss\na dose again.',
            fontSize: 13.sp,
            color: Colors.white38,
            lineHeight: 1.6,
            maxLines: 3,
            textAlign: TextAlign.center,
          ),
          32.verticalSpace,
          GestureDetector(
            onTap: _openAdd,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    UIConstants.accentGreen,
                    UIConstants.accentGreen.withValues(alpha: 0.75),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: UIConstants.accentGreen.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_alarm_rounded,
                      color: Colors.black, size: 18),
                  8.horizontalSpace,
                  AppText(
                    'Add First Reminder',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── List ──────────────────────────────────────────────

  Widget _buildList(List<MedicineReminder> reminders) {
    final items = <Widget>[];
    for (int i = 0; i < reminders.length; i++) {
      items.add(_buildReminderCard(reminders[i]));
      if ((i + 1) % 3 == 0) items.add(const NativeAdCard());
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 100.h),
      children: items,
    );
  }

  // ── Reminder card ─────────────────────────────────────

  Widget _buildReminderCard(MedicineReminder r) {
    final isOn = r.enabled;
    final accentColor =
        isOn ? UIConstants.accentGreen : Colors.white.withValues(alpha: 0.2);

    final hour12 = r.hour % 12 == 0 ? 12 : r.hour % 12;
    final minuteStr = r.minute.toString().padLeft(2, '0');
    final period = r.hour >= 12 ? 'PM' : 'AM';

    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 22),
      ),
      confirmDismiss: (_) => _confirmDelete(r),
      onDismissed: (_) => _delete(r),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: UIConstants.accentGreen.withValues(alpha: 0.05),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              // Time display
              SizedBox(
                width: 72.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppText(
                          '$hour12:$minuteStr',
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          color: isOn ? Colors.white : Colors.white38,
                        ),
                        3.horizontalSpace,
                        Padding(
                          padding: EdgeInsets.only(bottom: 2.h),
                          child: AppText(
                            period,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: isOn
                                ? UIConstants.accentGreen
                                : Colors.white24,
                          ),
                        ),
                      ],
                    ),
                    4.verticalSpace,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: AppText(
                        r.repeatDaily ? 'Daily' : 'Once',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: isOn
                            ? UIConstants.accentGreen
                            : Colors.white30,
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                width: 1,
                height: 44.h,
                color: Colors.white.withValues(alpha: 0.07),
                margin: EdgeInsets.symmetric(horizontal: 14.w),
              ),

              // Medicine info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      r.medicineName,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: isOn ? Colors.white : Colors.white38,
                      maxLines: 1,
                    ),
                    5.verticalSpace,
                    AppText(
                      isOn
                          ? '● Active'
                          : '● Disabled',
                      fontSize: 11.sp,
                      color: isOn
                          ? UIConstants.accentGreen.withValues(alpha: 0.8)
                          : Colors.white24,
                    ),
                  ],
                ),
              ),

              // Controls
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 0.78,
                        child: Switch(
                          value: isOn,
                          activeTrackColor: UIConstants.accentGreen,
                          activeThumbColor: Colors.black,
                          inactiveTrackColor: Colors.white10,
                          inactiveThumbColor: Colors.grey,
                          onChanged: (v) => _toggle(r, v),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openEdit(r),
                        child: Icon(
                          Icons.edit_rounded,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 17,
                        ),
                      ),
                      8.horizontalSpace,
                      GestureDetector(
                        onTap: () async {
                          if (await _confirmDelete(r)) _delete(r);
                        },
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white.withValues(alpha: 0.18),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  if (isOn) ...[
                    4.verticalSpace,
                    _buildTakenButton(r),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Taken button ──────────────────────────────────────

  Widget _buildTakenButton(MedicineReminder r) {
    final taken = AdherenceService.instance.isTakenToday(r.id);
    return GestureDetector(
      onTap: () => _toggleTaken(r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: taken
              ? UIConstants.accentGreen.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: taken
                ? UIConstants.accentGreen.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              taken ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: taken ? UIConstants.accentGreen : Colors.white30,
              size: 12,
            ),
            4.horizontalSpace,
            AppText(
              taken ? 'Taken' : 'Mark',
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: taken ? UIConstants.accentGreen : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirm delete ────────────────────────────────────

  Future<bool> _confirmDelete(MedicineReminder r) async {
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
              AppText('Delete Reminder?',
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              10.verticalSpace,
              AppText(
                'Remove the reminder for "${r.medicineName}"?',
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
                      child: AppText('Cancel', fontSize: 14.sp, color: Colors.white54),
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
                      child: AppText('Delete',
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

  // ── FAB ───────────────────────────────────────────────

  Widget _buildFab() {
    return GestureDetector(
      onTap: _openAdd,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              UIConstants.accentGreen,
              UIConstants.accentGreen.withValues(alpha: 0.75),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: UIConstants.accentGreen.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_alarm_rounded,
            color: Colors.black, size: 26),
      ),
    );
  }
}
