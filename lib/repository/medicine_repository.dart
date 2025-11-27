import 'dart:convert';
import 'dart:developer';

import 'package:ai_medicine_tracker/data/default_medicines.dart';
import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicineItem {
  final String originalName; // user typed name
  final String canonicalName; // lowercase
  final Map<String, List<String>> sections; // formatted data
  final int lastUsedAt;
  final bool fromCache;

  MedicineItem({
    required this.originalName,
    required this.canonicalName,
    required this.sections,
    required this.lastUsedAt,
    this.fromCache = false,
  });

  factory MedicineItem.fromJson(Map<String, dynamic> json) {
    return MedicineItem(
      originalName: json["originalName"],
      canonicalName: json["canonicalName"],
      sections: (json["sections"] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
      lastUsedAt: json["lastUsedAt"] ?? 0,
      fromCache: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "originalName": originalName,
      "canonicalName": canonicalName,
      "sections": sections,
      "lastUsedAt": lastUsedAt,
    };
  }

  MedicineItem copyWith({
    String? originalName,
    Map<String, List<String>>? sections,
    int? lastUsedAt,
    bool? fromCache,
  }) {
    return MedicineItem(
      originalName: originalName ?? this.originalName,
      canonicalName: canonicalName,
      sections: sections ?? this.sections,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

class MedicineRepository {
  static final MedicineRepository _instance = MedicineRepository._internal();

  factory MedicineRepository() => _instance;

  MedicineRepository._internal();

  final Dio _dio = Dio();

  /// key = canonicalName (lowercase)
  final Map<String, MedicineItem> _cache = {};

  bool _loaded = false;

  /// ---------- Load Cache ----------
  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();

    // Load cache
    final jsonStr = prefs.getString("medicine_cache");
    if (jsonStr != null) {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      decoded.forEach((key, value) {
        _cache[key] = MedicineItem.fromJson(value);
      });

      log("📦 Loaded ${_cache.length} cached medicines.");
    }

    // Inject default medicines only once
    final injected = prefs.getBool("default_injected") ?? false;
    if (!injected) {
      for (final entry in DefaultMedicinesData.defaultMedicines.entries) {
        final name = entry.key;
        final canonical = name.toLowerCase();

        final item = MedicineItem(
          originalName: name,
          canonicalName: canonical,
          sections: entry.value,
          lastUsedAt: 0,
        );

        _cache[canonical] = item;
      }

      await prefs.setBool("default_injected", true);
      await _saveCache();
      log("✨ Default medicines injected.");
    }

    _loaded = true;
  }

  /// ---------- Suggestions ----------
  Future<List<String>> getSuggestions(String query) async {
    await _ensureLoaded();

    final q = query.toLowerCase();

    return _cache.values
        .where((m) => m.canonicalName.contains(q))
        .map((m) => m.originalName)
        .toList();
  }

  /// ---------- Fetch ----------
  Future<MedicineItem> fetchMedicine(String name) async {
    await _ensureLoaded();

    final canonical = name.toLowerCase();

    // ✔ cache hit (case-insensitive)
    if (_cache.containsKey(canonical)) {
      log("📦 Cache hit: $name → ${_cache[canonical]!.originalName}");

      final updated = _cache[canonical]!.copyWith(
        fromCache: true,
        lastUsedAt: DateTime.now().millisecondsSinceEpoch,
      );

      _cache[canonical] = updated;
      _saveCache(); // 🔥 async, no await

      return updated;
    }

    // 🌐 fetch from API
    log("🌍 API Request for $name");

    final response = await _dio.post(
      Constants.openAiApi,
      options: Options(
        headers: {
          "Authorization": Constants.openAiAuthorizationKey,
          "Content-Type": "application/json",
        },
      ),
      data: Constants.getOpenAiRequestData(name),
    );

    final raw = response.data["choices"][0]["message"]["content"];
    final parsed = jsonDecode(raw) as Map<String, dynamic>;

    // ---- VALIDATE RESPONSE ----
    if (_isInvalidResponse(parsed)) {
      throw Exception("INVALID_MEDICINE");
    }

    // Normalize map — ensure List<String>
    final formatted = parsed.map((key, value) {
      if (value is List) return MapEntry(key, value.map((e) => "$e").toList());
      if (value is String) return MapEntry(key, [value]);
      return MapEntry(key, ["No data available"]);
    });

    final item = MedicineItem(
      originalName: name,
      canonicalName: canonical,
      sections: formatted,
      lastUsedAt: DateTime.now().millisecondsSinceEpoch,
    );

    _cache[canonical] = item;
    await _saveCache();

    return item;
  }

  bool _isInvalidResponse(Map<String, dynamic> parsed) {
    // If all lists are empty → nothing meaningful
    for (var value in parsed.values) {
      if (value is List && value.isNotEmpty) return false;
      if (value is String && value.trim().isNotEmpty) return false;
    }
    return true;
  }

  /// ---------- Save Cache ----------
  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();

    final map = _cache.map((key, value) => MapEntry(key, value.toJson()));

    await prefs.setString("medicine_cache", jsonEncode(map));

    log("💾 Cache saved (${_cache.length} medicines).");
  }

  /// ---------- Clear Cache ----------
  Future<void> clearCache() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("medicine_cache");
    log("🧹 Cache cleared.");
  }

  /// ---------- Delete single ----------
  Future<void> deleteMedicine(String name) async {
    final key = name.toLowerCase();
    _cache.remove(key);
    await _saveCache();
  }

  List<MedicineItem> getAllCachedItems() {
    return _cache.values.toList();
  }

  Future<void> ensureLoaded() async {
    await _ensureLoaded();
  }

  bool cacheContains(String canonical) {
    return _cache.containsKey(canonical);
  }
}
