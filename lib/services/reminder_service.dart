import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicine_reminder.dart';

class ReminderService {
  ReminderService._internal();

  static final ReminderService instance = ReminderService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final List<MedicineReminder> _reminders = [];
  bool _initialized = false;

  static const String _storageKey = 'medicine_reminders';

  // ------------------------------------------------
  // INIT
  // ------------------------------------------------
  Future<void> init() async {
    if (_initialized) return;

    // Timezone init
    try {
      tz.initializeTimeZones();
      final TimezoneInfo? timeZoneName =
          await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName?.identifier ?? ''));

      const androidInit = AndroidInitializationSettings('app_icon');
      const iosInit = DarwinInitializationSettings();

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(initSettings);

      // Request notification permissions
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      print(e);
    }

    await _loadFromStorage();
    await _rescheduleAllEnabled();

    _initialized = true;
  }

  // ------------------------------------------------
  // PUBLIC API
  // ------------------------------------------------

  List<MedicineReminder> getReminders() {
    // return copy sorted by time
    final list = [..._reminders];
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<MedicineReminder> addReminder({
    required String medicineName,
    required int hour,
    required int minute,
    bool repeatDaily = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final reminder = MedicineReminder(
      id: 'rem_$now',
      medicineName: medicineName,
      hour: hour,
      minute: minute,
      repeatDaily: repeatDaily,
      enabled: true,
      createdAt: now,
    );

    _reminders.add(reminder);
    await _saveToStorage();
    await _schedule(reminder);

    return reminder;
  }

  Future<void> deleteReminder(MedicineReminder reminder) async {
    _reminders.removeWhere((r) => r.id == reminder.id);
    await _saveToStorage();
    await _cancel(reminder);
  }

  Future<void> toggleEnabled(MedicineReminder reminder, bool enabled) async {
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index == -1) return;

    final updated = reminder.copyWith(enabled: enabled);
    _reminders[index] = updated;
    await _saveToStorage();

    if (enabled) {
      await _schedule(updated);
    } else {
      await _cancel(updated);
    }
  }

  // ------------------------------------------------
  // INTERNAL STORAGE
  // ------------------------------------------------
  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);

    _reminders.clear();

    if (jsonStr != null) {
      final List list = jsonDecode(jsonStr) as List;
      for (final item in list) {
        _reminders.add(MedicineReminder.fromJson(item));
      }
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _reminders.map((r) => r.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  // ------------------------------------------------
  // NOTIFICATION SCHEDULING
  // ------------------------------------------------
  int _notifIdFor(MedicineReminder r) => r.id.hashCode & 0x7fffffff;

  Future<void> _schedule(MedicineReminder reminder) async {
    try {
      if (!reminder.enabled) return;

      final id = _notifIdFor(reminder);

      const androidDetails = AndroidNotificationDetails(
        'medicine_reminders',
        'Medicine Reminders',
        channelDescription: 'Reminders to check your medicines',
        priority: Priority.high,
        importance: Importance.max,
      );

      const iosDetails = DarwinNotificationDetails();

      final details = const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final now = tz.TZDateTime.now(tz.local);

      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        reminder.hour,
        reminder.minute,
      );

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id,
        "Medicine Reminder",
        "Time to check: ${reminder.medicineName}",
        // tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.id,
        matchDateTimeComponents: reminder.repeatDaily
            ? DateTimeComponents.time
            : null,
      );
    } catch (e) {
      print(e);
    }
  }

  Future<void> _cancel(MedicineReminder reminder) async {
    final id = _notifIdFor(reminder);
    await _plugin.cancel(id);
  }

  Future<void> _rescheduleAllEnabled() async {
    for (final r in _reminders.where((e) => e.enabled)) {
      await _schedule(r);
    }
  }
}
