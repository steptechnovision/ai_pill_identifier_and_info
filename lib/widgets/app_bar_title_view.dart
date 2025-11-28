import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppBarTitleView extends StatelessWidget {
  final String title;

  const AppBarTitleView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppText(
      title,
      fontWeight: FontWeight.bold,
      fontSize: (16.5).sp,
      maxLines: 2,
    );
  }
}
