package com.steptechnovision.aipillidentifier;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin;

public class MainActivity extends FlutterActivity {

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine,
                "listTile",
                new NativeAdFactoryImpl(getLayoutInflater())
        );
    }

    @Override
    public void cleanUpFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile");
        super.cleanUpFlutterEngine(flutterEngine);
    }
}
