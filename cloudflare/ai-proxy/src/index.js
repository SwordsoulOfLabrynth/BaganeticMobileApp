import {createRemoteJWKSet, jwtVerify} from "jose";

const nvidiaEndpoint = "https://integrate.api.nvidia.com/v1/chat/completions";
const defaultModel = "meta/llama-3.1-8b-instruct";
const maxPromptLength = 2000;
const maxHistoryMessages = 12;
const maxRequestsPerMinute = 12;

const firebaseKeys = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

// This protects a single warm Worker isolate. Firebase authentication protects
// the endpoint itself; use a durable rate-limit binding before high-volume use.
const requestWindows = new Map();

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

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
  const communityPosts = Array.isArray(context?.communityPosts)
    ? context.communityPosts.slice(0, 6)
    : [];
  const pagodaText = pagodas.map((pagoda) => {
    const name = asText(pagoda?.name, 120);
    const category = asText(pagoda?.category, 60);
    const summary = asText(pagoda?.summary, 300);
    return name ? `- ${name}${category ? ` (${category})` : ""}: ${summary}` : "";
  }).filter(Boolean).join("\n") || "- No pagoda context supplied.";
  const tripText = context?.trip && asText(context.trip.name, 120)
    ? `- ${asText(context.trip.name, 120)}`
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

async function verifiedFirebaseUser(request, projectId) {
  const authorization = request.headers.get("authorization") || "";
  if (!authorization.startsWith("Bearer ")) {
    throw new Error("Authentication is required.");
  }
  const token = authorization.substring("Bearer ".length).trim();
  if (!token) throw new Error("Authentication is required.");

  try {
    const {payload} = await jwtVerify(token, firebaseKeys, {
      audience: projectId,
      issuer: `https://securetoken.google.com/${projectId}`,
    });
    if (!payload.sub) throw new Error("Authentication is required.");
    return String(payload.sub);
  } catch (_) {
    throw new Error("Your sign-in session has expired. Please sign in again.");
  }
}

function allowRequest(uid) {
  const now = Date.now();
  const existing = requestWindows.get(uid);
  const current = !existing || now - existing.startedAt >= 60_000
    ? {startedAt: now, count: 0}
    : existing;
  current.count += 1;
  requestWindows.set(uid, current);
  return current.count <= maxRequestsPerMinute;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return json({status: "ok"});
    }
    if (request.method !== "POST" || url.pathname !== "/v1/chat") {
      return json({error: "Not found."}, 404);
    }
    if (!env.NVIDIA_API_KEY) {
      return json({error: "AI proxy is not configured."}, 503);
    }

    let uid;
    try {
      uid = await verifiedFirebaseUser(request, env.FIREBASE_PROJECT_ID);
    } catch (error) {
      return json({error: error.message}, 401);
    }
    if (!allowRequest(uid)) {
      return json({error: "Too many AI requests. Please wait a minute and try again."}, 429);
    }

    let body;
    try {
      body = await request.json();
    } catch (_) {
      return json({error: "Invalid request body."}, 400);
    }
    const prompt = asText(body?.prompt, maxPromptLength);
    if (!prompt) return json({error: "Enter a question for the guide."}, 400);

    try {
      const response = await fetch(nvidiaEndpoint, {
        method: "POST",
        headers: {
          "authorization": `Bearer ${env.NVIDIA_API_KEY}`,
          "accept": "application/json",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model: defaultModel,
          temperature: 0.2,
          top_p: 0.9,
          max_tokens: 700,
          messages: [
            {role: "system", content: buildSystemPrompt(body?.context)},
            ...safeHistory(body?.history),
            {role: "user", content: prompt},
          ],
        }),
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) {
        console.warn("NVIDIA request failed", response.status);
        return json({error: "The AI service is temporarily unavailable. Please try again later."}, 503);
      }
      const reply = asText(result?.choices?.[0]?.message?.content, 6000);
      if (!reply) return json({error: "The AI service returned no reply."}, 503);
      return json({
        reply,
        createdAt: new Date().toISOString(),
        contextSummary: {
          pagodaCount: Array.isArray(body?.context?.pagodas)
            ? Math.min(body.context.pagodas.length, 8)
            : 0,
          tripCount: body?.context?.trip ? 1 : 0,
          communityPostCount: Array.isArray(body?.context?.communityPosts)
            ? Math.min(body.context.communityPosts.length, 6)
            : 0,
        },
      });
    } catch (error) {
      console.error("AI proxy request failed", error);
      return json({error: "The AI service is temporarily unavailable. Please try again later."}, 503);
    }
  },
};
