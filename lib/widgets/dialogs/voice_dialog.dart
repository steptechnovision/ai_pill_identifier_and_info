import 'package:ai_medicine_tracker/helper/app_colors.dart';
import 'package:ai_medicine_tracker/helper/constant.dart';
import 'package:ai_medicine_tracker/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class VoiceDialog extends StatelessWidget {
  final bool isListening;
  final bool hasError;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const VoiceDialog({
    super.key,
    required this.isListening,
    required this.hasError,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: Constants.screenHorizontalPadding,
        right: Constants.screenHorizontalPadding,
        top: 24.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      decoration: const BoxDecoration(
        // color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close, size: 30.r, color: Colors.white),
            ),
          ),
          SizedBox(height: 16.h),
          AppText(
            isListening
                ? "Listening..."
                : hasError
                ? "Sorry! Didn’t hear that"
                : "Tap the microphone to start",
            fontSize: 19.sp,
            fontWeight: FontWeight.w500,
            textAlign: TextAlign.center,
            color: Colors.white,
          ),
          if (hasError) ...[
            SizedBox(height: 6.h),
            AppText(
              "Try saying something\nTap the microphone to try again",
              textAlign: TextAlign.center,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ],
          const SizedBox(height: 24),
          PulseMicButton(isListening: isListening, onTap: onRetry),
          const SizedBox(height: 24),
          if (hasError) ...[
            AppText(
              "Tap the microphone to try again",
              textAlign: TextAlign.center,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            SizedBox(height: 4.h),
          ],
        ],
      ),
    );
  }
}

class PulseMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;

  const PulseMicButton({
    super.key,
    required this.isListening,
    required this.onTap,
  });

  @override
  State<PulseMicButton> createState() => _PulseMicButtonState();
}

class _PulseMicButtonState extends State<PulseMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.isListening ? _scaleAnimation : AlwaysStoppedAnimation(1.0),
      child: GestureDetector(
        onTap: widget.onTap,
        child: CircleAvatar(
          radius: 38.r,
          backgroundColor: AppColors.appPrimaryRedColor,
          child: Icon(Icons.mic, color: Colors.white, size: 36.r),
        ),
      ),
    );
  }
}
