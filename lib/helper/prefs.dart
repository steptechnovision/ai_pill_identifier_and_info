import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static late SharedPreferences prefs;

  // ── existing ──────────────────────────────────────────
  static String isDataPrefKey = 'isDataPrefKey';
  static const String keyTokens = 'user_tokens';

  // ── onboarding ────────────────────────────────────────
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyUserType = 'user_type'; // patient | caregiver | professional

  // ── daily limit ───────────────────────────────────────
  static const String keyDailyDate = 'daily_search_date';
  static const String keyDailyCount = 'daily_search_count';
  static const String keyDailyInteractionDate = 'daily_interaction_date';
  static const String keyDailyInteractionCount = 'daily_interaction_count';
  static const String keyDailyCannabisDate = 'daily_cannabis_date';
  static const String keyDailyCannabisCount = 'daily_cannabis_count';

  // ── subscription ──────────────────────────────────────
  static const String keyIsPro = 'is_pro_active';
  static const String keyProTokenGrantMonth = 'pro_token_grant_month'; // 'YYYY-MM'
  static const String keyProProductId = 'pro_product_id';
  static const String keySimulatePro = 'simulate_pro_mode';

  // ── welcome tokens (one-time server-side grant) ──────
  static const String keyWelcomeTokensChecked = 'welcome_tokens_checked';

  static bool isWelcomeTokensChecked() =>
      prefs.getBool(keyWelcomeTokensChecked) ?? false;

  static Future<void> setWelcomeTokensChecked() async =>
      prefs.setBool(keyWelcomeTokensChecked, true);

  // ── ad action counter (persists across restarts) ─────
  static const String keyAdActionCount = 'ad_action_count';
  static const String keyAdNextThreshold = 'ad_next_threshold';

  static int getAdActionCount() => prefs.getInt(keyAdActionCount) ?? 0;
  static Future<void> setAdActionCount(int v) async => prefs.setInt(keyAdActionCount, v);
  static int getAdNextThreshold() => prefs.getInt(keyAdNextThreshold) ?? 0;
  static Future<void> setAdNextThreshold(int v) async => prefs.setInt(keyAdNextThreshold, v);

  // ── language ──────────────────────────────────────────
  static const String keyLanguage = 'pref_language';

  static String getLanguage() => prefs.getString(keyLanguage) ?? 'en';

  static Future<void> setLanguage(String code) async =>
      prefs.setString(keyLanguage, code);

  // ── in-app review ─────────────────────────────────────
  static const String keyReviewSearchCount = 'review_search_count';
  static const String keyReviewAsked = 'review_asked';

  static int getReviewSearchCount() => prefs.getInt(keyReviewSearchCount) ?? 0;

  static Future<void> incrementReviewSearchCount() async =>
      prefs.setInt(keyReviewSearchCount, getReviewSearchCount() + 1);

  static bool isReviewAsked() => prefs.getBool(keyReviewAsked) ?? false;

  static Future<void> markReviewAsked() async =>
      prefs.setBool(keyReviewAsked, true);

  // ── my medications ────────────────────────────────────
  static const String keyMyMedications = 'my_medications_json';

  // ─────────────────────────────────────────────────────
  static Future<void> initialize() async {
    prefs = await SharedPreferences.getInstance();
  }

  // ── generic helpers ───────────────────────────────────
  static Future<void> putBool(String key, bool value) async =>
      prefs.setBool(key, value);

  static bool getBool(String key, {bool defaultValue = false}) =>
      prefs.getBool(key) ?? defaultValue;

  static void putInt(String key, int value) async =>
      prefs.setInt(key, value);

  static int getInt(String key, {int defaultValue = 0}) =>
      prefs.getInt(key) ?? defaultValue;

  static void putString(String key, String value) async =>
      prefs.setString(key, value);

  static String? getString(String key) => prefs.getString(key);

  // ── token methods ─────────────────────────────────────
  // TODO(server-side metering): credits are stored & enforced ON-DEVICE here.
  // A normal user can't cause a loss and App Check blocks external abuse, but a
  // determined user on a rooted device could edit this value to grant themselves
  // credits and then make real (App-Check-valid) AI calls we pay for. The only
  // full fix is to move the credit balance + the "enough credits?" check into
  // the Cloud Functions (decrement a Firestore balance only on a successful
  // OpenAI response). Deferred for now due to Firebase budget. Revisit when
  // budget allows. See memory: monetization-and-growth.md.
  static int getTokens() => prefs.getInt(keyTokens) ?? 0;

  static Future<void> setTokens(int value) async =>
      prefs.setInt(keyTokens, value);

  static Future<void> addTokens(int amount) async {
    final current = getTokens();
    await prefs.setInt(keyTokens, current + amount);
  }

  static Future<bool> deductToken() async {
    final current = getTokens();
    if (current <= 0) return false;
    await prefs.setInt(keyTokens, current - 1);
    return true;
  }

  static Future<bool> deductTokens(int amount) async {
    final current = getTokens();
    if (current < amount) return false;
    await prefs.setInt(keyTokens, current - amount);
    return true;
  }

  // ── onboarding ────────────────────────────────────────
  static bool isOnboardingDone() => prefs.getBool(keyOnboardingDone) ?? false;

  static Future<void> setOnboardingDone() async =>
      prefs.setBool(keyOnboardingDone, true);

  static String getUserType() => prefs.getString(keyUserType) ?? 'patient';

  static Future<void> setUserType(String type) async =>
      prefs.setString(keyUserType, type);

  // ── daily limit ───────────────────────────────────────
  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static int getDailyCount() {
    final saved = prefs.getString(keyDailyDate);
    if (saved != _todayStr()) return 0; // new day → reset
    return prefs.getInt(keyDailyCount) ?? 0;
  }

  static Future<void> incrementDailyCount() async {
    await prefs.setString(keyDailyDate, _todayStr());
    final current = getDailyCount();
    await prefs.setInt(keyDailyCount, current + 1);
  }

  static Future<void> addBonusDailySearch() async {
    await prefs.setString(keyDailyDate, _todayStr());
    // store bonus as negative offset: allow one extra beyond the limit
    final current = prefs.getInt(keyDailyCount) ?? 0;
    await prefs.setInt(keyDailyCount, (current - 1).clamp(0, 999));
  }

  // ── daily limit (drug interactions) ──────────────────
  static int getDailyInteractionCount() {
    final saved = prefs.getString(keyDailyInteractionDate);
    if (saved != _todayStr()) return 0;
    return prefs.getInt(keyDailyInteractionCount) ?? 0;
  }

  static Future<void> incrementDailyInteractionCount() async {
    await prefs.setString(keyDailyInteractionDate, _todayStr());
    final current = getDailyInteractionCount();
    await prefs.setInt(keyDailyInteractionCount, current + 1);
  }

  // ── daily limit (cannabis interactions) ──────────────
  static int getDailyCannabisCount() {
    final saved = prefs.getString(keyDailyCannabisDate);
    if (saved != _todayStr()) return 0;
    return prefs.getInt(keyDailyCannabisCount) ?? 0;
  }

  static Future<void> incrementDailyCannabisCount() async {
    await prefs.setString(keyDailyCannabisDate, _todayStr());
    final current = getDailyCannabisCount();
    await prefs.setInt(keyDailyCannabisCount, current + 1);
  }

  // ── subscription ──────────────────────────────────────
  static String _thisMonthStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static bool shouldGrantProTokensThisMonth() =>
      prefs.getString(keyProTokenGrantMonth) != _thisMonthStr();

  static Future<void> markProTokensGranted() async =>
      prefs.setString(keyProTokenGrantMonth, _thisMonthStr());

  static bool isPro() => prefs.getBool(keyIsPro) ?? false;

  static bool isSimulatePro() => prefs.getBool(keySimulatePro) ?? false;

  static Future<void> setSimulatePro(bool value) async =>
      prefs.setBool(keySimulatePro, value);

  static Future<void> setProActive(bool value, {String? productId}) async {
    await prefs.setBool(keyIsPro, value);
    if (productId != null) await prefs.setString(keyProProductId, productId);
  }

  // ── family members ────────────────────────────────────
  static const String keyFamilyMembers = 'family_members_json';

  static String? getFamilyMembersJson() => prefs.getString(keyFamilyMembers);

  static Future<void> setFamilyMembersJson(String json) async =>
      prefs.setString(keyFamilyMembers, json);

  // ── adherence (taken log) ─────────────────────────────
  static const String keyAdherence = 'adherence_taken';

  static String? getAdherenceJson() => prefs.getString(keyAdherence);

  static Future<void> setAdherenceJson(String json) async =>
      prefs.setString(keyAdherence, json);

  // ── my medications (stored as raw JSON string) ────────
  static String? getMyMedicationsJson() => prefs.getString(keyMyMedications);

  static Future<void> setMyMedicationsJson(String json) async =>
      prefs.setString(keyMyMedications, json);
}
