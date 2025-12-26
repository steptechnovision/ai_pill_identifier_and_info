import 'dart:async';

import 'package:ai_medicine_tracker/helper/prefs.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/services/remote_config_service.dart';
import 'package:flutter/material.dart';
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

  // ------------------------------------------------
  // INIT FLOW
  // ------------------------------------------------
  Future<void> _initPurchaseFlow() async {
    setState(() => _loading = true);

    // 1️⃣ Listen purchase updates
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (_) {
        Utils.showMessage(context, 'Purchase stream error', isError: true);
      },
    );

    // 2️⃣ Check store availability
    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      setState(() => _loading = false);
      Utils.showMessage(context, 'Store not available', isError: true);
      return;
    }

    // 3️⃣ Fetch Remote Config
    await RemoteConfigService.init();
    final productIds = RemoteConfigService.getTokenProductIds();

    if (productIds.isEmpty) {
      setState(() => _loading = false);
      Utils.showMessage(context, 'No products configured', isError: true);
      return;
    }

    // 4️⃣ Query Play Store
    final response = await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      setState(() => _loading = false);
      Utils.showMessage(
        context,
        response.error!.message ?? 'Failed to load products',
        isError: true,
      );
      return;
    }

    _products = response.productDetails;

    _bestValueProductId = getBestValueProductId(_products);
    final mostPopularId = getMostPopularProductId(_products);

    _products.sort((a, b) {
      if (a.id == mostPopularId) return -1;
      if (b.id == mostPopularId) return 1;
      if (a.id == _bestValueProductId) return -1;
      if (b.id == _bestValueProductId) return 1;

      return extractTokensFromProductId(a.id)
          .compareTo(extractTokensFromProductId(b.id));
    });

    setState(() => _loading = false);
  }

  String? getBestValueProductId(List<ProductDetails> products) {
    if (products.isEmpty) return null;

    final copy = List<ProductDetails>.from(products);

    copy.sort(
          (a, b) => extractTokensFromProductId(b.id)
          .compareTo(extractTokensFromProductId(a.id)),
    );

    return copy.first.id;
  }

  // ------------------------------------------------
  // BUY FLOW
  // ------------------------------------------------
  Future<void> _buy(ProductDetails product) async {
    if (_purchasingProductId != null) return;

    setState(() => _purchasingProductId = product.id);
    print('chechPurchase _purchasingProductId--$_purchasingProductId--');
    try {
      final param = PurchaseParam(productDetails: product);
      await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
    } catch (error) {
      print('chechPurchase error--${error}--');
      setState(() => _purchasingProductId = null);
      Utils.showMessage(context, 'Purchase failed', isError: true);
    }
  }

  // ------------------------------------------------
  // PURCHASE UPDATES
  // ------------------------------------------------
  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        Utils.showMessage(
          context,
          purchase.error?.message ?? 'Purchase error',
          isError: true,
        );
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _deliverPurchase(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      setState(() => _purchasingProductId = null);
    }
  }

  // ------------------------------------------------
  // DELIVER TOKENS
  // ------------------------------------------------
  Future<void> _deliverPurchase(PurchaseDetails purchase) async {
    final tokens = extractTokensFromProductId(purchase.productID);

    if (tokens <= 0) {
      Utils.showMessage(
        context,
        'Purchase completed but token parsing failed',
        isError: true,
      );
      return;
    }

    await Prefs.addTokens(tokens);

    Utils.showMessage(
      context,
      '🎉 $tokens tokens added successfully!',
      success: true,
    );

    setState(() {});
  }

  double pricePerToken(ProductDetails p) {
    final tokens = extractTokensFromProductId(p.id);
    if (tokens == 0) return double.infinity;
    return p.rawPrice / tokens;
  }

  String formatPricePerToken(ProductDetails p) {
    final value = pricePerToken(p);
    return '₹${value.toStringAsFixed(2)} / token';
  }

  String? getMostPopularProductId(List<ProductDetails> products) {
    if (products.length < 3) return null;

    final sorted = List<ProductDetails>.from(products)
      ..sort(
            (a, b) => extractTokensFromProductId(a.id)
            .compareTo(extractTokensFromProductId(b.id)),
      );

    return sorted[sorted.length ~/ 2].id;
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------
  // UI
  // ------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final currentTokens = Prefs.getTokens();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Tokens'),
        centerTitle: true,
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.symmetric(horizontal: 12),
        //     child: Center(
        //       child: Text(
        //         'Tokens: $currentTokens',
        //         style: const TextStyle(fontWeight: FontWeight.w600),
        //       ),
        //     ),
        //   ),
        // ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_storeAvailable
          ? const Center(child: Text('Store not available'))
          : _products.isEmpty
          ? const Center(child: Text('No products available'))
          : Column(
        children: [
          _buildTokenBalanceCard(currentTokens),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _products.length,
              itemBuilder: (_, i) =>
                  _buildProductTile(_products[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenBalanceCard(int tokens) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.15),
            Colors.deepOrange.withOpacity(0.15),
          ],
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Your Token Balance',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tokens.toString(),
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use tokens to unlock premium features',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(ProductDetails p) {
    final tokens = extractTokensFromProductId(p.id);
    final isBuying = _purchasingProductId == p.id;
    final isBestValue = p.id == _bestValueProductId;
    final isMostPopular = p.id == getMostPopularProductId(_products);

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey.shade900,
            border: Border.all(
              color: isMostPopular
                  ? Colors.orange
                  : Colors.grey.withOpacity(0.2),
              width: isMostPopular ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔢 Token Count
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$tokens Tokens',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatPricePerToken(p),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 📄 Description
              Text(
                p.description,
                style: const TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 16),

              // 💰 Price + Button
              Row(
                children: [
                  Text(
                    p.price,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: isBuying ? null : () => _buy(p),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isBuying
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Buy'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (isMostPopular)
          _buildBadge('MOST POPULAR', Colors.deepOrange),

        if (!isMostPopular && isBestValue)
          _buildBadge('BEST VALUE', Colors.orangeAccent),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Positioned(
      top: 6,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

}
