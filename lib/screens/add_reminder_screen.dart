import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/widgets/app_bar_title_view.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:ai_medicine_tracker/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/reminder_service.dart';

class AddReminderScreen extends StatefulWidget {
  final String? initialMedicineName;

  const AddReminderScreen({super.key, this.initialMedicineName});

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
    _nameController.text = widget.initialMedicineName ?? '';
    _time = TimeOfDay.now();
  }

  Future<void> _pickTime() async {
    // ✨ Force Dark Theme for the Time Picker Dialog
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: UIConstants.accentGreen, // Header color
              onPrimary: Colors.black, // Header text color
              surface: Color(0xFF1E1E1E), // Background
              onSurface: Colors.white, // Text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: UIConstants.accentGreen,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: const AppText(
            'Please enter medicine name and select time',
            color: Colors.white,
            maxLines: 5,
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    // Simulate network/db delay for smooth UX
    await Future.delayed(const Duration(milliseconds: 500));

    await ReminderService.instance.addReminder(
      medicineName: name,
      hour: _time!.hour,
      minute: _time!.minute,
      repeatDaily: _repeatDaily,
    );

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      // Close keyboard on tap outside
      child: Scaffold(
        backgroundColor: UIConstants.darkBackgroundStart,
        appBar: AppBar(
          backgroundColor: UIConstants.darkBackgroundStart,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: AppBarTitleView(title: 'Add Reminder'),
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. MEDICINE NAME INPUT
                      AppText(
                        "Medicine Name",
                        color: Colors.white70,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _nameController,
                        hintText: 'e.g. Paracetamol 500mg',
                        prefixIcon: Icons.medication_outlined,
                        // We use the same CustomTextField we optimized earlier
                      ),

                      const SizedBox(height: 24),

                      // 2. TIME PICKER CARD
                      AppText(
                        "Notification Time",
                        color: Colors.white70,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      const SizedBox(height: 8),
                      _buildTimePickerCard(),

                      const SizedBox(height: 24),

                      // 3. REPEAT TOGGLE
                      _buildRepeatToggle(),
                    ],
                  ),
                ),
              ),

              // 4. SAVE BUTTON (Bottom Sticky)
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerCard() {
    final hour = _time?.hourOfPeriod ?? 0;
    final minute = _time?.minute.toString().padLeft(2, '0') ?? "00";
    final period = _time?.period == DayPeriod.am ? "AM" : "PM";

    return InkWell(
      onTap: _pickTime,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05), // Soft fill
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: UIConstants.accentGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time_filled_rounded,
              color: UIConstants.accentGreen.withValues(alpha: 0.8),
              size: 28,
            ),
            const SizedBox(width: 16),
            AppText(
              "${hour == 0 ? 12 : hour}:$minute",
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              maxLines: 5,
              letterSpacing: 2,
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppText(
                period,
                fontSize: 16.sp,
                maxLines: 30,
                fontWeight: FontWeight.w600,
                color: UIConstants.accentGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.repeat_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              AppText(
                "Repeat Daily",
                color: Colors.white,
                fontSize: 15.sp,
                maxLines: 2,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
          Switch(
            value: _repeatDaily,
            activeColor: Colors.black,
            activeTrackColor: UIConstants.accentGreen,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white10,
            onChanged: (v) => setState(() => _repeatDaily = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: UIConstants.darkBackgroundStart,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: UIConstants.accentGreen,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: UIConstants.accentGreen.withValues(
              alpha: 0.3,
            ),
          ),
          child: _saving
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : AppText(
                  'Save Reminder',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  maxLines: 5,
                ),
        ),
      ),
    );
  }
}
