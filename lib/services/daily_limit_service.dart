import '../helper/constant.dart';
import '../helper/prefs.dart';
import '../services/subscription_service.dart';

enum ApiFeature { search, interaction, cannabis }

class DailyLimitService {
  DailyLimitService._();
  static final DailyLimitService instance = DailyLimitService._();

  bool isLimitReached(ApiFeature feature) {
    return getUsed(feature) >= getLimit(feature);
  }

  int getLimit(ApiFeature feature) {
    final isPro = SubscriptionService.instance.isPro;
    // During the free trial, apply reduced daily limits (full Pro limits unlock
    // once the trial converts to paid).
    if (isPro && SubscriptionService.instance.isInTrial) {
      switch (feature) {
        case ApiFeature.search:
          return Constants.trialDailySearchLimit;
        case ApiFeature.interaction:
          return Constants.trialDailyInteractionLimit;
        case ApiFeature.cannabis:
          return Constants.trialDailyCannabisLimit;
      }
    }
    switch (feature) {
      case ApiFeature.search:
        return isPro ? Constants.proDailySearchLimit : Constants.freeDailySearchLimit;
      case ApiFeature.interaction:
        return isPro ? Constants.proDailyInteractionLimit : Constants.freeDailyInteractionLimit;
      case ApiFeature.cannabis:
        return isPro ? Constants.proDailyCannabisLimit : Constants.freeDailyCannabisLimit;
    }
  }

  int getUsed(ApiFeature feature) {
    switch (feature) {
      case ApiFeature.search:
        return Prefs.getDailyCount();
      case ApiFeature.interaction:
        return Prefs.getDailyInteractionCount();
      case ApiFeature.cannabis:
        return Prefs.getDailyCannabisCount();
    }
  }

  int remaining(ApiFeature feature) {
    final limit = getLimit(feature);
    return (limit - getUsed(feature)).clamp(0, limit);
  }

  Future<void> record(ApiFeature feature) {
    switch (feature) {
      case ApiFeature.search:
        return Prefs.incrementDailyCount();
      case ApiFeature.interaction:
        return Prefs.incrementDailyInteractionCount();
      case ApiFeature.cannabis:
        return Prefs.incrementDailyCannabisCount();
    }
  }

  // Legacy helpers kept for existing call sites
  Future<void> recordSearch() => record(ApiFeature.search);
  int remainingToday() => remaining(ApiFeature.search);
  int usedToday() => getUsed(ApiFeature.search);

  // Called after the user watches a rewarded ad — grants +1 bonus search.
  Future<void> grantRewardedBonus() => Prefs.addBonusDailySearch();
}
