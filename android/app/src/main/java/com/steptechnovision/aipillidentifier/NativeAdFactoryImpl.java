package com.steptechnovision.aipillidentifier;

import android.view.LayoutInflater;
import android.widget.ImageView;
import android.widget.TextView;

import com.google.android.gms.ads.nativead.NativeAd;
import com.google.android.gms.ads.nativead.NativeAdView;

import java.util.Map;

import io.flutter.plugins.googlemobileads.NativeAdFactory;

public class NativeAdFactoryImpl implements NativeAdFactory {

    private final LayoutInflater layoutInflater;

    NativeAdFactoryImpl(LayoutInflater layoutInflater) {
        this.layoutInflater = layoutInflater;
    }

    @Override
    public NativeAdView createNativeAd(NativeAd nativeAd, Map<String, Object> customOptions) {
        NativeAdView adView = (NativeAdView) layoutInflater.inflate(R.layout.native_ad_layout, null);

        // Headline
        TextView headlineView = adView.findViewById(R.id.ad_headline);
        headlineView.setText(nativeAd.getHeadline());
        adView.setHeadlineView(headlineView);

        // Body
        TextView bodyView = adView.findViewById(R.id.ad_body);
        if (nativeAd.getBody() != null) {
            bodyView.setText(nativeAd.getBody());
        } else {
            bodyView.setText("");
        }
        adView.setBodyView(bodyView);

        // Advertiser
        TextView advertiserView = adView.findViewById(R.id.ad_advertiser);
        if (nativeAd.getAdvertiser() != null) {
            advertiserView.setText(nativeAd.getAdvertiser());
        }

        // Icon
        ImageView iconView = adView.findViewById(R.id.ad_icon);
        if (nativeAd.getIcon() != null) {
            iconView.setImageDrawable(nativeAd.getIcon().getDrawable());
        }
        adView.setIconView(iconView);

        // Call to action
        TextView callToActionView = adView.findViewById(R.id.ad_call_to_action);
        if (nativeAd.getCallToAction() != null) {
            callToActionView.setText(nativeAd.getCallToAction());
        } else {
            callToActionView.setText("Learn More");
        }
        adView.setCallToActionView(callToActionView);

        adView.setNativeAd(nativeAd);
        return adView;
    }
}
