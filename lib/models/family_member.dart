import 'dart:convert';

import '../helper/prefs.dart';

class FamilyMember {
  final String id;
  final String name;
  final int colorIndex; // 0–7, maps to accent colors
  final int createdAt;

  FamilyMember({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
        id: j['id'] as String,
        name: j['name'] as String,
        colorIndex: j['colorIndex'] as int? ?? 0,
        createdAt: j['createdAt'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorIndex': colorIndex,
        'createdAt': createdAt,
      };

  FamilyMember copyWith({String? name, int? colorIndex}) => FamilyMember(
        id: id,
        name: name ?? this.name,
        colorIndex: colorIndex ?? this.colorIndex,
        createdAt: createdAt,
      );

  // ── persistence helpers ───────────────────────────────

  static List<FamilyMember> loadAll() {
    final raw = Prefs.getFamilyMembersJson();
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => FamilyMember.fromJson(e)).toList();
  }

  static Future<void> saveAll(List<FamilyMember> items) async {
    final json = jsonEncode(items.map((e) => e.toJson()).toList());
    await Prefs.setFamilyMembersJson(json);
  }

  static Future<FamilyMember> add(String name, int colorIndex) async {
    final all = loadAll();
    final member = FamilyMember(
      id: 'fm_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      colorIndex: colorIndex,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    all.add(member);
    await saveAll(all);
    return member;
  }

  static Future<void> remove(String id) async {
    final all = loadAll();
    all.removeWhere((m) => m.id == id);
    await saveAll(all);
  }
}
