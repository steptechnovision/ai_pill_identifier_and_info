import 'dart:async';
import 'dart:convert';

import '../helper/prefs.dart';

class AdherenceService {
  AdherenceService._internal();
  static final AdherenceService instance = AdherenceService._internal();

  // Map<dateStr, List<reminderId>>  e.g. {"2026-05-07": ["rem_123", "rem_456"]}
  Map<String, List<String>> _data = {};

  final _changesController = StreamController<void>.broadcast();
  Stream<void> get onChanged => _changesController.stream;

  // ── Init ─────────────────────────────────────────────

  Future<void> init() async {
    final raw = Prefs.getAdherenceJson();
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _data = decoded.map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      );
    }
  }

  // ── Public API ────────────────────────────────────────

  bool isTakenToday(String reminderId) {
    final list = _data[_today()] ?? [];
    return list.contains(reminderId);
  }

  Future<void> markTaken(String reminderId) async {
    final key = _today();
    _data.putIfAbsent(key, () => []);
    if (!_data[key]!.contains(reminderId)) {
      _data[key]!.add(reminderId);
      await _save();
      _changesController.add(null);
    }
  }

  Future<void> unmarkTaken(String reminderId) async {
    final key = _today();
    _data[key]?.remove(reminderId);
    await _save();
    _changesController.add(null);
  }

  List<String> takenTodayIds() => List.unmodifiable(_data[_today()] ?? []);

  /// Returns consecutive-day streak where ALL supplied active reminder IDs
  /// were marked taken. Pass today's enabled reminder IDs.
  int getStreak(List<String> activeReminderIds) {
    if (activeReminderIds.isEmpty) return 0;

    int streak = 0;
    var date = DateTime.now();

    // Don't count today in streak — today might still be ongoing
    date = date.subtract(const Duration(days: 1));

    for (int i = 0; i < 365; i++) {
      final key = _dateKey(date);
      final taken = _data[key] ?? [];
      final allTaken =
          activeReminderIds.every((id) => taken.contains(id));
      if (!allTaken) break;
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ── Private helpers ───────────────────────────────────

  String _today() => _dateKey(DateTime.now());

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final encoded = jsonEncode(_data);
    await Prefs.setAdherenceJson(encoded);
  }
}
