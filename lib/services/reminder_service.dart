import 'dart:async';
import 'dart:convert';
import 'dart:developer';

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

  final _changesController = StreamController<void>.broadcast();

  Stream<void> get onChanged => _changesController.stream;

  static const String _storageKey = 'medicine_reminders';

  // ------------------------------------------------
  // INIT
  // ------------------------------------------------
  Future<void> init() async {
    if (_initialized) return;

    // Timezone init
    try {
      tz.initializeTimeZones();
      final TimezoneInfo timeZoneName =
          await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));

      const androidInit = AndroidInitializationSettings('ic_notification');
      const iosInit = DarwinInitializationSettings();

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(settings: initSettings);

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Request POST_NOTIFICATIONS permission (Android 13+)
      await androidPlugin?.requestNotificationsPermission();

      // Request exact alarm permission (Android 12+ / API 31+).
      // Without this, notifications may be delayed up to 30+ minutes.
      await androidPlugin?.requestExactAlarmsPermission();

      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      log('ReminderService init error: $e');
    }

    await _loadFromStorage();
    await _rescheduleAllEnabled();

    _initialized = true;
  }

  // ------------------------------------------------
  // PERMISSION CHECK
  // ------------------------------------------------

  Future<bool> areNotificationsEnabled() async {
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        return await androidPlugin.areNotificationsEnabled() ?? true;
      }
      // iOS: no direct check without permission_handler, default to true
      return true;
    } catch (_) {
      return true;
    }
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
    String? familyMemberId,
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
      familyMemberId: familyMemberId,
    );

    _reminders.add(reminder);
    await _saveToStorage();
    await _schedule(reminder);
    _changesController.add(null);

    return reminder;
  }

  Future<void> deleteReminder(MedicineReminder reminder) async {
    _reminders.removeWhere((r) => r.id == reminder.id);
    await _saveToStorage();
    await _cancel(reminder);
    _changesController.add(null);
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
    _changesController.add(null);
  }

  Future<void> editReminder(
    MedicineReminder original, {
    required String medicineName,
    required int hour,
    required int minute,
    required bool repeatDaily,
  }) async {
    final index = _reminders.indexWhere((r) => r.id == original.id);
    if (index == -1) return;

    // Cancel the old notification before rescheduling
    await _cancel(original);

    final updated = original.copyWith(
      medicineName: medicineName,
      hour: hour,
      minute: minute,
      repeatDaily: repeatDaily,
    );

    _reminders[index] = updated;
    await _saveToStorage();

    if (updated.enabled) {
      await _schedule(updated);
    }

    _changesController.add(null);
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
        channelDescription: 'Daily reminders to take your medicines on time',
        icon: 'ic_notification',
        priority: Priority.max,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
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

      // Try exact alarm first (most reliable). Falls back to inexact if the
      // exact-alarm permission has not been granted on Android 12+.
      try {
        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          title: 'Medicine Reminder 💊',
          body: 'Time to take: ${reminder.medicineName}',
          payload: reminder.id,
          matchDateTimeComponents: reminder.repeatDaily
              ? DateTimeComponents.time
              : null,
        );
      } catch (_) {
        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Medicine Reminder 💊',
          body: 'Time to take: ${reminder.medicineName}',
          payload: reminder.id,
          matchDateTimeComponents: reminder.repeatDaily
              ? DateTimeComponents.time
              : null,
        );
      }
    } catch (e) {
      log('❌ Failed to schedule notification: $e');
    }
  }

  Future<void> _cancel(MedicineReminder reminder) async {
    final id = _notifIdFor(reminder);
    await _plugin.cancel(id: id);
  }

  Future<void> _rescheduleAllEnabled() async {
    for (final r in _reminders.where((e) => e.enabled)) {
      await _schedule(r);
    }
  }

  Future<void> showRemoteNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'App Notifications',
      channelDescription: 'Important alerts from the app',
      icon: 'ic_notification',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 2. Generate a unique ID so messages don't overwrite each other
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 3. Show instantly
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      log('Error showing remote notification: $e');
    }
  }
}
