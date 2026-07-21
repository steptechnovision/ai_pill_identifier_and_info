# AI Pill Identifier & Info

Flutter app with Firebase backend. Package: `com.steptechnovision.aipillidentifier`

---

## Projects on this machine

| Project | Path |
|---|---|
| AI Medicine Tracker (this project) | `C:\Users\rajka\ai_medicine_tracker` |
| HD Camera | `C:\Users\rajka\hd_camera` |

Firebase project ID: `appprojects-ce9c6`

---

## Tech Stack

- **Flutter** (Dart) — mobile app
- **Firebase Cloud Functions** (TypeScript) — backend AI calls
- **OpenAI API** — GPT-4o-mini for medicine info, GPT-4o for camera scan
- **Firebase App Check** — blocks unauthorized callers
- **Google Play In-App Purchase** — monthly & annual Pro subscriptions
- **AdMob** — banner, interstitial, native, app-open ads

---

## OpenAI API Key

The key is **never in the app or code**. It lives in Firebase Secret Manager.

### Update / rotate the key

1. Create a new key at https://platform.openai.com/api-keys
2. Run from `C:\Users\rajka\ai_medicine_tracker\functions\`:
   ```powershell
   firebase functions:secrets:set OPENAI_API_KEY
   ```
   Paste the new key when prompted → press Enter → choose **Yes** to redeploy.

> **Note:** Use `firebase functions:secrets:set` (not `firebase secrets:set` — that command does not exist in this CLI version).

### Check billing

https://platform.openai.com/settings/organization/billing/overview
Auto-recharge is ON: recharges to $50 when balance hits $5.

---

## Firebase App Check

Blocks any caller that is not your signed app.

| Mode | Android | iOS |
|---|---|---|
| Debug | `AndroidDebugProvider(debugToken: 'b48b0120-e52b-4fed-a2f0-80e3e4263e1c')` | `AppleDebugProvider()` |
| Release | `AndroidPlayIntegrityProvider()` | `AppleAppAttestProvider()` |

**Registered debug token:** `b48b0120-e52b-4fed-a2f0-80e3e4263e1c`
(Registered in Firebase Console → App Check → Apps → Manage debug tokens)

### If App Check fails (403 App attestation failed)

- Debug build: make sure the `debugToken` in `lib/main.dart` matches the one registered in Firebase Console above.
- Release build side-loaded (not from Play Store): Play Integrity will fail — only works for builds downloaded from Play Store.

---

## Subscriptions (Google Play)

| Plan | Product ID | Price |
|---|---|---|
| Monthly | `ai_pill_pro_monthly` | ₹399/month |
| Annual | `ai_pill_pro_annual` | ₹2,900/year |

Prices are read live from Play Store (`ProductDetails.rawPrice`). Changing the price in Play Console automatically reflects in the paywall — **no app release needed**.

Fallback prices (shown only if Play Store is unreachable) are in `lib/helper/constant.dart`:
```dart
static const String subMonthlyFallbackPrice = '₹399/month';
static const String subAnnualFallbackPrice  = '₹2,900/year';
```

---

## Free vs Pro Limits

All limits and token costs are in `lib/helper/constant.dart`. Change there — everything else updates automatically.

| Feature | Free | Pro |
|---|---|---|
| Medicine search | 1/day | 20/day |
| Drug interactions | 0 (tokens only) | 15/day |
| Cannabis interactions | 0 (tokens only) | 10/day |
| Family members | 2 | 20 |

### Token costs (free users)

| Feature | Tokens |
|---|---|
| Medicine search | 1 |
| Drug interactions | 3 |
| Cannabis interactions | 2 |
| Camera scan | 5 |
| Missed dose advice | 1 |

Pro subscribers receive **30 tokens** on the 1st of each calendar month.

---

## Notification Icon

Custom monochrome pill icon: `android/app/src/main/res/drawable/ic_notification.xml`

Referenced in `lib/services/reminder_service.dart` as `'ic_notification'`.

> Android 5.0+ requires notification icons to be white-on-transparent. Full-color icons appear as grey blobs — always use a monochrome vector drawable.

---

## Deploying Functions

From `C:\Users\rajka\ai_medicine_tracker\functions\`:

```powershell
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:searchMedicine

# Deploy Firestore rules + functions
firebase deploy --only firestore:rules,functions
```

---

## AdMob IDs

Debug uses Google test IDs automatically. Release IDs are in `lib/helper/constant.dart`.

| Ad type | Release unit ID |
|---|---|
| Banner | `ca-app-pub-5003311732017255/1779408142` |
| Interstitial | `ca-app-pub-5003311732017255/3726914635` |
| Native | `ca-app-pub-5003311732017255/9652204909` |
| App Open | `ca-app-pub-5003311732017255/2667544446` |

Interstitial shows every **4 new searches** (configurable via `Constants.interstitialCadence`).

---

## SHA-256 Fingerprint

Required for Firebase App Check (Play Integrity) and Google Sign-In.
Add in: Firebase Console → Project Settings → Your apps → Android app → Add fingerprint.

To get the release fingerprint:
```powershell
keytool -list -v -keystore "path\to\your.keystore" -alias your_alias
```

---

## Useful Commands

```powershell
# Run app in debug
flutter run

# Build release APK
flutter build apk --release

# Build release AAB (for Play Store)
flutter build appbundle --release

# Analyze code
flutter analyze

# Update dependencies
flutter pub upgrade
```
