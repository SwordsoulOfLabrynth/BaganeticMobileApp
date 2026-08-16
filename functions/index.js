const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {defineSecret} = require("firebase-functions/params");

const nvidiaApiKey = defineSecret("NVIDIA_API_KEY");
const endpoint = "https://integrate.api.nvidia.com/v1/chat/completions";
const defaultModel = "meta/llama-3.1-8b-instruct";
const maxPromptLength = 2000;
const maxHistoryMessages = 12;

function asText(value, maxLength = 4000) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function safeHistory(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(-maxHistoryMessages).flatMap((entry) => {
    const text = asText(entry?.text, 1500);
    if (!text) return [];
    return [{
      role: entry.role === "assistant" ? "assistant" : "user",
      content: text,
    }];
  });
}

function buildSystemPrompt(context) {
  const pagodas = Array.isArray(context?.pagodas) ? context.pagodas.slice(0, 8) : [];
  const trip = context?.trip;
  const communityPosts = Array.isArray(context?.communityPosts)
    ? context.communityPosts.slice(0, 6)
    : [];

  const pagodaText = pagodas.map((pagoda) => {
    const name = asText(pagoda?.name, 120);
    const category = asText(pagoda?.category, 60);
    const summary = asText(pagoda?.summary, 300);
    return name ? `- ${name}${category ? ` (${category})` : ""}: ${summary}` : "";
  }).filter(Boolean).join("\n") || "- No pagoda context supplied.";

  const tripText = trip && asText(trip.name, 120)
    ? `- ${asText(trip.name, 120)}`
    : "- No trip context supplied.";
  const communityText = communityPosts.map((post) => {
    const title = asText(post?.title, 160);
    const body = asText(post?.body, 250);
    return title ? `- ${title}: ${body}` : "";
  }).filter(Boolean).join("\n") || "- No relevant community posts supplied.";

  return [
    "You are Baganetic's in-app travel assistant for Bagan pagodas.",
    "Stay inside the Bagan travel domain and answer concisely in English.",
    "Do not invent facts. Treat community posts as unverified traveler reports.",
    "Pagoda context:", pagodaText,
    "Trip context:", tripText,
    "Community context:", communityText,
  ].join("\n");
}

exports.generateAiReply = onCall(
  {region: "asia-southeast1", secrets: [nvidiaApiKey], timeoutSeconds: 60},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in is required to use the AI assistant.");
    }

    const prompt = asText(request.data?.prompt, maxPromptLength);
    if (!prompt) {
      throw new HttpsError("invalid-argument", "A non-empty prompt is required.");
    }

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${nvidiaApiKey.value()}`,
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: defaultModel,
        temperature: 0.2,
        top_p: 0.9,
        max_tokens: 700,
        messages: [
          {role: "system", content: buildSystemPrompt(request.data?.context)},
          ...safeHistory(request.data?.history),
          {role: "user", content: prompt},
        ],
      }),
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      logger.warn("NVIDIA request failed", {status: response.status});
      throw new HttpsError("internal", "The AI service is unavailable. Please try again later.");
    }

    const reply = asText(data?.choices?.[0]?.message?.content, 6000);
    if (!reply) {
      throw new HttpsError("internal", "The AI service returned no reply.");
    }

    return {
      reply,
      createdAt: new Date().toISOString(),
      contextSummary: {
        pagodaCount: Array.isArray(request.data?.context?.pagodas)
          ? Math.min(request.data.context.pagodas.length, 8)
          : 0,
        tripCount: request.data?.context?.trip ? 1 : 0,
        communityPostCount: Array.isArray(request.data?.context?.communityPosts)
          ? Math.min(request.data.context.communityPosts.length, 6)
          : 0,
      },
    };
  },
);
