import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/models/family_member.dart';
import 'package:ai_medicine_tracker/models/user_medication.dart';
import 'package:ai_medicine_tracker/screens/add_reminder_screen.dart';
import 'package:ai_medicine_tracker/screens/drug_interaction_screen.dart';
import 'package:ai_medicine_tracker/screens/family_members_screen.dart';
import 'package:ai_medicine_tracker/services/admob_service.dart';
import 'package:ai_medicine_tracker/services/pdf_export_service.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:ai_medicine_tracker/widgets/native_ad_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MyMedicationsScreen extends StatefulWidget {
  const MyMedicationsScreen({super.key});

  @override
  State<MyMedicationsScreen> createState() => _MyMedicationsScreenState();
}

class _MyMedicationsScreenState extends State<MyMedicationsScreen> {
  List<UserMedication> _meds = [];
  List<FamilyMember> _family = [];
  String? _selectedMemberId; // null = "Me"
  bool _isAdding = false;
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _load() {
    final all = UserMedication.loadAll();
    setState(() {
      _meds = all.where((m) => m.familyMemberId == _selectedMemberId).toList();
      _family = FamilyMember.loadAll();
    });
  }

  Future<void> _exportPdf() async {
    await AdmobService.instance.showInterstitialAndWait();
    if (!mounted) return;
    Utils.showLoading(message: 'Generating PDF…');
    try {
      final label = _selectedMemberId == null
          ? 'My'
          : (_family
                  .where((m) => m.id == _selectedMemberId)
                  .firstOrNull
                  ?.name ??
              'Member');
      await PdfExportService.exportMedicationsList(_meds, personLabel: label);
    } catch (_) {
      if (mounted) {
        Utils.showMessage(context, 'Could not generate PDF. Try again.',
            isError: true);
      }
    } finally {
      await Utils.hideLoading();
    }
  }

  Future<void> _delete(String id) async {
    await UserMedication.remove(id);
    _load();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final med = UserMedication(
      id: 'med_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      dosage: _dosageCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      addedAt: DateTime.now().millisecondsSinceEpoch,
      familyMemberId: _selectedMemberId,
    );
    await UserMedication.add(med);
    _nameCtrl.clear();
    _dosageCtrl.clear();
    _notesCtrl.clear();
    setState(() => _isAdding = false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      appBar: AppBar(
        backgroundColor: UIConstants.darkBackgroundStart,
        elevation: 0,
        title: AppText(
          'My Medications',
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        actions: [
          if (!_isAdding && _meds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded,
                  color: Colors.blueAccent),
              tooltip: 'Export PDF',
              onPressed: _exportPdf,
            ),
          if (!_isAdding)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: UIConstants.accentGreen),
              tooltip: 'Add medication',
              onPressed: () => setState(() => _isAdding = true),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildPersonSelector(),
          if (_meds.isNotEmpty && !_isAdding) _buildInteractionsButton(),
          if (_isAdding)
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
                ),
                child: _buildAddForm(),
              ),
            )
          else
            Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: _isAdding
          ? null
          : FloatingActionButton(
              backgroundColor: UIConstants.accentGreen,
              foregroundColor: Colors.black,
              onPressed: () => setState(() => _isAdding = true),
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  Widget _buildPersonSelector() {
    return SizedBox(
      height: 48.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        children: [
          _personChip(null, 'Me'),
          ..._family.map((m) => _personChip(m.id, m.name)),
          _addMemberChip(),
        ],
      ),
    );
  }

  Widget _personChip(String? memberId, String label) {
    final isSelected = _selectedMemberId == memberId;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMemberId = memberId);
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(right: 8.w),
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

  Widget _addMemberChip() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FamilyMembersScreen()),
        );
        _load();
      },
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add_alt_1_rounded,
                color: Colors.white38, size: 13),
            5.horizontalSpace,
            AppText('Add Member', fontSize: 12.sp, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionsButton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 4.h),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DrugInteractionScreen(
              preloadedMeds: _meds.map((m) => m.name).toList(),
            ),
          ),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 16),
              10.horizontalSpace,
              Expanded(
                child: AppText(
                  'Check Drug Interactions for these medications',
                  fontSize: 12.sp,
                  color: Colors.redAccent.shade100,
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.redAccent, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddForm() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UIConstants.accentGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Add Medication',
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white),
          12.verticalSpace,
          _inputField(_nameCtrl, 'Medicine name *', Icons.medication_rounded),
          10.verticalSpace,
          _inputField(_dosageCtrl, 'Dosage (e.g. 500mg)', Icons.straighten_rounded),
          10.verticalSpace,
          _inputField(_notesCtrl, 'Notes (e.g. Take after food)', Icons.notes_rounded),
          if (_family.isNotEmpty) ...[
            14.verticalSpace,
            AppText('Assign to',
                fontSize: 12.sp, color: Colors.white38),
            8.verticalSpace,
            SizedBox(
              height: 36.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _assignChip(null, 'Me'),
                  ..._family.map((m) => _assignChip(m.id, m.name)),
                ],
              ),
            ),
          ],
          16.verticalSpace,
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _nameCtrl.clear();
                    _dosageCtrl.clear();
                    _notesCtrl.clear();
                    setState(() => _isAdding = false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const AppText('Cancel'),
                ),
              ),
              12.horizontalSpace,
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UIConstants.accentGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: AppText('Save',
                      fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _assignChip(String? memberId, String label) {
    final isSelected = _selectedMemberId == memberId;
    return GestureDetector(
      onTap: () => setState(() => _selectedMemberId = memberId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? UIConstants.accentGreen.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? UIConstants.accentGreen.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: AppText(
          label,
          fontSize: 12.sp,
          color: isSelected ? UIConstants.accentGreen : Colors.white54,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _inputField(
      TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      ),
    );
  }

  Widget _buildList() {
    if (_meds.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined,
                size: 48, color: Colors.white.withValues(alpha: 0.2)),
            16.verticalSpace,
            AppText(
              'No medications yet.\nTap + to add your first one.',
              fontSize: 14.sp,
              color: Colors.white38,
              textAlign: TextAlign.center,
              lineHeight: 1.5,
              maxLines: 3,
            ),
          ],
        ),
      );
    }

    final items = <Widget>[];
    for (int i = 0; i < _meds.length; i++) {
      items.add(_buildCard(_meds[i]));
      // Native ad every 2 items (shows even with just 2 meds)
      if ((i + 1) % 2 == 0) items.add(const NativeAdCard());
    }
    // Show at least 1 ad for odd-length lists ≥ 1
    if (_meds.length % 2 != 0 && _meds.isNotEmpty) {
      items.add(const NativeAdCard());
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      children: items,
    );
  }

  Widget _buildCard(UserMedication med) {
    final memberColor = _getMemberColor(med.familyMemberId);
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: UIConstants.accentGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medication_rounded,
                    color: UIConstants.accentGreen, size: 20),
              ),
              14.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(med.name,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    if (med.dosage.isNotEmpty) ...[
                      4.verticalSpace,
                      AppText(med.dosage,
                          fontSize: 12.sp, color: UIConstants.accentGreen),
                    ],
                    if (med.notes.isNotEmpty) ...[
                      2.verticalSpace,
                      AppText(med.notes,
                          fontSize: 11.sp, color: Colors.white38, maxLines: 2),
                    ],
                    if (med.familyMemberId != null) ...[
                      4.verticalSpace,
                      _buildMemberBadge(med.familyMemberId!, memberColor),
                    ],
                  ],
                ),
              ),
              // Set Reminder shortcut
              GestureDetector(
                onTap: () => _openSetReminder(med),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: UIConstants.accentGreen.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.alarm_add_rounded,
                      color: UIConstants.accentGreen, size: 18),
                ),
              ),
              6.horizontalSpace,
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white24, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDelete(med),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBadge(String memberId, Color color) {
    final member = _family.where((m) => m.id == memberId).firstOrNull;
    if (member == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, color: color, size: 10),
          3.horizontalSpace,
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 90.w),
            child: AppText(member.name,
                fontSize: 10.sp,
                color: color,
                fontWeight: FontWeight.w600,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Color _getMemberColor(String? memberId) {
    if (memberId == null) return UIConstants.accentGreen;
    final member = _family.where((m) => m.id == memberId).firstOrNull;
    if (member == null) return Colors.blue;
    const colors = [
      Color(0xFF00E676), Color(0xFF2979FF), Color(0xFFFF6D00),
      Color(0xFFD500F9), Color(0xFFFF1744), Color(0xFF00B8D4),
      Color(0xFFFFD600), Color(0xFF69F0AE),
    ];
    return colors[member.colorIndex % colors.length];
  }

  Future<void> _openSetReminder(UserMedication med) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(
          initialMedicineName: med.name,
          familyMemberId: med.familyMemberId,
        ),
      ),
    );
  }

  void _confirmDelete(UserMedication med) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: UIConstants.darkBackgroundEnd,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: AppText('Remove ${med.name}?',
            fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.bold),
        content: AppText('This medication will be removed from your list.',
            fontSize: 13.sp, color: Colors.white54),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel', color: Colors.white38),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _delete(med.id);
            },
            child: const AppText('Remove', color: UIConstants.accentRed),
          ),
        ],
      ),
    );
  }
}
