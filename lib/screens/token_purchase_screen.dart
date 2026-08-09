import 'dart:async';

import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/services/remote_config_service.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

int extractTokensFromProductId(String productId) {
  try {
    return int.parse(productId.split('_').last);
  } catch (_) {
    return 0;
  }
}

class PurchaseTokenScreen extends StatefulWidget {
  const PurchaseTokenScreen({super.key});

  @override
  State<PurchaseTokenScreen> createState() => _PurchaseTokenScreenState();
}

class _PurchaseTokenScreenState extends State<PurchaseTokenScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;

  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _storeAvailable = false;
  String? _purchasingProductId;
  late String? _bestValueProductId;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  @override
  void initState() {
    super.initState();
    _initPurchaseFlow();
  }

  Future<void> _initPurchaseFlow() async {
    setState(() => _loading = true);

    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (_) {
        if (mounted) {
          Utils.showMessage(context, 'Purchase stream error', isError: true);
        }
      },
    );

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      if (mounted) setState(() => _loading = false);
      if (mounted) Utils.showMessage(context, 'Store not available', isError: true);
      return;
    }

    await RemoteConfigService.init();
    final productIds = RemoteConfigService.getTokenProductIds();

    if (productIds.isEmpty) {
      if (mounted) setState(() => _loading = false);
      if (mounted) Utils.showMessage(context, 'No products configured', isError: true);
      return;
    }

    final response = await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        Utils.showMessage(
          context,
          response.error!.message.isNotEmpty ? response.error!.message : 'Failed to load products',
          isError: true,
        );
      }
      return;
    }

    _products = response.productDetails;
    _bestValueProductId = _getBestValueProductId(_products);
    final mostPopularId = _getMostPopularProductId(_products);

    _products.sort((a, b) {
      if (a.id == mostPopularId) return -1;
      if (b.id == mostPopularId) return 1;
      if (a.id == _bestValueProductId) return -1;
      if (b.id == _bestValueProductId) return 1;
      return extractTokensFromProductId(a.id)
          .compareTo(extractTokensFromProductId(b.id));
    });

    if (mounted) setState(() => _loading = false);
  }

  String? _getBestValueProductId(List<ProductDetails> products) {
    if (products.isEmpty) return null;
    final copy = List<ProductDetails>.from(products);
    copy.sort((a, b) => extractTokensFromProductId(b.id)
        .compareTo(extractTokensFromProductId(a.id)));
    return copy.first.id;
  }

  String? _getMostPopularProductId(List<ProductDetails> products) {
    if (products.length < 3) return null;
    final sorted = List<ProductDetails>.from(products)
      ..sort((a, b) => extractTokensFromProductId(a.id)
          .compareTo(extractTokensFromProductId(b.id)));
    return sorted[sorted.length ~/ 2].id;
  }

  Future<void> _buy(ProductDetails product) async {
    if (_purchasingProductId != null) return;
    setState(() => _purchasingProductId = product.id);
    try {
      final param = PurchaseParam(productDetails: product);
      await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
    } catch (e) {
      if (mounted) setState(() => _purchasingProductId = null);
      if (mounted) Utils.showMessage(context, 'Purchase failed', isError: true);
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          Utils.showMessage(
            context,
            purchase.error?.message ?? 'Purchase error',
            isError: true,
          );
        }
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _deliverPurchase(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      if (mounted) setState(() => _purchasingProductId = null);
    }
  }

  Future<void> _deliverPurchase(PurchaseDetails purchase) async {
    final tokens = extractTokensFromProductId(purchase.productID);
    if (tokens <= 0) {
      if (mounted) {
        Utils.showMessage(
          context,
          'Purchase completed but token parsing failed',
          isError: true,
        );
      }
      return;
    }
    await Prefs.addTokens(tokens);
    if (mounted) {
      Utils.showMessage(context, '$tokens credits added!', success: true);
      setState(() {});
    }
  }

  double _pricePerToken(ProductDetails p) {
    final tokens = extractTokensFromProductId(p.id);
    if (tokens == 0) return double.infinity;
    return p.rawPrice / tokens;
  }

  String _formatPricePerToken(ProductDetails p) {
    final value = _pricePerToken(p);
    return '₹${value.toStringAsFixed(2)}/credit';
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentTokens = Prefs.getTokens();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3, 1.0],
            colors: [
              Color(0xFF100A00),
              Color(0xFF121212),
              Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading
                    ? _buildLoading()
                    : !_storeAvailable
                        ? _buildUnavailable()
                        : _products.isEmpty
                            ? _buildNoProducts()
                            : _buildContent(currentTokens),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 4.h, 20.w, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white54, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Buy Credits',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                AppText(
                  'One credit = one AI medicine search',
                  fontSize: 11.sp,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading / error states ────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
          color: UIConstants.accentGreen, strokeWidth: 2),
    );
  }

  Widget _buildUnavailable() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_mall_directory_outlined,
              size: 48, color: Colors.white24),
          20.verticalSpace,
          AppText('Store not available', fontSize: 16.sp, color: Colors.white54),
        ],
      ),
    );
  }

  Widget _buildNoProducts() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white24),
          20.verticalSpace,
          AppText('No products available', fontSize: 16.sp, color: Colors.white54),
        ],
      ),
    );
  }

  // ── Main content ──────────────────────────────────────

  Widget _buildContent(int currentTokens) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 16.h, 0, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBalanceCard(currentTokens),
          24.verticalSpace,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    color: Colors.amber, size: 16),
                6.horizontalSpace,
                AppText(
                  'Choose a Pack',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ],
            ),
          ),
          8.verticalSpace,
          ..._products.map((p) => _buildProductCard(p)),
          16.verticalSpace,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: AppText(
              'Credits never expire. Each credit unlocks one premium AI medicine search. Cached results are always free.',
              fontSize: 11.sp,
              color: Colors.white30,
              lineHeight: 1.55,
              maxLines: 4,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── Balance hero card ─────────────────────────────────

  Widget _buildBalanceCard(int tokens) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(vertical: 22.h, horizontal: 20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withValues(alpha: 0.18),
            Colors.deepOrange.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.stars_rounded,
                color: Colors.amber, size: 24),
          ),
          16.horizontalSpace,
          Expanded(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Credit Balance',
                fontSize: 12.sp,
                color: Colors.amber.shade200.withValues(alpha: 0.7),
              ),
              4.verticalSpace,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppText(
                    '$tokens',
                    fontSize: 38.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  6.horizontalSpace,
                  Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: AppText(
                      'credits',
                      fontSize: 13.sp,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Product card ──────────────────────────────────────

  Widget _buildProductCard(ProductDetails p) {
    final tokens = extractTokensFromProductId(p.id);
    final isBuying = _purchasingProductId == p.id;
    final isBestValue = p.id == _bestValueProductId;
    final isMostPopular = p.id == _getMostPopularProductId(_products);

    final badgeColor = isMostPopular ? Colors.deepOrange : Colors.amber;
    final badgeLabel = isMostPopular ? 'MOST POPULAR' : 'BEST VALUE';
    final showBadge = isMostPopular || (!isMostPopular && isBestValue);

    final borderColor = isMostPopular
        ? Colors.deepOrange.withValues(alpha: 0.55)
        : isBestValue
            ? Colors.amber.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.09);

    return Stack(
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 6.h),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: (isMostPopular
                        ? Colors.deepOrange
                        : isBestValue
                            ? Colors.amber
                            : Colors.transparent)
                    .withValues(alpha: 0.06),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: UIConstants.accentGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: UIConstants.accentGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded,
                            color: UIConstants.accentGreen, size: 13),
                        5.horizontalSpace,
                        AppText(
                          '$tokens Credits',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: UIConstants.accentGreen,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AppText(
                    _formatPricePerToken(p),
                    fontSize: 11.sp,
                    color: Colors.white38,
                  ),
                ],
              ),
              14.verticalSpace,
              AppText(
                p.description,
                fontSize: 12.sp,
                color: Colors.white54,
                maxLines: 2,
                lineHeight: 1.4,
              ),
              16.verticalSpace,
              Row(
                children: [
                  AppText(
                    p.price,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: isBuying ? null : () => _buy(p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConstants.accentGreen,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            UIConstants.accentGreen.withValues(alpha: 0.3),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isBuying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black),
                            )
                          : AppText(
                              'Buy',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showBadge)
          Positioned(
            top: 0,
            right: 24,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8)),
              ),
              child: AppText(
                badgeLabel,
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}
