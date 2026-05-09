import 'package:ai_medicine_tracker/screens/web_search_screen.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CollapsibleCard extends StatefulWidget {
  final String title;
  final List<String> content;
  final bool initiallyExpanded;
  final String medicineName;

  const CollapsibleCard({
    super.key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
    required this.medicineName,
  });

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  static const Map<String, (IconData, Color)> _meta = {
    'Pros': (Icons.thumb_up_rounded, Color(0xFF00E676)),
    'Cons': (Icons.thumb_down_rounded, Colors.redAccent),
    'Benefits': (Icons.favorite_rounded, Color(0xFF00E676)),
    'Usage': (Icons.medical_services_rounded, Colors.blue),
    'WhoCanTake': (Icons.person_rounded, Colors.purple),
    'SideEffects': (Icons.warning_amber_rounded, Colors.orange),
    'Precautions': (Icons.shield_rounded, Colors.amber),
    'ExtraInformation': (Icons.info_rounded, Colors.blueGrey),
    'Dosage': (Icons.numbers_rounded, Color(0xFF9C27B0)),
    'Interactions': (Icons.compare_arrows_rounded, Colors.redAccent),
    'Storage': (Icons.inventory_2_rounded, Colors.blueGrey),
    'Warnings': (Icons.report_rounded, Colors.red),
    'FAQs': (Icons.quiz_rounded, Colors.teal),
  };

  (IconData, Color) get _sectionMeta =>
      _meta[widget.title] ??
      (Icons.article_rounded, Colors.white38);

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
    if (_expanded) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      _expanded ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _sectionMeta;
    final count = widget.content.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _expanded
            ? const Color(0xFF1E1E1E)
            : const Color(0xFF191919),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _expanded
              ? color.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _toggle,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: _expanded ? 0.14 : 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon,
                          size: 16,
                          color: color.withValues(
                              alpha: _expanded ? 1.0 : 0.7)),
                    ),
                    8.horizontalSpace,
                    Expanded(
                      child: AppText(
                        widget.title,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: _expanded ? Colors.white : Colors.white70,
                        maxLines: 1,
                      ),
                    ),
                    // Count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(
                            alpha: _expanded ? 0.14 : 0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: AppText(
                        '$count',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: color.withValues(
                            alpha: _expanded ? 1.0 : 0.6),
                      ),
                    ),
                    // Web search (compact)
                    GestureDetector(
                      onTap: () {
                        final query = Uri.encodeComponent(
                          '${widget.medicineName} ${widget.title}',
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WebSearchScreen(
                              query: query,
                              medicineName: widget.medicineName,
                              title: widget.title,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 4.h),
                        child: Icon(Icons.open_in_new_rounded,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 250),
                      turns: _expanded ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _expanded
                            ? color.withValues(alpha: 0.8)
                            : Colors.white30,
                        size: 20,
                      ),
                    ),
                  ],
                ),

                // Body
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  axisAlignment: -1.0,
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.h, left: 4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.content
                          .map(
                            (point) => Padding(
                              padding: EdgeInsets.only(bottom: 5.h),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 6, right: 8),
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.7),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: AppText(
                                      point,
                                      color: Colors.white.withValues(
                                          alpha: 0.72),
                                      fontSize: 15.sp,
                                      maxLines: 200,
                                      lineHeight: 1.45,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
