import 'dart:developer' as developer;

import 'package:flutter/material.dart';

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
}
