import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';

class AIService {
  AIService._();
  static final AIService instance = AIService._();

  HttpsCallable _fn(String name, {Duration timeout = const Duration(seconds: 90)}) =>
      FirebaseFunctions.instance.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: timeout),
      );

  // ── 1. Medicine info ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> searchMedicine(
    String name, {
    String language = 'en',
    String? genericName,
  }) async {
    log('🔥 Functions: searchMedicine($name, lang=$language)');
    final result = await _fn('searchMedicine', timeout: const Duration(seconds: 60)).call({
      'medicineName': name,
      'language': language,
      // ignore: use_null_aware_elements
      if (genericName != null) 'genericName': genericName,
    });
    return _toMap(result.data);
  }

  // ── 2. Drug–drug interactions ───────────────────────────────────────────────
  Future<Map<String, dynamic>> checkDrugInteractions(
    List<String> medicines, {
    bool includeSupplements = false,
  }) async {
    log('🔥 Functions: checkDrugInteractions(${medicines.length} drugs)');
    final result = await _fn('checkDrugInteractions').call({
      'medicines': medicines,
      'includeSupplements': includeSupplements,
    });
    return _toMap(result.data);
  }

  // ── 3. Cannabis / CBD interactions ─────────────────────────────────────────
  Future<Map<String, dynamic>> checkCannabisInteractions(String medicine) async {
    log('🔥 Functions: checkCannabisInteractions($medicine)');
    final result = await _fn('checkCannabisInteractions').call({'medicine': medicine});
    return _toMap(result.data);
  }

  // ── 4. Camera scan — pill identification ───────────────────────────────────
  Future<Map<String, dynamic>> scanPill(String base64Image) async {
    log('🔥 Functions: scanPill (image ${(base64Image.length / 1024).toStringAsFixed(1)} KB)');
    final result = await _fn('scanPill', timeout: const Duration(seconds: 90)).call({
      'base64Image': base64Image,
    });
    return _toMap(result.data);
  }

  // ── 5. Missed dose advice ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMissedDoseAdvice(String medicine) async {
    log('🔥 Functions: getMissedDoseAdvice($medicine)');
    final result = await _fn('getMissedDoseAdvice', timeout: const Duration(seconds: 30)).call({
      'medicine': medicine,
    });
    return _toMap(result.data);
  }

  // ── Error message helper (call this from catch blocks in screens) ───────────
  static String friendlyError(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'unauthenticated':
          return 'Verification failed. Please reinstall the app.';
        case 'invalid-argument':
          return 'Invalid input. Please check your entry.';
        case 'resource-exhausted':
          return 'Too many requests. Please wait a moment.';
        case 'unavailable':
          return 'Service unavailable. Please check your connection.';
        default:
          return 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  static dynamic _deepCast(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map((e) => MapEntry(e.key.toString(), _deepCast(e.value))),
      );
    } else if (value is List) {
      return value.map(_deepCast).toList();
    }
    return value;
  }

  Map<String, dynamic> _toMap(dynamic data) => _deepCast(data) as Map<String, dynamic>;
}
