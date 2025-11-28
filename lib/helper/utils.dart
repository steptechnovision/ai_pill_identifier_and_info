import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

printLog(dynamic data, {bool printLog = false}) {
  if (printLog) {
    developer.log('$data');
  } else {
    print('$data');
  }
}

class Utils {
  static void runAfterCurrentSuccess(VoidCallback onSuccess) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSuccess();
    });
  }

  /// **Top-positioned** toast style message + haptic feedback 🚀
  static void showToast(
    BuildContext context, {
    required String message,
    Color? backgroundColor = Colors.black87,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Haptic vibration
    HapticFeedback.mediumImpact();

    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(snackBar);
  }

  /// 🔹 Special green toast — cache hit = no token used
  static void showNoTokenUsed(BuildContext context) {
    showToast(
      context,
      message: "No token used! ✔ You already searched this",
      backgroundColor: Colors.green,
    );
  }

  /// 🔹 Token deducted
  static void showTokenUsed(BuildContext context) {
    showToast(
      context,
      message: "Token used ✔ AI result unlocked",
      backgroundColor: Colors.blueAccent,
    );
  }

  /// 🔹 Token deducted
  static void showErrorMessage(BuildContext context) {
    showToast(
      context,
      message: "No matching medicine found.",
      backgroundColor: Colors.redAccent,
    );
  }

  static void showMessage(
    BuildContext context,
    String msg, {
    bool success = false,
    bool isError = false,
  }) {
    final Color? color = success
        ? Colors.greenAccent[700]
        : (isError ? Colors.redAccent : Colors.blueAccent);
    showToast(context, message: msg, backgroundColor: color);
    // ScaffoldMessenger.of(
    //   context,
    // ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ---------------------------------------------------------------------------
  // 1. PREMIUM LOADING (Context-Free!)
  // ---------------------------------------------------------------------------
  static void showLoading({String message = "Loading..."}) {
    SmartDialog.showLoading(
      maskColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => Container(
        padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 24.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Colors.greenAccent,
              strokeWidth: 3,
            ),
            20.verticalSpace,
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> hideLoading() async {
    await SmartDialog.dismiss();
  }

  // ---------------------------------------------------------------------------
  // 2. INTERNET CHECK (With Smart Dialog)
  // ---------------------------------------------------------------------------
  static Future<bool> checkInternetWithLoading() async {
    showLoading(message: "Loading...");

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 12));

      final hasNet = result.isNotEmpty && result.first.rawAddress.isNotEmpty;

      await hideLoading();
      return hasNet;
    } catch (_) {
      await hideLoading();
      return false;
    }
  }
}
