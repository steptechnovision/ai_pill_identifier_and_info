import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:ai_medicine_tracker/helper/app_assets.dart';
import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/repository/medicine_repository.dart';
import 'package:ai_medicine_tracker/screens/medicine_history_screen.dart';
import 'package:ai_medicine_tracker/screens/token_purchase_screen.dart';
import 'package:ai_medicine_tracker/widgets/collapsible_card.dart';
import 'package:ai_medicine_tracker/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicineTrackerScreen extends StatefulWidget {
  const MedicineTrackerScreen({super.key});

  @override
  State<MedicineTrackerScreen> createState() => _MedicineTrackerScreenState();
}

class _MedicineTrackerScreenState extends State<MedicineTrackerScreen> {
  final MedicineRepository repo = MedicineRepository();
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  Map<String, List<String>>? _resultMap;

  /// 🗂 Local in-memory cache (medicineName -> resultMap)
  final Map<String, Map<String, List<String>>> _cache = {};

  /// Suggestions list
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadCacheFromPrefs();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchTextChanged(String value) async {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final query = value.trim();
      if (query.isEmpty) {
        setState(() {
          _suggestions = [];
          _resultMap = null; // 👈 optional reset
        });
        return;
      }
      final suggestions = await repo.getSuggestions(query);
      setState(() => _suggestions = suggestions);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Medicine Tracker")),
      body: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TokenPurchaseScreen(currentTokens: 10),
                ),
              );
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.appPrimaryRedColor,
              ),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Text(
                "Purchase",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomTextField(
                        hintText: 'Search medicine...',
                        prefixIcon: AppAssets.icSearch,
                        controller: _controller,
                        showDividerOnSuffixIcon: false,
                        onChanged: _onSearchTextChanged,
                        textFieldHintTextColor:
                            AppColors.textFieldHintTextColorNew,
                        isSearchView: true,
                        showCancelButton: true,
                      ),
                      if (_suggestions.isNotEmpty) _buildSuggestions(),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _searchMedicine,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          if (_resultMap != null) Expanded(child: _buildResultView()),
        ],
      ),
      bottomNavigationBar: Container(
        margin: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MedicineHistoryScreen(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.appPrimaryRedColor,
                ),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Text(
                  "View History",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
            ),
            Text(
              "*This app provides AI-generated info. Consult a doctor before taking any medication.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  /// Load cache from SharedPreferences when app starts
  Future<void> _loadCacheFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString("medicine_cache");
    if (cachedJson != null) {
      final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        _cache[key] = (value as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, List<String>.from(v)),
        );
      });
    }
    printLog("📂 Cache loaded from SharedPrefs: ${_cache.keys.toList()}");
  }

  Future<void> _searchMedicine() async {
    final medicineName = _controller.text.trim();
    if (medicineName.isEmpty) return;

    setState(() {
      _isLoading = true;
      _resultMap = null;
      _suggestions.clear();
    });

    try {
      final result = await repo.fetchMedicine(medicineName);
      setState(() => _resultMap = result);
    } catch (e, st) {
      log("❌ Error: $e\n$st");
      setState(
        () => _resultMap = {
          "Error": ["$e"],
        },
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildResultView() {
    if (_resultMap == null || _resultMap!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "No information available for this medicine.",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: _resultMap!.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final section = entry.value;

        return CollapsibleCard(
          key: ValueKey(section.key),
          title: section.key,
          content: section.value,
          initiallyExpanded: index < 2,
          medicineName: _controller.text.trim(),
        );
      }).toList(),
    );
  }

  Widget _buildSuggestions() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          color: Theme.of(context).colorScheme.surface,
          // dark surface color
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              _controller.text = suggestion;
              _suggestions.clear();
              setState(() {});
              _searchMedicine();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.medication,
                    color: AppColors.appPrimaryRedColor,
                    // icon accent
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
