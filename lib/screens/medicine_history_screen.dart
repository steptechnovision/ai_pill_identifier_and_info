import 'package:ai_medicine_tracker/helper/app_assets.dart';
import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/utils.dart';
import 'package:ai_medicine_tracker/repository/medicine_repository.dart';
import 'package:ai_medicine_tracker/widgets/collapsible_card.dart';
import 'package:ai_medicine_tracker/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';

class MedicineHistoryScreen extends StatefulWidget {
  const MedicineHistoryScreen({super.key});

  @override
  State<MedicineHistoryScreen> createState() => _MedicineHistoryScreenState();
}

class _MedicineHistoryScreenState extends State<MedicineHistoryScreen> {
  final MedicineRepository repo = MedicineRepository();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<MedicineItem> _history = [];
  List<MedicineItem> _filteredHistory = [];

  MedicineItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await repo.ensureLoaded();
    final all = repo.getAllCachedItems();

    // Latest first
    all.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    _history = all;
    _filteredHistory = all;

    setState(() => _isLoading = false);
  }

  void _searchHistory(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredHistory = _history
          .where((item) => item.originalName.toLowerCase().contains(q))
          .toList();
    });
  }

  // Group by Today / This Week / Earlier
  String _groupTitle(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return "Today";
    }
    if (now.difference(date).inDays <= 7) {
      return "This Week";
    }
    return "Earlier";
  }

  Future<void> _deleteFromHistory(MedicineItem item) async {
    await repo.deleteMedicine(item.canonicalName);

    setState(() {
      _history.remove(item);
      _filteredHistory.remove(item);
      if (_selectedItem == item) _selectedItem = null;
    });

    Utils.showToast(context, message: "Removed from history 🗑");
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedItem == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedItem != null) {
          setState(() => _selectedItem = null);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0B),
        appBar: AppBar(
          title: Text(
            _selectedItem == null ? "History" : _selectedItem!.originalName,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedItem == null
            ? _buildHistoryList()
            : _buildDetails(_selectedItem!),
      ),
    );
  }

  // 📌 LIST VIEW WITH SEARCH + GROUPING
  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Center(
        child: Text(
          "No history found.",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      children: [
        // 🔍 Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: CustomTextField(
            hintText: "Search history…",
            prefixIcon: AppAssets.icSearch,
            controller: _searchController,
            showDividerOnSuffixIcon: false,
            onChanged: _searchHistory,
            isSearchView: true,
            showCancelButton: true, // cross icon remains
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredHistory.length,
            itemBuilder: (_, index) {
              final item = _filteredHistory[index];
              final title = _groupTitle(item.lastUsedAt);

              final showHeader =
                  index == 0 ||
                  title != _groupTitle(_filteredHistory[index - 1].lastUsedAt);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        top: 14,
                        bottom: 6,
                      ),
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),

                  ListTile(
                    onTap: () => setState(() => _selectedItem = item),
                    leading: const Icon(
                      Icons.medication,
                      color: AppColors.appPrimaryRedColor,
                    ),

                    title: Text(
                      item.originalName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),

                    trailing: Wrap(
                      children: [
                        // 🗑 Delete button
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteFromHistory(item),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // 📌 DETAILS VIEW
  Widget _buildDetails(MedicineItem item) {
    final entries = item.sections.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (_, index) {
        final e = entries[index];
        return CollapsibleCard(
          key: ValueKey(e.key),
          title: e.key,
          content: e.value,
          initiallyExpanded: index < 2,
          medicineName: item.originalName,
        );
      },
    );
  }
}

// import 'dart:developer';
//
// import 'package:ai_medicine_tracker/helper/app_colors.dart';
// import 'package:ai_medicine_tracker/repository/medicine_repository.dart';
// import 'package:ai_medicine_tracker/widgets/collapsible_card.dart';
// import 'package:flutter/material.dart';
//
// class MedicineHistoryScreen extends StatefulWidget {
//   const MedicineHistoryScreen({super.key});
//
//   @override
//   State<MedicineHistoryScreen> createState() => _MedicineHistoryScreenState();
// }
//
// class _MedicineHistoryScreenState extends State<MedicineHistoryScreen> {
//   final MedicineRepository repo = MedicineRepository();
//
//   bool _isLoading = true;
//
//   /// history list as MedicineItem
//   List<MedicineItem> _history = [];
//
//   MedicineItem? _selectedItem;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadHistory();
//   }
//
//   Future<void> _loadHistory() async {
//     await repo.ensureLoaded(); // load everything from SharedPreferences
//
//     _history = repo.getAllCachedItems().reversed.toList(); // latest first
//
//     log("📂 Loaded ${_history.length} medicine items from history.");
//
//     setState(() => _isLoading = false);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: _selectedItem == null,
//       onPopInvokedWithResult: (didPop, result) {
//         if (!didPop && _selectedItem != null) {
//           setState(() => _selectedItem = null);
//         }
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           title: Text(
//             _selectedItem == null ? "History" : _selectedItem!.originalName,
//           ),
//         ),
//         body: _isLoading
//             ? const Center(child: CircularProgressIndicator())
//             : _history.isEmpty
//             ? const Center(child: Text("No history found."))
//             : _selectedItem == null
//             ? _buildMedicineList()
//             : _buildMedicineDetails(_selectedItem!),
//       ),
//     );
//   }
//
//   // -------------------------------------------------------------
//   // LIST OF MEDICINES (unchanged UI, improved logic)
//   // -------------------------------------------------------------
//   Widget _buildMedicineList() {
//     final savedTokens = _history.length;
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // 🎉 Smart Saver Banner
//         Container(
//           width: double.infinity,
//           margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.greenAccent.withValues(alpha: 0.12),
//             borderRadius: BorderRadius.circular(10),
//             border: Border.all(
//               color: Colors.greenAccent.withValues(alpha: 0.3),
//               width: 1.2,
//             ),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: const [
//                   Icon(Icons.savings, color: Colors.greenAccent, size: 20),
//                   SizedBox(width: 6),
//                   Text(
//                     "Smart Saver!",
//                     style: TextStyle(
//                       color: Colors.greenAccent,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 6),
//               Text(
//                 "You saved $savedTokens tokens by re-viewing medicines instead of spending credits again 🎉",
//                 style: const TextStyle(color: Colors.white70, fontSize: 12),
//               ),
//             ],
//           ),
//         ),
//         // Medicine List
//         Expanded(
//           child: ListView.separated(
//             padding: const EdgeInsets.all(12),
//             itemCount: _history.length,
//             separatorBuilder: (_, __) =>
//                 Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
//             itemBuilder: (_, index) {
//               final item = _history[index];
//
//               return ListTile(
//                 leading: const Icon(
//                   Icons.medication,
//                   color: AppColors.appPrimaryRedColor,
//                 ),
//                 title: Text(
//                   item.originalName,
//                   style: const TextStyle(fontWeight: FontWeight.w600),
//                 ),
//                 trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
//                 onTap: () => setState(() => _selectedItem = item),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
//
//   // -------------------------------------------------------------
//   // MEDICINE DETAILS (unchanged UI, improved logic)
//   // -------------------------------------------------------------
//   Widget _buildMedicineDetails(MedicineItem item) {
//     final entries = item.sections.entries.toList();
//
//     return Column(
//       children: [
//         Expanded(
//           child: ListView.builder(
//             padding: const EdgeInsets.all(12),
//             itemCount: entries.length,
//             itemBuilder: (_, index) {
//               final e = entries[index];
//
//               return CollapsibleCard(
//                 key: ValueKey(e.key),
//                 title: e.key,
//                 content: e.value,
//                 initiallyExpanded: index < 2,
//                 medicineName: item.originalName,
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }
