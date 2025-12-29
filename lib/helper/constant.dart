import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Constants {
  static String openAiApi = dotenv.env['OPEN_AI_API'] ?? '';
  static String openAiAuthorizationKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String openAiModel = 'gpt-4o-mini';
  static const String packageName = 'com.steptechnovision.aipillidentifier';
  static const String appName = 'AI Pill Identifier & Info';
  static double screenHorizontalPadding = 16.w;
  static const String privacyPolicyUrl = 'https://steptechnovision.blogspot.com/2025/12/privacy-policy-for-ai-pill-identifier.html';
  static const String termsAndConditionUrl = 'https://steptechnovision.blogspot.com/2025/11/terms-conditions-ai-pill-identifier-info.html';
  static const String emailAddress = 'steptechnovision@gmail.com';
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
  static const String appStoreId = '';

  static Map<String, dynamic> getOpenAiRequestData(String medicineName) {
    return {
      "model": Constants.openAiModel,
      "messages": [
        {
          "role": "system",
          "content": """
You are a precise medical assistant. 
Your response must be ONLY valid JSON with these exact keys:
["Pros", "Cons", "Benefits", "Usage", "WhoCanTake", "SideEffects", "Precautions", "ExtraInformation", "Dosage", "Interactions", "Storage", "Warnings", "FAQs"].

⚠️ Rules:
- Always include ALL keys, even if empty (use an empty array).
- Each value must be an array of strings.
- Each string should be a detailed explanation (1–3 sentences).
- Never return plain text, markdown, or extra commentary — ONLY JSON.
- Ensure information is concise, accurate, and safe for general informational purposes.
""",
        },
        {
          "role": "user",
          "content": "Provide detailed structured medical information about \"$medicineName\".",
        },
      ],
      "response_format": {"type": "json_object"},
    };
  }

//   static Object getOpenAiRequestData(String medicineName) {
//     return {
//       "model": Constants.openAiModel,
//       "messages": [
//         {
//           "role": "system",
//           "content": """
// You are a medical assistant. Always return JSON with the following keys:
// Pros, Cons, Benefits, Usage, WhoCanTake, SideEffects, Precautions, ExtraInformation.
//
// Each value must be an array of strings.
// Each string should be a detailed explanation, not just a short phrase.
// Do not return plain text, always return valid JSON.
// """,
//         },
//         {
//           "role": "user",
//           "content": "Give me detailed medical information about $medicineName.",
//         },
//       ],
//       "response_format": {"type": "json_object"},
//     };
//   }
}
