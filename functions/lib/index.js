"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getMissedDoseAdvice = exports.grantWelcomeTokens = exports.scanPill = exports.checkCannabisInteractions = exports.checkDrugInteractions = exports.searchMedicine = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const openai_1 = require("openai");
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
(0, app_1.initializeApp)();
// ── Secret (stored in Firebase Secret Manager, never in code or APK) ─────────
const openAiKey = (0, params_1.defineSecret)("OPENAI_API_KEY");
// ── Models ────────────────────────────────────────────────────────────────────
const GPT_MINI = "gpt-4o-mini";
const GPT_VISION = "gpt-4o";
// ── Helpers ───────────────────────────────────────────────────────────────────
function client() {
    return new openai_1.default({ apiKey: openAiKey.value() });
}
function requireString(value, field, maxLen = 200) {
    if (typeof value !== "string" || value.trim().length === 0) {
        throw new https_1.HttpsError("invalid-argument", `${field} must be a non-empty string`);
    }
    if (value.length > maxLen) {
        throw new https_1.HttpsError("invalid-argument", `${field} is too long (max ${maxLen} chars)`);
    }
    return value.trim();
}
function parseJsonResponse(content) {
    if (!content)
        throw new https_1.HttpsError("internal", "Empty response from AI");
    const clean = content.replace(/```json/g, "").replace(/```/g, "").trim();
    try {
        return JSON.parse(clean);
    }
    catch (_a) {
        throw new https_1.HttpsError("internal", "AI returned malformed JSON");
    }
}
// Common callable options — App Check enforced on every function
const callableOpts = { enforceAppCheck: true, secrets: [openAiKey] };
// ── 1. Search Medicine ────────────────────────────────────────────────────────
exports.searchMedicine = (0, https_1.onCall)(Object.assign(Object.assign({}, callableOpts), { timeoutSeconds: 60 }), async (request) => {
    const medicineName = requireString(request.data.medicineName, "medicineName");
    const language = typeof request.data.language === "string" ? request.data.language.slice(0, 10) : "en";
    const genericName = request.data.genericName != null
        ? requireString(request.data.genericName, "genericName", 150)
        : null;
    const langInstruction = language === "en"
        ? ""
        : `\n- Language: Respond in the language with ISO 639-1 code "${language}". Keep ALL medicine names, chemical/scientific terms, drug names, and numeric dosages in English. Translate only the explanatory sentences.`;
    const brandInstruction = genericName
        ? `"${medicineName}" is an Indian brand name for ${genericName}. Use "${medicineName} (${genericName})" as the medicine name throughout your response.`
        : `"${medicineName}"`;
    const response = await client().chat.completions.create({
        model: GPT_MINI,
        response_format: { type: "json_object" },
        messages: [
            {
                role: "system",
                content: `You are a senior clinical pharmacist and medical information expert.
Your response must be ONLY valid JSON with these exact keys:
["Pros","Cons","Benefits","Usage","WhoCanTake","SideEffects","Precautions","ExtraInformation","Dosage","Interactions","Storage","Warnings","FAQs"].

⚠️ Rules:
- Always include ALL keys.
- Each value must be an array of 5 to 7 detailed strings — never fewer than 5.
- Each string must be a complete, informative sentence of 1–3 sentences with real medical value.
- Make every point genuinely useful — cover timing, food interactions, contraindications, age groups, etc.
- "FAQs" format: "Q: ... A: ..." in each string.
- "WhoCanTake": cover adults, elderly, children, pregnancy, renal/hepatic conditions.
- "Dosage": include standard adult dose, timing, frequency, maximum daily dose, form.
- Never return markdown, code fences, or text outside the JSON — ONLY valid JSON.${langInstruction}`,
            },
            {
                role: "user",
                content: `Provide comprehensive, detailed medical information about ${brandInstruction} with at least 5 informative points per section.`,
            },
        ],
    });
    return parseJsonResponse(response.choices[0].message.content);
});
// ── 2. Drug–Drug Interactions ─────────────────────────────────────────────────
exports.checkDrugInteractions = (0, https_1.onCall)(Object.assign(Object.assign({}, callableOpts), { timeoutSeconds: 60 }), async (request) => {
    const raw = request.data.medicines;
    if (!Array.isArray(raw) || raw.length < 2 || raw.length > 10) {
        throw new https_1.HttpsError("invalid-argument", "medicines must be an array of 2–10 items");
    }
    const medicines = raw.map((m, i) => requireString(m, `medicine[${i}]`, 100));
    const includeSupplements = request.data.includeSupplements === true;
    const list = medicines.join(", ");
    const response = await client().chat.completions.create({
        model: GPT_MINI,
        response_format: { type: "json_object" },
        messages: [
            {
                role: "system",
                content: `You are a clinical pharmacist. Analyze drug interactions for the given list of medications.
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
- Always include ALL keys. Never return markdown or text outside the JSON.`,
            },
            {
                role: "user",
                content: includeSupplements
                    ? `Check drug interactions for these medications (also consider supplements, vitamins, and herbal remedies): ${list}`
                    : `Check drug interactions for these medications: ${list}`,
            },
        ],
    });
    return parseJsonResponse(response.choices[0].message.content);
});
// ── 3. Cannabis / CBD Interactions ────────────────────────────────────────────
exports.checkCannabisInteractions = (0, https_1.onCall)(Object.assign(Object.assign({}, callableOpts), { timeoutSeconds: 60 }), async (request) => {
    const medicine = requireString(request.data.medicine, "medicine");
    const response = await client().chat.completions.create({
        model: GPT_MINI,
        response_format: { type: "json_object" },
        messages: [
            {
                role: "system",
                content: `You are a clinical pharmacist specialising in cannabis and CBD drug interactions.
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
- Always include ALL keys. Never return markdown or text outside the JSON.`,
            },
            {
                role: "user",
                content: `What are the interactions between "${medicine}" and Cannabis (THC) or CBD (Cannabidiol)?`,
            },
        ],
    });
    return parseJsonResponse(response.choices[0].message.content);
});
// ── 4. Camera Scan — Pill Identification ─────────────────────────────────────
exports.scanPill = (0, https_1.onCall)(Object.assign(Object.assign({}, callableOpts), { timeoutSeconds: 90 }), async (request) => {
    const base64Image = request.data.base64Image;
    if (typeof base64Image !== "string" || base64Image.length === 0) {
        throw new https_1.HttpsError("invalid-argument", "base64Image is required");
    }
    // ~3 MB binary limit (base64 is ~4/3 the binary size)
    if (base64Image.length > 4000000) {
        throw new https_1.HttpsError("invalid-argument", "Image is too large. Please use a smaller photo.");
    }
    const response = await client().chat.completions.create({
        model: GPT_VISION,
        max_tokens: 4000,
        response_format: { type: "json_object" },
        messages: [
            {
                role: "system",
                content: `You are a senior clinical pharmacist and medical expert specialising in pill identification.
Given an image of a pill, tablet, capsule, or medicine packaging, identify it and return ONLY valid JSON.

The JSON must have these exact keys:
"medicineName" (string), "Pros" (array), "Cons" (array), "Benefits" (array), "Usage" (array),
"WhoCanTake" (array), "SideEffects" (array), "Precautions" (array), "ExtraInformation" (array),
"Dosage" (array), "Interactions" (array), "Storage" (array), "Warnings" (array), "FAQs" (array).

Rules:
- If the pill cannot be identified, set "medicineName" to "Unknown" and all arrays to [].
- Each array MUST contain 5 to 7 detailed, informative strings — never fewer than 5.
- Each string must be a complete, useful sentence of 1–3 sentences with clear medical information.
- "FAQs" should be formatted as "Q: ... A: ..." in each string.
- "WhoCanTake" should cover adults, elderly, children, pregnant women, specific conditions.
- Never return markdown, code fences, or any text outside the JSON — ONLY valid JSON.`,
            },
            {
                role: "user",
                content: [
                    {
                        type: "image_url",
                        image_url: {
                            url: `data:image/jpeg;base64,${base64Image}`,
                            detail: "high",
                        },
                    },
                    {
                        type: "text",
                        text: "Identify this pill or medicine from the image. Provide comprehensive, detailed medical information with at least 5 points in every section.",
                    },
                ],
            },
        ],
    });
    return parseJsonResponse(response.choices[0].message.content);
});
// ── 6. Grant Welcome Tokens (one-time per device, verified via Firestore) ────
exports.grantWelcomeTokens = (0, https_1.onCall)({ enforceAppCheck: true }, async (request) => {
    const deviceId = request.data.deviceId;
    if (typeof deviceId !== "string" || deviceId.trim().length === 0 || deviceId.length > 200) {
        throw new https_1.HttpsError("invalid-argument", "deviceId required");
    }
    const db = (0, firestore_1.getFirestore)();
    const docRef = db.collection("deviceTokens").doc(deviceId.trim());
    const doc = await docRef.get();
    if (doc.exists) {
        return { granted: false };
    }
    await docRef.set({ grantedAt: new Date().toISOString() });
    return { granted: true };
});
// ── 5. Missed Dose Advice ─────────────────────────────────────────────────────
exports.getMissedDoseAdvice = (0, https_1.onCall)(Object.assign(Object.assign({}, callableOpts), { timeoutSeconds: 30 }), async (request) => {
    const medicine = requireString(request.data.medicine, "medicine");
    const response = await client().chat.completions.create({
        model: GPT_MINI,
        response_format: { type: "json_object" },
        messages: [
            {
                role: "system",
                content: `You are a clinical pharmacist giving safe, practical guidance.
Return ONLY valid JSON with these exact keys:
{
  "general_advice": "string — what to do in most cases (2-3 sentences)",
  "do_not": "string — what NOT to do (1-2 sentences)",
  "when_to_seek_help": "string — warning signs that need a doctor (1 sentence)",
  "reminder_tip": "string — a practical tip to avoid missing future doses (1 sentence)"
}
Keep language simple, patient-friendly. Never say 'double dose is safe' — always err on the side of caution.`,
            },
            {
                role: "user",
                content: `What should I do if I missed a dose of "${medicine}"?`,
            },
        ],
    });
    return parseJsonResponse(response.choices[0].message.content);
});
//# sourceMappingURL=index.js.map