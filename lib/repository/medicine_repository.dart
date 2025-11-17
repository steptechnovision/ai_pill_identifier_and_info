import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helper/constant.dart';

/// ✅ A Singleton repository that handles:
/// - Network requests
/// - Caching results in memory & SharedPreferences
/// - JSON parsing and formatting
class MedicineRepository {
  // ---- Singleton Boilerplate ----
  static final MedicineRepository _instance = MedicineRepository._internal();

  factory MedicineRepository() => _instance;

  MedicineRepository._internal();

  // ---- Internal State ----
  final Dio _dio = Dio();
  final Map<String, Map<String, List<String>>> _cache = {};
  bool _cacheLoaded = false;

  /// Load cache once from SharedPreferences (if not already loaded)
  Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString("medicine_cache");
    if (cachedJson != null) {
      final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        _cache[key] = (value as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, List<String>.from(v)),
        );
      });
      log("📦 MedicineRepository cache loaded with ${_cache.length} entries.");
    }
    _cacheLoaded = true;
  }

  /// Public getter for suggestions based on query
  Future<List<String>> getSuggestions(String query) async {
    await _ensureCacheLoaded();
    final q = query.toLowerCase();
    return _cache.keys.where((name) => name.toLowerCase().contains(q)).toList();
  }

  /// Fetch medicine data — cached first, then API if needed.
  Future<Map<String, List<String>>> fetchMedicine(String name) async {
    await _ensureCacheLoaded();

    final key = name.toLowerCase();

    // ✅ Return cached if available
    if (_cache.containsKey(key)) {
      log("📦 Cache hit: $key");
      return _cache[key]!;
    }

    // 🌐 API request
    log("📤 Searching medicine: $key");
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

    final rawContent = response.data["choices"][0]["message"]["content"];
    final parsed = Map<String, dynamic>.from(jsonDecode(rawContent));

    // ✅ Normalize data: ensure all values are List<String>
    final formatted = parsed.map((k, v) {
      if (v is List) return MapEntry(k, v.map((e) => e.toString()).toList());
      if (v is String) return MapEntry(k, [v]);
      return MapEntry(k, ["No data available"]);
    });

    // 🧠 Save in memory + persist
    _cache[key] = formatted;
    await _saveCache();

    return formatted;
  }

  /// Persist cache to SharedPreferences
  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_cache);
    await prefs.setString("medicine_cache", encoded);
    log("💾 Cache saved (${_cache.length} entries).");
  }

  /// Optional: Clear cache
  Future<void> clearCache() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("medicine_cache");
    log("🧹 Cache cleared.");
  }
}
