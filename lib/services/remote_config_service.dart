import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final _remoteConfig = FirebaseRemoteConfig.instance;

  static Future<void> init() async {
    // await _remoteConfig.setDefaults({'token_product_ids': ''});
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ),
    );
    await _remoteConfig.fetchAndActivate();
  }

  static Set<String> getTokenProductIds() {
    final raw = _remoteConfig.getString('token_product_ids');
    if (raw.isEmpty) return {};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }
}
