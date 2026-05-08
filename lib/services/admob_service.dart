import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../helper/constant.dart';
import '../helper/prefs.dart';

class AdmobService {
  AdmobService._();
  static final AdmobService instance = AdmobService._();

  // ── Rewarded ──────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _rewardedLoading = false;

  // ── Interstitial ──────────────────────────────────────
  InterstitialAd? _interstitialAd;
  bool _interstitialLoading = false;
  int _searchCount = 0;
  int _interstitialShownCount = 0;
  bool _tiredOfAdsTriggered = false;

  // Fires once when the tired-of-ads threshold is reached.
  // HomeScreen listens and shows the upgrade dialog.
  final ValueNotifier<int> tiredOfAdsNotifier = ValueNotifier(0);

  // ── App Open ──────────────────────────────────────────
  AppOpenAd? _appOpenAd;
  bool _appOpenLoading = false;
  DateTime? _appOpenLoadTime;
  bool _coldLaunchAdShown = false;

  // ─────────────────────────────────────────────────────
  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadRewarded();
    _loadInterstitial();
    _loadAppOpen();
  }

  bool get _adsEnabled => !Prefs.isPro() && !Prefs.isSimulatePro();

  // ── Rewarded ──────────────────────────────────────────
  void _loadRewarded() {
    if (_rewardedLoading) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: Constants.admobRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoading = false;
          log('✅ Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _rewardedLoading = false;
          log('❌ Rewarded ad failed: ${error.message}');
        },
      ),
    );
  }

  bool get isReady => _rewardedAd != null;

  /// Returns true if the user earned the reward.
  Future<bool> showRewarded() async {
    if (_rewardedAd == null) {
      _loadRewarded();
      return false;
    }
    final completer = Completer<bool>();
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await _rewardedAd!.show(
      onUserEarnedReward: (_, __) {
        if (!completer.isCompleted) completer.complete(true);
      },
    );
    return completer.future;
  }

  // ── Interstitial ──────────────────────────────────────
  void _loadInterstitial() {
    if (_interstitialLoading || !_adsEnabled) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: Constants.admobInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
          log('✅ Interstitial loaded');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _interstitialLoading = false;
          log('❌ Interstitial failed: ${error.message}');
        },
      ),
    );
  }

  /// Call after each new (non-cached) search — shows interstitial every N searches.
  Future<void> onNewSearch() async {
    if (!_adsEnabled) return;
    _searchCount++;
    if (_searchCount % Constants.interstitialCadence == 0 &&
        _interstitialAd != null) {
      await _showInterstitial();
    }
    if (_interstitialAd == null) _loadInterstitial();
  }

  Future<void> _showInterstitial() async {
    if (_interstitialAd == null) return;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );
    await _interstitialAd!.show();
    _interstitialAd = null;
    _interstitialShownCount++;
    if (_interstitialShownCount >= 3 && !_tiredOfAdsTriggered) {
      _tiredOfAdsTriggered = true;
      tiredOfAdsNotifier.value++;
    }
  }

  // ── App Open ──────────────────────────────────────────
  void _loadAppOpen() {
    if (_appOpenLoading || !_adsEnabled) return;
    _appOpenLoading = true;
    AppOpenAd.load(
      adUnitId: Constants.admobAppOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          _appOpenLoading = false;
          log('✅ App Open ad loaded');
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          _appOpenLoading = false;
          log('❌ App Open ad failed: ${error.message}');
        },
      ),
    );
  }

  bool _isAppOpenFresh() {
    if (_appOpenLoadTime == null) return false;
    return DateTime.now().difference(_appOpenLoadTime!) <
        const Duration(hours: 4);
  }

  /// Call once from HomeScreen.initState() — shows exactly once per cold launch.
  Future<void> showColdLaunchAd() async {
    if (_coldLaunchAdShown) return;
    _coldLaunchAdShown = true;
    await showAppOpenAd();
  }

  /// Call on app foreground — shows at most once per 4-hour window.
  Future<void> showAppOpenAd() async {
    if (!_adsEnabled) return;
    if (_appOpenAd == null || !_isAppOpenFresh()) {
      _loadAppOpen();
      return;
    }
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpen();
      },
    );
    await _appOpenAd!.show();
    _appOpenAd = null;
  }
}
