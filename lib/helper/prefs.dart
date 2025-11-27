import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static late SharedPreferences prefs;
  static String isDataPrefKey = 'isDataPrefKey';
  static const String keyTokens = "user_tokens";

  static Future<void> initialize() async {
    prefs = await SharedPreferences.getInstance();
  }

  static Future<void> putBool(String key, bool value) async {
    await prefs.setBool(key, value);
  }

  static bool getBool(String key, {bool defaultValue = false}) {
    return prefs.getBool(key) ?? defaultValue;
  }

  static void putInt(String key, int value) async {
    await prefs.setInt(key, value);
  }

  static int getInt(String key, {int defaultValue = 0}) {
    return prefs.getInt(key) ?? defaultValue;
  }

  static void putString(String key, String value) async {
    await prefs.setString(key, value);
  }

  static String? getString(String key) {
    return prefs.getString(key);
  }

  // ------------------ TOKEN METHODS ------------------

  static int getTokens() {
    return prefs.getInt(keyTokens) ?? 0;
  }

  static Future<void> setTokens(int value) async {
    await prefs.setInt(keyTokens, value);
  }

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
}
