import 'package:flutter/material.dart';

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
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter medicine name and select time'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    await ReminderService.instance.addReminder(
      medicineName: name,
      hour: _time!.hour,
      minute: _time!.minute,
      repeatDaily: _repeatDaily,
    );

    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _time == null
        ? 'Select time'
        : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Reminder'),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Medicine name',
                  hintText: 'eg. Paracetamol 500',
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text('Time: $timeLabel'),
                onTap: _pickTime,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat daily'),
                value: _repeatDaily,
                onChanged: (v) {
                  setState(() => _repeatDaily = v);
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Save Reminder'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
