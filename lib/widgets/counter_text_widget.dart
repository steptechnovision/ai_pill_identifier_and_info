import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CounterTextWidget extends StatelessWidget {
  final TextEditingController? controller;
  final int? maxLength;
  final bool isDummy;

  const CounterTextWidget({
    super.key,
    this.controller,
    this.maxLength,
    this.isDummy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h, right: 12.w),
      child: Align(
        alignment: Alignment.centerRight,
        child: isDummy
            ? _textView(0)
            : ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller!,
                builder: (context, value, child) {
                  return _textView(value.text.length);
                },
              ),
      ),
    );
  }

  Widget _textView(int currentLength) {
    return AppText(
      isDummy ? '' : '$currentLength / $maxLength',
      fontSize: 11.sp,
      color: isDummy
          ? Colors.transparent
          : currentLength > maxLength!
          ? Colors.redAccent
          : Colors.white70, // 🌙 use light text color
      letterSpacing: 0.05,
    );
  }
}
