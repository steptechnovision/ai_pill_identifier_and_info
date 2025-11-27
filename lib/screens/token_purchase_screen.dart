import 'dart:ui';

import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// TokenPurchaseScreen
/// - dynamic (works for any new packages you add in RevenueCat)
/// - marks the package with the HIGHEST token count as "Best value"
/// - shows a computed "Save X%" ribbon for packages with better per-token price
/// - premium glassmorphism + neon glow UI (dark)
///
/// Usage:
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => TokenPurchaseScreen(currentTokens: yourCurrentTokens),
/// ));
class TokenPurchaseScreen extends StatefulWidget {
  final int currentTokens;

  const TokenPurchaseScreen({super.key, required this.currentTokens});

  @override
  State<TokenPurchaseScreen> createState() => _TokenPurchaseScreenState();
}

class _TokenPurchaseScreenState extends State<TokenPurchaseScreen> {
  // ---------------------------------------------------------------------------
  // LOGIC SECTION (EXACTLY AS PROVIDED)
  // ---------------------------------------------------------------------------
  Offerings? offerings;
  bool isLoading = true;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final fetched = await Purchases.getOfferings();
      setState(() {
        offerings = fetched;
        isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to fetch offerings: $e\n$st');
      setState(() => isLoading = false);
      _showMessage('Failed to load packages. Please try again.', isError: true);
    }
  }

  int _extractTokenCount(String title) {
    final match = RegExp(r'\d+').firstMatch(title);
    if (match != null) {
      try {
        return int.parse(match.group(0)!);
      } catch (_) {}
    }
    return 0;
  }

  double _parsePrice(StoreProduct p) {
    try {
      final dynamic maybePrice = p.price;
      if (maybePrice is num) return maybePrice.toDouble();
    } catch (_) {}
    final s = p.priceString;
    final digits = RegExp(r'[\d,]+(\.\d+)?').firstMatch(s)?.group(0) ?? '0';
    final cleaned = digits.replaceAll(',', '');
    try {
      return double.parse(cleaned);
    } catch (_) {
      return 0.0;
    }
  }

  String _bestPackageIdentifier(List<Package> pkgs) {
    String bestId = '';
    int bestTokens = -1;
    double bestPrice = 0;
    for (var pkg in pkgs) {
      final t = _extractTokenCount(pkg.storeProduct.title);
      final price = _parsePrice(pkg.storeProduct);
      if (t > bestTokens || (t == bestTokens && price > bestPrice)) {
        bestTokens = t;
        bestPrice = price;
        bestId = pkg.identifier;
      }
    }
    return bestId;
  }

  double _pricePerToken(Package pkg) {
    final tokens = _extractTokenCount(pkg.storeProduct.title);
    final price = _parsePrice(pkg.storeProduct);
    if (tokens <= 0) return double.infinity;
    return price / tokens;
  }

  Future<void> _purchase(Package pkg) async {
    setState(() => isProcessing = true);
    try {
      await Purchases.purchasePackage(pkg);
      final tokenCount = _extractTokenCount(pkg.storeProduct.title);
      // Logic to save tokens backend...
      setState(() => isProcessing = false);
      _showMessage('Purchase successful — you received $tokenCount tokens!', success: true);
    } catch (e) {
      setState(() => isProcessing = false);
      debugPrint('Purchase error: $e');
      _showMessage('Purchase failed or cancelled.', isError: true);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => isProcessing = true);
    try {
      await Purchases.restorePurchases();
      setState(() => isProcessing = false);
      _showMessage('Restore completed.', success: true);
    } catch (e) {
      setState(() => isProcessing = false);
      _showMessage('Restore failed or nothing to restore.', isError: true);
    }
  }

  void _showMessage(String msg, {bool success = false, bool isError = false}) {
    final color = success ? Colors.greenAccent[700] : (isError ? Colors.redAccent : Colors.blueAccent);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ---------------------------------------------------------------------------
  // IMPROVED UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final packages = offerings?.current?.availablePackages ?? [];

    return Scaffold(
      backgroundColor: UIConstants.darkBackgroundStart,
      appBar: AppBar(
        backgroundColor: UIConstants.darkBackgroundStart,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Credits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _buildBody(packages),
          if (isProcessing) _processingOverlay(),
        ],
      ),
    );
  }

  Widget _buildBody(List<Package> packages) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: UIConstants.accentGreen));
    }

    if (packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            const Text('No packages available', style: TextStyle(color: Colors.white70)),
            TextButton(
              onPressed: _loadOfferings,
              child: const Text('Retry', style: TextStyle(color: UIConstants.accentGreen)),
            )
          ],
        ),
      );
    }

    final bestId = _bestPackageIdentifier(packages);

    // Calculate baseline for discounts
    final perTokenList = packages.map((p) => _pricePerToken(p)).toList();
    final cheapestPerToken = perTokenList.isNotEmpty
        ? perTokenList.reduce((a, b) => a < b ? a : b)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Current Balance Header
          _buildBalanceHeader(),

          const SizedBox(height: 24),

          // 2. Info Banner (One-time search USP)
          _buildInfoBanner(),

          const SizedBox(height: 24),

          const Text(
            "Select a Package",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 3. Package List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: packages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final p = packages[index];
              final perToken = _pricePerToken(p);
              final discount = (cheapestPerToken.isFinite && perToken.isFinite && perToken < cheapestPerToken)
                  ? ((1 - (perToken / cheapestPerToken)) * 100)
                  : 0.0;

              return _buildPackageCard(
                pkg: p,
                isBest: p.identifier == bestId,
                discountPercent: discount,
              );
            },
          ),

          const SizedBox(height: 30),

          // 4. Footer
          Center(
            child: TextButton(
              onPressed: _restorePurchases,
              style: TextButton.styleFrom(foregroundColor: Colors.white54),
              child: const Text("Restore Purchases", style: TextStyle(decoration: TextDecoration.underline)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            UIConstants.accentGreen.withValues(alpha: 0.2),
            UIConstants.accentGreen.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: UIConstants.accentGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Text(
            "CURRENT BALANCE",
            style: TextStyle(
              color: UIConstants.accentGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${widget.currentTokens}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Credits Available",
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt_rounded, color: Colors.amber, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Search once, access forever",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  "Credits are only deducted for new searches. Viewing history is always free.",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard({
    required Package pkg,
    required bool isBest,
    required double discountPercent,
  }) {
    final tokenCount = _extractTokenCount(pkg.storeProduct.title);
    // Gold color for 'Best Value'
    const bestColor = Color(0xFFFFD700);

    return GestureDetector(
      onTap: () => _purchase(pkg),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: isBest
                  ? Border.all(color: bestColor.withValues(alpha: 0.5), width: 1.5)
                  : Border.all(color: Colors.white.withValues(alpha: 0.05)),
              boxShadow: isBest
                  ? [BoxShadow(color: bestColor.withValues(alpha: 0.1), blurRadius: 12)]
                  : [],
            ),
            child: Row(
              children: [
                // Icon Box
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isBest
                        ? bestColor.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.stars_rounded,
                    color: isBest ? bestColor : Colors.white70,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "$tokenCount Credits",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (discountPercent > 1) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: UIConstants.accentGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "SAVE ${discountPercent.toInt()}%",
                                style: const TextStyle(
                                  color: UIConstants.accentGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pkg.storeProduct.priceString,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Buy Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isBest ? bestColor : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Buy",
                    style: TextStyle(
                      color: isBest ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 'Best Value' Floating Tag
          if (isBest)
            Positioned(
              top: -10,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bestColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                  ],
                ),
                child: const Text(
                  "BEST VALUE",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _processingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: const Center(
        child: CircularProgressIndicator(color: UIConstants.accentGreen),
      ),
    );
  }
}