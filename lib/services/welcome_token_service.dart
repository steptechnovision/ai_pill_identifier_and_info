import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../helper/constant.dart';
import '../helper/prefs.dart';

class WelcomeTokenService {
  // Called once at startup. Silently skipped if already checked or on failure.
  // On success (granted or not), marks locally so we never call the server again.
  static Future<void> grant() async {
    if (Prefs.isWelcomeTokensChecked()) return;
    if (!Platform.isAndroid) return; // iOS not in use yet

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final deviceId = androidInfo.id;

      final callable =
          FirebaseFunctions.instance.httpsCallable('grantWelcomeTokens');
      final result = await callable.call({'deviceId': deviceId});
      final data = result.data as Map<dynamic, dynamic>;

      if (data['granted'] == true) {
        await Prefs.addTokens(Constants.welcomeTokens);
      }

      // Mark checked only after a successful server response
      // (not on exception, so retry is possible if offline at first launch)
      await Prefs.setWelcomeTokensChecked();
    } catch (_) {
      // Network down or function not deployed yet — retry next launch
    }
  }
}
