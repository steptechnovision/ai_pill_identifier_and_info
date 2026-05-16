import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Constants {
  // ── App ───────────────────────────────────────────────
  static const String packageName = 'com.steptechnovision.aipillidentifier';
  static const String appName = 'AI Pill Identifier & Info';
  static double screenHorizontalPadding = 16.w;
  static const String privacyPolicyUrl =
      'https://steptechnovision.blogspot.com/2025/12/privacy-policy-for-ai-pill-identifier.html';
  static const String termsAndConditionUrl =
      'https://steptechnovision.blogspot.com/2025/11/terms-conditions-ai-pill-identifier-info.html';
  static const String emailAddress = 'steptechnovision@gmail.com';
  static const String appStoreId = '';

  // ── Daily limits (free / Pro) ────────────────────────
  static const int freeDailySearchLimit = 3;
  static const int freeDailyInteractionLimit = 2;
  static const int proDailySearchLimit = 30;
  static const int proDailyInteractionLimit = 20;
  static const int freeFamilyMembersLimit = 2;
  static const int proFamilyMembersLimit = 20;

  // ── Pro monthly token bundle ──────────────────────────
  static const int proMonthlyTokens = 30; // granted once per calendar month

  // ── Subscription product IDs ─────────────────────────
  // Create these in Google Play Console → Monetize → Subscriptions
  static const String subMonthlyId = 'ai_pill_pro_monthly';
  static const String subAnnualId = 'ai_pill_pro_annual';
  static const Set<String> subscriptionIds = {subMonthlyId, subAnnualId};

  // ── Subscription fallback prices (shown when Play Store unavailable) ────
  static const String subMonthlyFallbackPrice = '₹199/month';
  static const String subAnnualFallbackPrice = '₹1,199/year';

  // ── AdMob IDs (test in debug, real in release) ────────
  static String get admobBannerAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-5003311732017255/1779408142';
  static String get admobInterstitialAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-5003311732017255/3726914635';
  static String get admobNativeAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/2247696110'
      : 'ca-app-pub-5003311732017255/9652204909';
  static String get admobAppOpenAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/9257395921'
      : 'ca-app-pub-5003311732017255/2667544446';

  // Show interstitial every N new searches
  static const int interstitialCadence = 4;

  // ── Share text ────────────────────────────────────────
  static String get shareText {
    const baseMessage =
        "💊 Stop guessing about your medicines!\n\n"
        "I use $appName to get instant, detailed AI insights on side effects, dosage, and usage.\n\n"
        "Get it here 👇\n";

    if (Platform.isAndroid) {
      return "$baseMessage"
          "https://play.google.com/store/apps/details?id=${Constants.packageName}";
    } else {
      return "$baseMessage"
          "https://apps.apple.com/app/id${Constants.appStoreId}";
    }
  }

}
