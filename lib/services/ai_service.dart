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

  /// True when a failure happened BEFORE the paid OpenAI call ran (rejected by
  /// App Check, input validation, rate-limit, or the service being
  /// unreachable). In those cases NO OpenAI cost was incurred, so any tokens
  /// the caller reserved can be refunded with ZERO cost to us.
  ///
  /// Returns false for 'internal'/unknown/timeout failures, where OpenAI may
  /// already have been billed — those must NOT be refunded, otherwise we pay
  /// OpenAI without collecting a credit.
  static bool isNoCostFailure(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'unauthenticated': // App Check / auth rejected before the handler ran
        case 'invalid-argument': // our input validation threw before OpenAI ran
        case 'resource-exhausted': // Firebase throttled admission, before OpenAI ran
          return true;
        // NOTE: 'unavailable' is intentionally NOT refundable. A connection can
        // drop AFTER OpenAI was already billed, so refunding it could cost us.
        // (True offline is caught earlier by the internet check, before any
        // charge, so genuine no-network users are never charged here.)
        default:
          return false; // 'unavailable', 'internal', 'deadline-exceeded', unknown
      }
    }
    return false;
  }

  // ── Trusted server time (for the trial timer) ──────────────────────────────
  /// Returns Google server time in ms since epoch, or null if unreachable.
  /// Used to release the full Pro credits only after the trial genuinely ends,
  /// so a tampered device clock can't unlock them early.
  Future<int?> getServerTime() async {
    try {
      final result =
          await _fn('getServerTime', timeout: const Duration(seconds: 15)).call();
      final data = _toMap(result.data);
      final now = data['now'];
      if (now is int) return now;
      if (now is num) return now.toInt();
      return int.tryParse('$now');
    } catch (e) {
      log('⚠️ getServerTime failed: $e');
      return null;
    }
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
