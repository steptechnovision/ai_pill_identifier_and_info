class MedicineReminder {
  final String id;
  final String medicineName;
  final int hour; // 0–23
  final int minute; // 0–59
  final bool repeatDaily;
  final bool enabled;
  final int createdAt; // timestamp (ms)
  final String? familyMemberId; // null = "Me"

  MedicineReminder({
    required this.id,
    required this.medicineName,
    required this.hour,
    required this.minute,
    required this.repeatDaily,
    required this.enabled,
    required this.createdAt,
    this.familyMemberId,
  });

  factory MedicineReminder.fromJson(Map<String, dynamic> json) {
    return MedicineReminder(
      id: json['id'] as String,
      medicineName: json['medicineName'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      repeatDaily: json['repeatDaily'] as bool? ?? true,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: json['createdAt'] as int? ?? 0,
      familyMemberId: json['familyMemberId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicineName': medicineName,
      'hour': hour,
      'minute': minute,
      'repeatDaily': repeatDaily,
      'enabled': enabled,
      'createdAt': createdAt,
      if (familyMemberId != null) 'familyMemberId': familyMemberId,
    };
  }

  MedicineReminder copyWith({
    String? id,
    String? medicineName,
    int? hour,
    int? minute,
    bool? repeatDaily,
    bool? enabled,
    int? createdAt,
    Object? familyMemberId = _sentinel,
  }) {
    return MedicineReminder(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      familyMemberId: familyMemberId == _sentinel
          ? this.familyMemberId
          : familyMemberId as String?,
    );
  }

  static const Object _sentinel = Object();

  // ✨ UPDATED: Converts 22:00 -> 10:00 PM
  String get timeLabel {
    final period = hour >= 12 ? 'PM' : 'AM';

    // Logic:
    // 0 becomes 12 (12:00 AM)
    // 13-23 becomes 1-11
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;

    final m = minute.toString().padLeft(2, '0');

    return '$hour12:$m $period';
  }
}
