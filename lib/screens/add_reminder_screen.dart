import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/medicine_reminder.dart';
import '../services/reminder_service.dart';

class AddReminderScreen extends StatefulWidget {
  final String? initialMedicineName;
  final String? familyMemberId;
  final MedicineReminder? existingReminder; // non-null = edit mode

  const AddReminderScreen({
    super.key,
    this.initialMedicineName,
    this.familyMemberId,
    this.existingReminder,
  });

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final TextEditingController _nameController = TextEditingController();
  TimeOfDay? _time;
  bool _repeatDaily = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingReminder != null) {
      _nameController.text = widget.existingReminder!.medicineName;
      _time = TimeOfDay(
        hour: widget.existingReminder!.hour,
        minute: widget.existingReminder!.minute,
      );
      _repeatDaily = widget.existingReminder!.repeatDaily;
    } else {
      _nameController.text = widget.initialMedicineName ?? '';
      _time = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: UIConstants.accentGreen,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                  foregroundColor: UIConstants.accentGreen),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 18),
              8.horizontalSpace,
              AppText('Enter medicine name and select time',
                  color: Colors.white, fontSize: 13.sp),
            ],
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 400));

    if (widget.existingReminder != null) {
      await ReminderService.instance.editReminder(
        widget.existingReminder!,
        medicineName: name,
        hour: _time!.hour,
        minute: _time!.minute,
        repeatDaily: _repeatDaily,
      );
    } else {
      await ReminderService.instance.addReminder(
        medicineName: name,
        hour: _time!.hour,
        minute: _time!.minute,
        repeatDaily: _repeatDaily,
        familyMemberId: widget.familyMemberId,
      );
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.25, 1.0],
              colors: [
                Color(0xFF071209),
                Color(0xFF121212),
                Color(0xFF1A1A1A),
              ],
            ),
          ),
          child: SafeArea(
            child: AbsorbPointer(
              absorbing: _saving,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTimeSection(),
                          24.verticalSpace,
                          _buildNameSection(),
                          20.verticalSpace,
                          _buildRepeatSection(),
                          20.verticalSpace,
                          _buildInfoNote(),
                        ],
                      ),
                    ),
                  ),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 20.w, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white54, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  widget.existingReminder != null ? 'Edit Reminder' : 'Add Reminder',
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                AppText(
                  widget.existingReminder != null ? 'Update time and medicine name' : 'Set time to never miss a dose',
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

  // ── Time section ──────────────────────────────────────

  Widget _buildTimeSection() {
    final hour12 = (_time?.hourOfPeriod ?? 0) == 0 ? 12 : (_time?.hourOfPeriod ?? 12);
    final minute = (_time?.minute ?? 0).toString().padLeft(2, '0');
    final period = _time?.period == DayPeriod.am ? 'AM' : 'PM';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time_rounded,
                color: Colors.white38, size: 14),
            6.horizontalSpace,
            AppText('Reminder Time',
                fontSize: 12.sp,
                color: Colors.white38,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4),
          ],
        ),
        12.verticalSpace,
        GestureDetector(
          onTap: _pickTime,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 24.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: UIConstants.accentGreen.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: UIConstants.accentGreen.withValues(alpha: 0.06),
                  blurRadius: 24,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText(
                      '$hour12:$minute',
                      fontSize: 52.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8.h, left: 8.w),
                      child: AppText(
                        period,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: UIConstants.accentGreen,
                      ),
                    ),
                  ],
                ),
                10.verticalSpace,
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: UIConstants.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded,
                          color: UIConstants.accentGreen, size: 12),
                      5.horizontalSpace,
                      AppText(
                        'Tap to change time',
                        fontSize: 11.sp,
                        color: UIConstants.accentGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Medicine name section ─────────────────────────────

  Widget _buildNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.medication_rounded,
                color: Colors.white38, size: 14),
            6.horizontalSpace,
            AppText('Medicine Name',
                fontSize: 12.sp,
                color: Colors.white38,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4),
          ],
        ),
        10.verticalSpace,
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: _nameController,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
            ),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'e.g. Paracetamol 500mg',
              hintStyle: TextStyle(
                color: Colors.white30,
                fontSize: 15.sp,
              ),
              prefixIcon: const Icon(Icons.medication_outlined,
                  color: Colors.white30, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w, vertical: 14.h),
            ),
          ),
        ),
      ],
    );
  }

  // ── Repeat section ────────────────────────────────────

  Widget _buildRepeatSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _repeatDaily
                  ? UIConstants.accentGreen.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.repeat_rounded,
              color: _repeatDaily ? UIConstants.accentGreen : Colors.white38,
              size: 18,
            ),
          ),
          14.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Repeat Daily',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                3.verticalSpace,
                AppText(
                  _repeatDaily
                      ? 'Fires every day at this time'
                      : 'Fires only once',
                  fontSize: 11.sp,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: _repeatDaily,
              activeTrackColor: UIConstants.accentGreen,
              activeThumbColor: Colors.black,
              inactiveTrackColor: Colors.white10,
              inactiveThumbColor: Colors.grey,
              onChanged: (v) => setState(() => _repeatDaily = v),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info note ─────────────────────────────────────────

  Widget _buildInfoNote() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.amber, size: 14),
          8.horizontalSpace,
          Expanded(
            child: AppText(
              'Make sure notifications are enabled in your phone settings for reminders to work.',
              fontSize: 11.sp,
              color: Colors.amber.shade200.withValues(alpha: 0.7),
              lineHeight: 1.5,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Save button ───────────────────────────────────────

  Widget _buildSaveButton() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, bottomPad + 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: UIConstants.accentGreen,
            foregroundColor: Colors.black,
            disabledBackgroundColor:
                UIConstants.accentGreen.withValues(alpha: 0.3),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.black),
                )
              : AppText(
                  'Save Reminder',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
        ),
      ),
    );
  }
}
