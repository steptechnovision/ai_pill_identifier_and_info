import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!Prefs.isPro() && !Prefs.isSimulatePro()) _loadAd();
  }

  void _loadAd() {
    NativeAd(
      adUnitId: Constants.admobNativeAdUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() { _ad = ad as NativeAd; _loaded = true; });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Prefs.isPro() || Prefs.isSimulatePro()) return const SizedBox.shrink();
    if (!_loaded || _ad == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      height: 80.h,
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
