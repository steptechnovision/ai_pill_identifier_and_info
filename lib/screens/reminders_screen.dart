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
        builder: (_) => AddReminderScreen(
          initialMedicineName: initialMedicine,
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Reminders'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
          ? const Center(
        child: Text(
          'No reminders yet.\nTap + to add one.',
          textAlign: TextAlign.center,
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _reminders.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final r = _reminders[index];
          final subtitle = r.repeatDaily ? 'Daily at ${r.timeLabel}' : 'Once at ${r.timeLabel}';

          return ListTile(
            leading: const Icon(Icons.alarm, color: Colors.greenAccent),
            title: Text(r.medicineName),
            subtitle: Text(subtitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: r.enabled,
                  onChanged: (v) => _toggle(r, v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _delete(r),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
