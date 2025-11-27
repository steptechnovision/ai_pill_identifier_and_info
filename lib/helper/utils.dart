import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
}
