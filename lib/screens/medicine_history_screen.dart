import 'dart:convert';
import 'dart:developer';

import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/widgets/collapsible_card.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicineHistoryScreen extends StatefulWidget {
  const MedicineHistoryScreen({super.key});

  @override
  State<MedicineHistoryScreen> createState() => _MedicineHistoryScreenState();
}

class _MedicineHistoryScreenState extends State<MedicineHistoryScreen> {
  Map<String, Map<String, List<String>>> _cache = {};
  bool _isLoading = true;
  String? _selectedMedicine;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString("medicine_cache");

    if (cachedJson != null) {
      final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
      _cache = decoded.map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, List<String>.from(v)),
          ),
        ),
      );
      log("📂 Loaded ${_cache.length} medicine entries from history.");
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cache.isEmpty
          ? const Center(child: Text("No history found."))
          : _selectedMedicine == null
          ? _buildMedicineList()
          : _buildMedicineDetails(_selectedMedicine!),
    );
  }

  Widget _buildMedicineList() {
    final keys = _cache.keys.toList().reversed.toList(); // latest first

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: keys.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
      itemBuilder: (context, index) {
        final name = keys[index];
        return ListTile(
          leading: const Icon(
            Icons.medication,
            color: AppColors.appPrimaryRedColor,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () => setState(() => _selectedMedicine = name),
        );
      },
    );
  }

  Widget _buildMedicineDetails(String medicineName) {
    final resultMap = _cache[medicineName.toLowerCase()] ?? {};
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => setState(() => _selectedMedicine = null),
              ),
              Text(
                medicineName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: resultMap.entries.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final section = entry.value;

              return CollapsibleCard(
                key: ValueKey(section.key),
                title: section.key,
                content: section.value,
                initiallyExpanded: index < 2,
                medicineName: medicineName,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
