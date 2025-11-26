import 'dart:ui';

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

  // ------------------------
  // Helpers: parse dynamic info
  // ------------------------

  /// Extract number (first integer) from title like "500 Tokens Pack".
  /// Returns 0 if not found.
  int _extractTokenCount(String title) {
    final match = RegExp(r'\d+').firstMatch(title);
    if (match != null) {
      try {
        return int.parse(match.group(0)!);
      } catch (_) {}
    }
    return 0;
  }

  /// Parse price numeric value from either storeProduct.price (if available)
  /// or from priceString (strip currency symbols).
  double _parsePrice(StoreProduct p) {
    try {
      // Some StoreProduct implementations include a numeric `price` field.
      final dynamic maybePrice = p.price;
      if (maybePrice is num) return maybePrice.toDouble();
    } catch (_) {}
    // Fallback: parse priceString like "₹1,950.00"
    final s = p.priceString;
    final digits = RegExp(r'[\d,]+(\.\d+)?').firstMatch(s)?.group(0) ?? '0';
    final cleaned = digits.replaceAll(',', '');
    try {
      return double.parse(cleaned);
    } catch (_) {
      return 0.0;
    }
  }

  // ------------------------
  // Determine best-value and discounts
  // ------------------------

  // Returns id of package that is best (highest tokens). If tie, pick largest price (still "highest amount").
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

  // Computes per-token price (price / tokens). If tokens=0 returns huge number.
  double _pricePerToken(Package pkg) {
    final tokens = _extractTokenCount(pkg.storeProduct.title);
    final price = _parsePrice(pkg.storeProduct);
    if (tokens <= 0) return double.infinity;
    return price / tokens;
  }

  // ------------------------
  // Purchase / Restore
  // ------------------------

  Future<void> _purchase(Package pkg) async {
    setState(() => isProcessing = true);
    try {
      final result = await Purchases.purchasePackage(pkg);

      // RevenueCat finishes consumables automatically; we need to credit tokens locally/backend.
      final productId = pkg.storeProduct.identifier;
      final tokenCount = _extractTokenCount(pkg.storeProduct.title);

      /// TODO: Save tokenCount to your backend or SharedPreferences
      /// Example: await MyBackend.creditTokensForUser(tokenCount);

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

      /// NOTE: For consumables, restorePurchases might not return consumable history.
      /// You should rely on your backend to re-credit if you track purchases server-side.
      setState(() => isProcessing = false);
      _showMessage('Restore completed. If you had previous purchases, they will be applied.', success: true);
    } catch (e) {
      setState(() => isProcessing = false);
      _showMessage('Restore failed or nothing to restore.', isError: true);
    }
  }

  void _showMessage(String msg, {bool success = false, bool isError = false}) {
    final color = success ? Colors.greenAccent[700] : (isError ? Colors.redAccent : Colors.blueAccent);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
      ),
    );
  }

  // ------------------------
  // UI Building
  // ------------------------

  @override
  Widget build(BuildContext context) {
    final packages = offerings?.current?.availablePackages ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Buy Credits', style: TextStyle(fontWeight: FontWeight.w700)),
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
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.white30),
            const SizedBox(height: 12),
            const Text('No purchase packages available', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadOfferings,
              child: const Text('Retry', style: TextStyle(color: Colors.blueAccent)),
            )
          ],
        ),
      );
    }

    final bestId = _bestPackageIdentifier(packages);

    // prepare per-token baseline => cheapest per-token to compute discount
    final perTokenList = packages.map((p) => _pricePerToken(p)).toList();
    final cheapestPerToken = perTokenList.reduce((a, b) => a < b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _glassHeader(),

          const SizedBox(height: 20),

          // Benefit text
          _benefitsCard(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: .2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "🔥 One-time Search = Lifetime Access",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Search a medicine once using credits — and it remains FREE forever!",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "✔ 0 Token for previously searched medicines 🎉",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Packages grid (responsive)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: packages.map((p) {
              final title = p.storeProduct.title;
              final tokens = _extractTokenCount(title);
              final priceStr = p.storeProduct.priceString;
              final perToken = _pricePerToken(p);
              final discountPercent =
              cheapestPerToken.isFinite && perToken.isFinite && perToken < cheapestPerToken
                  ? ((1 - (perToken / cheapestPerToken)) * 100)
                  : 0.0;
              final isBest = p.identifier == bestId;
              return _packageTile(
                package: p,
                tokens: tokens,
                priceString: priceStr,
                isBest: isBest,
                discountPercent: discountPercent,
              );
            }).toList(),
          ),

          const SizedBox(height: 22),

          // Restore & FAQ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _restorePurchases,
                icon: const Icon(Icons.restore, color: Colors.blueAccent),
                label: const Text('Restore Purchases', style: TextStyle(color: Colors.blueAccent)),
              ),
              TextButton(
                onPressed: () => _showMessage('Support: contact us at support@example.com'),
                child: const Text('Need help?', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  // Glass header with neon glow and tokens display
  Widget _glassHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), offset: const Offset(0, 6), blurRadius: 12),
            ],
          ),
          child: Row(
            children: [
              // left: token count
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.greenAccent.withValues(alpha: .12), Colors.greenAccent.withValues(alpha: .06)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: .2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Credits', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.currentTokens}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Each generation consumes 1 credit', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // right: benefit bubble
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _neonBadge('Pro Tip', Icons.lightbulb),
                    const SizedBox(height: 8),
                    const Text(
                      'Buy packs in bulk for better value. Highest token pack is marked as "Best value".',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // small neon badge widget
  Widget _neonBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [Colors.blueAccent.withValues(alpha: .18), Colors.purpleAccent.withValues(alpha: .08)]),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: .4)),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: .06), blurRadius: 8, spreadRadius: 1)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blueAccent),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _benefitsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Benefits: Faster generations, priority queue, and offline storage options. Tokens never expire.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Individual package tile (glass + neon highlight + discount ribbon)
  Widget _packageTile({
    required Package package,
    required int tokens,
    required String priceString,
    required bool isBest,
    required double discountPercent,
  }) {
    final primary = isBest ? Colors.purpleAccent : Colors.white12;
    final neon = isBest ? Colors.purpleAccent : Colors.blueAccent;

    return SizedBox(
      width: 320, // fixed tile width for nicer grid; wrap handles responsiveness
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glass card
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.02),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    if (isBest)
                      BoxShadow(
                        color: neon.withOpacity(0.14),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    // icon
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(colors: [
                          neon.withOpacity(0.12),
                          neon.withOpacity(0.04),
                        ]),
                        border: Border.all(color: neon.withOpacity(0.18)),
                      ),
                      child: Center(
                        child: Icon(Icons.local_florist, size: 30, color: isBest ? neon : Colors.greenAccent),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // token count (prefer numeric if we have)
                          Text(
                            tokens > 0 ? '$tokens Tokens' : package.storeProduct.title,
                            style: TextStyle(
                              color: isBest ? Colors.white : Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            priceString,
                            style: const TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          // small subtext e.g. "Good for heavy users"
                          Text(
                            tokens >= 1000
                                ? 'Best for agencies & power users'
                                : tokens >= 200
                                ? 'Great value'
                                : 'Starter pack',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    // buy button
                    ElevatedButton(
                      onPressed: () => _purchase(package),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBest ? neon : Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      child: const Text('Buy'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Discount ribbon (top-left)
          if (discountPercent > 0.9)
            Positioned(
              top: -8,
              left: -8,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.18)),
                  ),
                  child: Text(
                    'Save ${discountPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),

          // Best value ribbon (top-right)
          if (isBest)
            Positioned(
              top: -8,
              right: -8,
              child: Transform.rotate(
                angle: 0.35,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.purpleAccent, Colors.deepPurpleAccent]),
                    boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.18), blurRadius: 10)],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Simple overlay while processing (purchase/restore)
  Widget _processingOverlay() {
    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: Colors.black45,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:purchases_flutter/purchases_flutter.dart';
//
// class SubscriptionScreen extends StatefulWidget {
//   const SubscriptionScreen({super.key});
//
//   @override
//   State<SubscriptionScreen> createState() => _SubscriptionScreenState();
// }
//
// class _SubscriptionScreenState extends State<SubscriptionScreen> {
//   Offerings? offerings;
//   bool isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchOfferings();
//   }
//
//   Future<void> _fetchOfferings() async {
//     try {
//       final fetchedOfferings = await Purchases.getOfferings();
//       setState(() {
//         offerings = fetchedOfferings;
//         isLoading = false;
//       });
//     } catch (e) {
//       debugPrint("Error fetching offerings: $e");
//       setState(() => isLoading = false);
//     }
//   }
//
//   Future<void> _purchase(Package package) async {
//     try {
//       final PurchaseParams purchaseParams = PurchaseParams.package(package);
//       final PurchaseResult purchaseResult = await Purchases.purchase(
//         purchaseParams,
//       );
//       if (purchaseResult.customerInfo.entitlements.active.isNotEmpty) {
//         // ✅ Grant tokens or access here
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text("Purchase successful!")));
//       }
//     } catch (e) {
//       debugPrint("Purchase failed: $e");
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final packages = offerings?.current?.availablePackages ?? [];
//
//     return Scaffold(
//       backgroundColor: const Color(0xFF0D0D0D),
//       appBar: AppBar(
//         title: const Text("Buy Tokens"),
//         backgroundColor: Colors.black,
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : packages.isEmpty
//           ? const Center(
//               child: Text(
//                 "No plans available.",
//                 style: TextStyle(color: Colors.white),
//               ),
//             )
//           : ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: packages.length,
//               itemBuilder: (context, index) {
//                 final package = packages[index];
//                 final product = package.storeProduct;
//
//                 return Container(
//                   margin: const EdgeInsets.only(bottom: 16),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade900,
//                     borderRadius: BorderRadius.circular(16),
//                     border: Border.all(color: Colors.white10),
//                   ),
//                   child: ListTile(
//                     contentPadding: const EdgeInsets.all(16),
//                     title: Text(
//                       product.title.split('(').first.trim(),
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     subtitle: Text(
//                       product.description,
//                       style: TextStyle(
//                         color: Colors.grey.shade400,
//                         fontSize: 14,
//                       ),
//                     ),
//                     trailing: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blueAccent,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       onPressed: () => _purchase(package),
//                       child: Text(product.priceString),
//                     ),
//                   ),
//                 );
//               },
//             ),
//     );
//   }
// }
