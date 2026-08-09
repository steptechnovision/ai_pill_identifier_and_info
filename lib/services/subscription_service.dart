import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../helper/constant.dart';
import '../helper/prefs.dart';

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Trial days for the annual plan — read from Play Store offer, fallback 3
  int _annualTrialDays = 3;
  int get annualTrialDays => _annualTrialDays;

  // Regular (post-trial) annual price from Play Store
  String _annualRegularPrice = '';
  String get annualRegularPrice => _annualRegularPrice;

  // Fires whenever Pro status changes — UI can listen and rebuild instantly
  final ValueNotifier<int> proChangeNotifier = ValueNotifier(0);

  bool get isPro => Prefs.isPro() || Prefs.isSimulatePro();

  /// True while the current subscription is still inside its free-trial window
  /// (computed from the stored start time + the plan's trial length). Used to
  /// hold back the full monthly scan credits until the trial converts to paid.
  bool get isInTrial {
    if (Prefs.isTrialConverted()) return false;
    final startedAt = Prefs.getProStartedAt();
    final trialDays = Prefs.getProTrialDays();
    if (startedAt == 0 || trialDays <= 0) return false;
    final endsAt = startedAt + trialDays * 24 * 60 * 60 * 1000;
    return DateTime.now().millisecondsSinceEpoch < endsAt;
  }

  bool _initRestoreDone = false;
  bool _activeSubFoundDuringInit = false;
  bool _restoreErrorDuringInit = false;

  Future<void> init() async {
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) {
        log('SubscriptionService stream error: $e');
        if (!_initRestoreDone) _restoreErrorDuringInit = true;
      },
    );

    final available = await _iap.isAvailable();
    if (!available) return;

    await _loadProducts();
    await _iap.restorePurchases();

    // Wait for stream to deliver all restored purchases, then verify Pro status
    await Future.delayed(const Duration(seconds: 4));
    if (Prefs.isPro() && !_activeSubFoundDuringInit && !_restoreErrorDuringInit) {
      await Prefs.setProActive(false);
      proChangeNotifier.value++;
      log('⚠️ No active subscription found — reverted to free');
    }
    _initRestoreDone = true;

    // Release credits based on trial state (trial allowance during the trial,
    // full monthly bundle only after it ends). Idempotent — safe to call often.
    if (Prefs.isPro()) {
      await _grantProCredits();
    }
  }

  /// Releases Pro credits with trial protection:
  /// - During the free trial → ONE scan's worth of tokens, once.
  /// - After the trial ends (or a plan with no trial) → the full monthly bundle,
  ///   once per calendar month.
  /// This guarantees a trial-then-cancel user can never drain the 30 monthly
  /// scan credits — they only ever unlock after the trial converts to paid.
  Future<void> _grantProCredits({PurchaseDetails? purchase}) async {
    if (!Prefs.isPro()) return;

    // Record when Pro started + the trial length for THIS plan (once).
    // transactionDate is Google-provided, so the trial START can't be faked.
    if (Prefs.getProStartedAt() == 0) {
      final tx =
          purchase != null ? int.tryParse(purchase.transactionDate ?? '') : null;
      final startedAt = (tx != null && tx > 0)
          ? tx
          : DateTime.now().millisecondsSinceEpoch;
      // Trial applies to the annual plan only; monthly has no trial.
      final productId = purchase?.productID ?? Prefs.getProProductId();
      final trialDays = productId == Constants.subAnnualId ? _annualTrialDays : 0;
      await Prefs.setProStartedAt(startedAt);
      await Prefs.setProTrialDays(trialDays);

      // Migration guard: an existing subscriber who has ALREADY received a
      // monthly grant is clearly past any trial. Mark converted so the trial
      // limits/hold never wrongly apply to them after they update the app.
      // (A brand-new trial user has never been granted, so this won't fire.)
      if (!Prefs.shouldGrantProTokensThisMonth()) {
        await Prefs.setTrialConverted();
      }
    }

    final trialDays = Prefs.getProTrialDays();
    final startedAt = Prefs.getProStartedAt();

    // Fast path: no trial, or trial already confirmed ended → monthly bundle,
    // no server call needed.
    if (Prefs.isTrialConverted() || trialDays <= 0 || startedAt == 0) {
      await _grantMonthlyIfDue();
      return;
    }

    final trialEndsAt = startedAt + trialDays * 24 * 60 * 60 * 1000;

    // Still inside the trial per the device clock → release ONLY the 1-scan
    // allowance.
    if (DateTime.now().millisecondsSinceEpoch < trialEndsAt) {
      await _grantTrialAllowance();
      return;
    }

    // Trial is over per the device clock → mark converted and release the
    // monthly bundle. We use the device clock (no server call) to keep traffic
    // off the shared Firebase project. The small clock-tamper edge this leaves
    // open is non-scalable (one trial per account) and bounded by the OpenAI
    // hard spend cap.
    await Prefs.setTrialConverted();
    await _grantMonthlyIfDue();
  }

  Future<void> _grantTrialAllowance() async {
    if (!Prefs.isTrialTokensGranted()) {
      await Prefs.addTokens(Constants.trialTokens);
      await Prefs.setTrialTokensGranted();
      log('✅ Trial allowance granted: ${Constants.trialTokens}');
    }
  }

  Future<void> _grantMonthlyIfDue() async {
    if (Prefs.shouldGrantProTokensThisMonth()) {
      await Prefs.addTokens(Constants.proMonthlyTokens);
      await Prefs.markProTokensGranted();
      log('✅ Pro monthly tokens granted: ${Constants.proMonthlyTokens}');
    }
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(Constants.subscriptionIds);
    if (response.error != null) {
      log('SubscriptionService load error: ${response.error}');
      return;
    }
    _products = response.productDetails;
    // Sort: monthly first, annual second
    _products.sort((a, b) {
      if (a.id == Constants.subMonthlyId) return -1;
      if (b.id == Constants.subMonthlyId) return 1;
      return 0;
    });
    _extractAnnualTrialDays();
  }

  // Reads the free-trial period from Play Store's SubscriptionOfferDetails so
  // trial days update automatically when changed in Play Console.
  void _extractAnnualTrialDays() {
    try {
      final annual = _products.firstWhere((p) => p.id == Constants.subAnnualId);
      if (annual is! GooglePlayProductDetails) return;

      final offers = annual.productDetails.subscriptionOfferDetails;
      if (offers == null) return;

      for (final offer in offers) {
        for (final phase in offer.pricingPhases) {
          if (phase.priceAmountMicros == 0 && phase.billingPeriod.isNotEmpty) {
            final days = _parseIsoPeriodDays(phase.billingPeriod);
            if (days > 0) {
              _annualTrialDays = days;
              log('✅ Annual trial days from Play Store: $days');
            }
          } else if (phase.priceAmountMicros > 0 &&
              _annualRegularPrice.isEmpty) {
            _annualRegularPrice = phase.formattedPrice;
            log('✅ Annual regular price from Play Store: $_annualRegularPrice');
          }
        }
      }
    } catch (e) {
      log('⚠️ Could not read trial days: $e');
    }
  }

  // Parses ISO 8601 duration → days: P3D→3, P7D→7, P1W→7, P1M→30
  int _parseIsoPeriodDays(String period) {
    final d = RegExp(r'P(\d+)D').firstMatch(period);
    if (d != null) return int.parse(d.group(1)!);
    final w = RegExp(r'P(\d+)W').firstMatch(period);
    if (w != null) return int.parse(w.group(1)!) * 7;
    final m = RegExp(r'P(\d+)M').firstMatch(period);
    if (m != null) return int.parse(m.group(1)!) * 30;
    return 0;
  }

  Future<void> purchase(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async => _iap.restorePurchases();

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        if (Constants.subscriptionIds.contains(p.productID)) {
          await Prefs.setProActive(true, productId: p.productID);
          if (!_initRestoreDone) _activeSubFoundDuringInit = true;
          log('✅ Pro activated: ${p.productID}');
          proChangeNotifier.value++; // notify all UI listeners immediately

          // Record start (once) and release credits based on trial state.
          await _grantProCredits(purchase: p);
        }
      }

      if (p.status == PurchaseStatus.error) {
        log('❌ Purchase error: ${p.error?.message}');
      }

      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  void dispose() => _sub?.cancel();
}
