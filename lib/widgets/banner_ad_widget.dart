import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';


/// Full-width adaptive banner ad for non-Pro users.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  AdSize? _adSize;
  bool _loaded = false;
  bool _adRequested = false;

  @override
  void initState() {
    super.initState();
    SubscriptionService.instance.proChangeNotifier.addListener(_onProChanged);
  }

  @override
  void dispose() {
    SubscriptionService.instance.proChangeNotifier.removeListener(_onProChanged);
    _ad?.dispose();
    super.dispose();
  }

  void _onProChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_adRequested && !SubscriptionService.instance.isPro) {
      _adRequested = true;
      _load();
    }
  }

  Future<void> _load() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final adSize =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (adSize == null || !mounted) return;

    _adSize = adSize;
    _ad = BannerAd(
      adUnitId: Constants.admobBannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    if (SubscriptionService.instance.isPro ||
        _ad == null ||
        !_loaded ||
        _adSize == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: _adSize!.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
