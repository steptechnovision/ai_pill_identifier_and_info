import 'dart:convert';

import '../helper/prefs.dart';

class UserMedication {
  final String id;
  final String name;
  final String dosage; // e.g. "500mg" — optional
  final String notes;  // e.g. "Take after food" — optional
  final int addedAt;
  final String? familyMemberId; // null = "Me"

  UserMedication({
    required this.id,
    required this.name,
    this.dosage = '',
    this.notes = '',
    required this.addedAt,
    this.familyMemberId,
  });

  factory UserMedication.fromJson(Map<String, dynamic> j) => UserMedication(
        id: j['id'] as String,
        name: j['name'] as String,
        dosage: j['dosage'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        addedAt: j['addedAt'] as int? ?? 0,
        familyMemberId: j['familyMemberId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'notes': notes,
        'addedAt': addedAt,
        if (familyMemberId != null) 'familyMemberId': familyMemberId,
      };

  // ── persistence helpers ───────────────────────────────

  static List<UserMedication> loadAll() {
    final raw = Prefs.getMyMedicationsJson();
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => UserMedication.fromJson(e)).toList();
  }

  static Future<void> saveAll(List<UserMedication> items) async {
    final json = jsonEncode(items.map((e) => e.toJson()).toList());
    await Prefs.setMyMedicationsJson(json);
  }

  static Future<void> add(UserMedication med) async {
    final all = loadAll();
    all.removeWhere((m) => m.name.toLowerCase() == med.name.toLowerCase());
    all.insert(0, med);
    await saveAll(all);
  }

  static Future<void> remove(String id) async {
    final all = loadAll();
    all.removeWhere((m) => m.id == id);
    await saveAll(all);
  }
}
