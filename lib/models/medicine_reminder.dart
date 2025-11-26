class MedicineReminder {
  final String id;
  final String medicineName;
  final int hour; // 0–23
  final int minute; // 0–59
  final bool repeatDaily;
  final bool enabled;
  final int createdAt; // timestamp (ms)

  MedicineReminder({
    required this.id,
    required this.medicineName,
    required this.hour,
    required this.minute,
    required this.repeatDaily,
    required this.enabled,
    required this.createdAt,
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
  }) {
    return MedicineReminder(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
