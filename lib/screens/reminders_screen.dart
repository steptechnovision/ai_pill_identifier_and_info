import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:flutter/material.dart';

import '../models/medicine_reminder.dart';
import '../services/reminder_service.dart';
import 'add_reminder_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  // ---------------------------------------------------------------------------
  // LOGIC (UNTOUCHED)
  // ---------------------------------------------------------------------------
  bool _isLoading = true;
  List<MedicineReminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = ReminderService.instance.getReminders();
    setState(() {
      _reminders = list;
      _isLoading = false;
    });
  }

  Future<void> _openAdd({String? initialMedicine}) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(initialMedicineName: initialMedicine),
      ),
    );

    if (added == true) {
      _load();
    }
  }

  Future<void> _toggle(MedicineReminder r, bool enabled) async {
    await ReminderService.instance.toggleEnabled(r, enabled);
    _load();
  }

  Future<void> _delete(MedicineReminder r) async {
    await ReminderService.instance.deleteReminder(r);
    _load();
  }

  // ---------------------------------------------------------------------------
  // IMPROVED UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      appBar: AppBar(
        backgroundColor: UIConstants.darkBackgroundStart,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Medicine Reminders',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(),
        backgroundColor: UIConstants.accentGreen,
        child: const Icon(Icons.add_alarm_rounded, color: Colors.black),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: UIConstants.accentGreen),
            )
          : _reminders.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _reminders.length,
              // Use space instead of Divider for cleaner look
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final r = _reminders[index];
                return _buildReminderCard(r);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.alarm_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No reminders yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the + button to add one',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(MedicineReminder r) {
    // We dim the opacity if the reminder is disabled
    final opacity = r.enabled ? 1.0 : 0.5;

    return Dismissible(
      key: ValueKey(r.id ?? r.medicineName),
      // Ensure unique key
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      confirmDismiss: (direction) async {
        return await _confirmDelete(r);
      },
      onDismissed: (direction) {
        _delete(r);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: r.enabled
                ? UIConstants.accentGreen.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 🕒 Time Badge (Left side)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: r.enabled
                          ? UIConstants.accentGreen.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.timeLabel, // e.g. "08:00 AM"
                      style: TextStyle(
                        color: r.enabled
                            ? UIConstants.accentGreen
                            : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.repeatDaily ? 'Daily' : 'Once',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: opacity * 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 16),

              // 💊 Medicine Name
              Expanded(
                child: Opacity(
                  opacity: opacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.medicineName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.enabled ? "Active" : "Disabled",
                        style: TextStyle(
                          fontSize: 12,
                          color: r.enabled ? Colors.white70 : Colors.white30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ⚡ Toggle Switch
              Transform.scale(
                scale: 0.8, // Make switch slightly smaller/compact
                child: Switch(
                  value: r.enabled,
                  activeColor: Colors.black,
                  activeTrackColor: UIConstants.accentGreen,
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.white10,
                  onChanged: (v) => _toggle(r, v),
                ),
              ),

              // 🗑 Delete Icon (Optional, since we have swipe, but good for visibility)
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 26,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final confirm = await _confirmDelete(r);
                  if (confirm) {
                    _delete(r);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(MedicineReminder r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E), // Matches your dark theme
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Delete Reminder?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to remove the reminder for '${r.medicineName}'?",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Confirm
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }
}
