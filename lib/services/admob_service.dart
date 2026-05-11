import 'dart:async';
import 'dart:developer';
import 'dart:math' hide log;

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

  // Unified persistent counter — all interstitial-eligible actions share this.
  int _actionCount = 0;
  int _nextThreshold = 4; // random 4–6, rerolled after each successful show

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
    await _loadAdCounters();
    _loadRewarded();
    _loadInterstitial();
    _loadAppOpen();
  }

  // ── Ad counter helpers ────────────────────────────────

  int _randomThreshold() => 4 + Random().nextInt(3); // 4, 5, or 6

  Future<void> _loadAdCounters() async {
    _actionCount = Prefs.getAdActionCount();
    final saved = Prefs.getAdNextThreshold();
    if (saved >= 4 && saved <= 6) {
      _nextThreshold = saved;
    } else {
      _nextThreshold = _randomThreshold();
      await Prefs.setAdNextThreshold(_nextThreshold);
    }
    log('📊 Ad counter: $_actionCount / $_nextThreshold');
  }

  /// Increments the unified action counter. Returns true when the threshold
  /// is hit and an ad should be shown. Resets counter and rerolls threshold.
  Future<bool> _tick() async {
    _actionCount++;
    await Prefs.setAdActionCount(_actionCount);
    if (_actionCount >= _nextThreshold) {
      _actionCount = 0;
      _nextThreshold = _randomThreshold();
      await Prefs.setAdActionCount(0);
      await Prefs.setAdNextThreshold(_nextThreshold);
      log('🎯 Ad threshold hit — next threshold: $_nextThreshold');
      return true;
    }
    return false;
  }

  void _onAdShownSuccess() {
    _interstitialShownCount++;
    if (_interstitialShownCount >= 3 && !_tiredOfAdsTriggered) {
      _tiredOfAdsTriggered = true;
      tiredOfAdsNotifier.value++;
    }
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

  /// Fire-and-forget: call after any interstitial-eligible action (search,
  /// interaction check, cannabis check). Increments the shared persistent
  /// counter and shows an ad when the random threshold (4–6) is reached.
  Future<void> onNewSearch() async {
    if (!_adsEnabled) return;
    if (!await _tick()) {
      if (_interstitialAd == null) _loadInterstitial();
      return;
    }
    if (_interstitialAd != null) {
      await _showInterstitial();
    } else {
      _loadInterstitial();
    }
  }

  /// Awaited: call before PDF export. Increments the shared counter and, if
  /// the threshold is hit, shows the interstitial and waits for dismissal
  /// before returning so the PDF share sheet doesn't overlap.
  Future<void> showInterstitialAndWait() async {
    if (!_adsEnabled) return;
    if (!await _tick()) {
      if (_interstitialAd == null) _loadInterstitial();
      return;
    }
    if (_interstitialAd == null) {
      _loadInterstitial();
      return;
    }
    final completer = Completer<void>();
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete();
      },
    );
    await _interstitialAd!.show();
    _interstitialAd = null;
    _onAdShownSuccess();
    return completer.future;
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
    _onAdShownSuccess();
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
