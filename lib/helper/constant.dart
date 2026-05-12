import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Constants {
  // ── OpenAI ────────────────────────────────────────────
  static String openAiApi = dotenv.env['OPEN_AI_API'] ?? '';
  static String openAiAuthorizationKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String openAiModel = 'gpt-4o-mini';
  static const String openAiVisionModel = 'gpt-4o'; // for camera pill ID

  // ── App ───────────────────────────────────────────────
  static const String packageName = 'com.steptechnovision.aipillidentifier';
  static const String appName = 'AI Pill Identifier & Info';
  static double screenHorizontalPadding = 16.w;
  static const String privacyPolicyUrl =
      'https://steptechnovision.blogspot.com/2025/12/privacy-policy-for-ai-pill-identifier.html';
  static const String termsAndConditionUrl =
      'https://steptechnovision.blogspot.com/2025/11/terms-conditions-ai-pill-identifier-info.html';
  static const String emailAddress = 'steptechnovision@gmail.com';
  static const String appStoreId = '';

  // ── Daily limits (free / Pro) ────────────────────────
  static const int freeDailySearchLimit = 3;
  static const int freeDailyInteractionLimit = 2;
  static const int proDailySearchLimit = 30;
  static const int proDailyInteractionLimit = 20;
  static const int freeFamilyMembersLimit = 2;
  static const int proFamilyMembersLimit = 20;

  // ── Pro monthly token bundle ──────────────────────────
  static const int proMonthlyTokens = 30; // granted once per calendar month

  // ── Subscription product IDs ─────────────────────────
  // Create these in Google Play Console → Monetize → Subscriptions
  static const String subMonthlyId = 'ai_pill_pro_monthly';
  static const String subAnnualId = 'ai_pill_pro_annual';
  static const Set<String> subscriptionIds = {subMonthlyId, subAnnualId};

  // ── Subscription fallback prices (shown when Play Store unavailable) ────
  static const String subMonthlyFallbackPrice = '₹199/month';
  static const String subAnnualFallbackPrice = '₹1,199/year';

  // ── AdMob IDs (test in debug, real in release) ────────
  static String get admobBannerAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-5003311732017255/1779408142';
  static String get admobInterstitialAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-5003311732017255/3726914635';
  static String get admobNativeAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/2247696110'
      : 'ca-app-pub-5003311732017255/9652204909';
  static String get admobAppOpenAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/9257395921'
      : 'ca-app-pub-5003311732017255/2667544446';

  // Show interstitial every N new searches
  static const int interstitialCadence = 4;

  // ── Share text ────────────────────────────────────────
  static String get shareText {
    const baseMessage =
        "💊 Stop guessing about your medicines!\n\n"
        "I use $appName to get instant, detailed AI insights on side effects, dosage, and usage.\n\n"
        "Get it here 👇\n";

    if (Platform.isAndroid) {
      return "$baseMessage"
          "https://play.google.com/store/apps/details?id=${Constants.packageName}";
    } else {
      return "$baseMessage"
          "https://apps.apple.com/app/id${Constants.appStoreId}";
    }
  }

  // ── OpenAI: medicine info prompt ─────────────────────
  static Map<String, dynamic> getOpenAiRequestData(String medicineName,
      {String language = 'en', String? genericName}) {
    final langInstruction = language == 'en'
        ? ''
        : '\n- Language: Respond in the language with ISO 639-1 code "$language". Keep ALL medicine names, chemical/scientific terms, drug names, and numeric dosages in English. Translate only the explanatory sentences.';
    final brandInstruction = genericName != null
        ? '"$medicineName" is an Indian brand name for $genericName. Use "$medicineName ($genericName)" as the medicine name throughout your response.'
        : '"$medicineName"';
    return {
      "model": openAiModel,
      "messages": [
        {
          "role": "system",
          "content": """
You are a senior clinical pharmacist and medical information expert.
Your response must be ONLY valid JSON with these exact keys:
["Pros", "Cons", "Benefits", "Usage", "WhoCanTake", "SideEffects", "Precautions", "ExtraInformation", "Dosage", "Interactions", "Storage", "Warnings", "FAQs"].

⚠️ Rules:
- Always include ALL keys.
- Each value must be an array of 5 to 7 detailed strings — never fewer than 5.
- Each string must be a complete, informative sentence of 1–3 sentences with real medical value.
- Make every point genuinely useful — cover timing, food interactions, contraindications, age groups, etc.
- "FAQs" format: "Q: ... A: ..." in each string.
- "WhoCanTake": cover adults, elderly, children, pregnancy, renal/hepatic conditions.
- "Dosage": include standard adult dose, timing, frequency, maximum daily dose, form.
- Never return markdown, code fences, or text outside the JSON — ONLY valid JSON.$langInstruction
""",
        },
        {
          "role": "user",
          "content":
              "Provide comprehensive, detailed medical information about $brandInstruction with at least 5 informative points per section.",
        },
      ],
      "response_format": {"type": "json_object"},
    };
  }

  // ── OpenAI: cannabis/CBD interaction prompt ──────────
  static Map<String, dynamic> getCannabisInteractionRequest(String medicine) {
    return {
      "model": openAiModel,
      "messages": [
        {
          "role": "system",
          "content": """
You are a clinical pharmacist specialising in cannabis and CBD drug interactions.
Return ONLY valid JSON with this exact structure:
{
  "risk_level": "None|Minor|Moderate|Major",
  "thc_interactions": ["string — specific interaction with THC/Cannabis (1-2 sentences each)", ...],
  "cbd_interactions": ["string — specific interaction with CBD/Cannabidiol (1-2 sentences each)", ...],
  "mechanism": ["string — how the interaction works pharmacologically (1-2 sentences each)", ...],
  "recommendations": ["string — what the patient should do (1-2 sentences each)", ...],
  "summary": "string — plain English overall summary (2-3 sentences)"
}
Rules:
- Each array must have 3 to 5 entries.
- Use plain, patient-friendly language — avoid excessive jargon.
- If no significant interaction is known, set risk_level to "None" and explain why it is considered safe.
- Always include ALL keys. Never return markdown or text outside the JSON.
""",
        },
        {
          "role": "user",
          "content":
              "What are the interactions between \"$medicine\" and Cannabis (THC) or CBD (Cannabidiol)?",
        },
      ],
      "response_format": {"type": "json_object"},
    };
  }

  // ── OpenAI: camera pill identification (Vision) ──────
  static Map<String, dynamic> getCameraScanRequest(String base64Image) {
    return {
      "model": openAiVisionModel,
      "messages": [
        {
          "role": "system",
          "content": """
You are a senior clinical pharmacist and medical expert specialising in pill identification.
Given an image of a pill, tablet, capsule, or medicine packaging, identify it and return ONLY valid JSON.

The JSON must have these exact keys:
"medicineName" (string), "Pros" (array), "Cons" (array), "Benefits" (array), "Usage" (array),
"WhoCanTake" (array), "SideEffects" (array), "Precautions" (array), "ExtraInformation" (array),
"Dosage" (array), "Interactions" (array), "Storage" (array), "Warnings" (array), "FAQs" (array).

Rules:
- If the pill cannot be identified, set "medicineName" to "Unknown" and all arrays to [].
- Each array MUST contain 5 to 7 detailed, informative strings — never fewer than 5.
- Each string must be a complete, useful sentence of 1–3 sentences with clear medical information.
- Make every point genuinely helpful and detailed — users rely on this information.
- Cover dosage forms, timing, age restrictions, food interactions, contraindications, etc.
- "FAQs" should be formatted as "Q: ... A: ..." in each string.
- "WhoCanTake" should cover adults, elderly, children, pregnant women, specific conditions.
- Never return markdown, code fences, or any text outside the JSON — ONLY valid JSON.
""",
        },
        {
          "role": "user",
          "content": [
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,$base64Image",
                "detail": "high",
              },
            },
            {
              "type": "text",
              "text":
                  "Identify this pill or medicine from the image. Provide comprehensive, detailed medical information with at least 5 points in every section.",
            },
          ],
        },
      ],
      "response_format": {"type": "json_object"},
      "max_tokens": 4000,
    };
  }

  // ── OpenAI: missed dose advice ────────────────────────
  static Map<String, dynamic> getMissedDoseRequest(String medicine) {
    return {
      "model": openAiModel,
      "messages": [
        {
          "role": "system",
          "content": """
You are a clinical pharmacist giving safe, practical guidance.
Return ONLY valid JSON with these exact keys:
{
  "general_advice": "string — what to do in most cases (2-3 sentences)",
  "do_not": "string — what NOT to do (1-2 sentences)",
  "when_to_seek_help": "string — warning signs that need a doctor (1 sentence)",
  "reminder_tip": "string — a practical tip to avoid missing future doses (1 sentence)"
}
Keep language simple, patient-friendly. Never say 'double dose is safe' — always err on the side of caution.
""",
        },
        {
          "role": "user",
          "content":
              "What should I do if I missed a dose of \"$medicine\"?",
        },
      ],
      "response_format": {"type": "json_object"},
    };
  }

  // ── OpenAI: drug interaction prompt ──────────────────
  static Map<String, dynamic> getInteractionRequestData(
    List<String> medicines, {
    bool includeSupplements = false,
  }) {
    final list = medicines.join(', ');
    return {
      "model": openAiModel,
      "messages": [
        {
          "role": "system",
          "content": """
You are a clinical pharmacist. Analyze drug interactions for the given list of medications.
Return ONLY valid JSON with this exact structure:
{
  "interactions": [
    {
      "drug1": "string",
      "drug2": "string",
      "severity": "Major|Moderate|Minor",
      "description": "string — plain English, what happens when these drugs interact (1-2 sentences)",
      "action": "string — what the user should do (1-2 sentences)"
    }
  ],
  "overall_risk": "High|Medium|Low|None",
  "summary": "string — overall plain English summary (1-2 sentences)"
}
Rules:
- Check ALL pairs of drugs for interactions.
- Only include clinically significant interactions.
- Use plain English that patients can understand — no jargon.
- If no significant interactions, return interactions as [].
- Always include ALL keys.
""",
        },
        {
          "role": "user",
          "content": includeSupplements
              ? "Check drug interactions for these medications (also consider supplements, vitamins, and herbal remedies): $list"
              : "Check drug interactions for these medications: $list",
        },
      ],
      "response_format": {"type": "json_object"},
    };
  }
}
