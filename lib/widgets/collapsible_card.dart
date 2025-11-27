import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/screens/web_search_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn, // Smooth "physics-like" feel
    );

    if (_expanded) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✨ Using AnimatedContainer for smooth background color transition
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        // ✨ Soft fill instead of hard border
        color: _expanded
            ? Colors.white.withValues(alpha: 0.08) // Slightly lighter when open
            : Colors.white.withValues(alpha: 0.04), // Very subtle when closed
        borderRadius: BorderRadius.circular(12),
        // ✨ Only show a faint glow border when expanded
        border: Border.all(
          color: _expanded
              ? UIConstants.accentGreen.withValues(alpha: 0.2)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _toggleExpand,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: _expanded
                              ? UIConstants.accentGreen
                              : Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          // ✨ Semi-bold is cleaner than Bold
                          fontSize: 16.sp,
                        ),
                      ),
                    ),

                    // ✨ Compact Search Button
                    IconButton(
                      icon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.white38,
                      ),
                      tooltip: "Search Web",
                      visualDensity: VisualDensity.compact,
                      // Removes extra padding
                      onPressed: () {
                        final query = Uri.encodeComponent(
                          "${widget.medicineName} ${widget.title}",
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
                    ),
                    const SizedBox(width: 2),

                    // Arrow Icon
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: _expanded ? 0.5 : 0,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _expanded
                            ? UIConstants.accentGreen
                            : Colors.white38,
                        size: 22,
                      ),
                    ),
                  ],
                ),

                // 🔹 Collapsible body
                SizeTransition(
                  sizeFactor: _expandAnimation,
                  axisAlignment: -1.0,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    // ✨ Less gap than before
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...widget.content.asMap().entries.map((entry) {
                          final point = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(bottom: 6.h),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ✨ Custom Bullet Dot instead of Text "•"
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 7,
                                    right: 10,
                                  ),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: UIConstants.accentGreen.withValues(
                                        alpha: 0.8,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.75,
                                      ),
                                      fontSize: 15.sp,
                                      height: 1.5, // Good readability
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
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
