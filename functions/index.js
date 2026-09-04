const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentDeleted} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {defineSecret} = require("firebase-functions/params");
const {initializeApp, getApps} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");

if (getApps().length === 0) {
  initializeApp();
}

const nvidiaApiKey = defineSecret("NVIDIA_API_KEY");
const endpoint = "https://integrate.api.nvidia.com/v1/chat/completions";
const defaultModel = "meta/llama-3.1-8b-instruct";
const maxPromptLength = 2000;
const maxHistoryMessages = 12;
const aiHourlyLimit = 20;
const functionRegion = "asia-southeast1";
const firestoreDatabaseId =
  process.env.FIRESTORE_DATABASE_ID || "baganetic-mobile";

function firestore() {
  return getFirestore(firestoreDatabaseId);
}

async function updateCommunityPostCounter(event, field, delta) {
  const source = event.data;
  const postRef = source?.ref.parent.parent;
  if (!postRef) {
    return;
  }

  await firestore().runTransaction(async (transaction) => {
    const post = await transaction.get(postRef);
    if (!post.exists) {
      return;
    }

    const current = Number(post.get(field)) || 0;
    transaction.update(postRef, {
      [field]: Math.max(0, current + delta),
      updatedAt: FieldValue.serverTimestamp(),
    });
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

async function assertAiQuota(uid) {
  const ref = firestore().collection("aiUsage").doc(uid);
  const windowMs = 60 * 60 * 1000;

  await firestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const now = Date.now();
    let count = 0;
    let windowStart = now;

    if (snapshot.exists) {
      const data = snapshot.data() || {};
      windowStart = typeof data.windowStart === "number" ? data.windowStart : now;
      count = typeof data.count === "number" ? data.count : 0;
      if (now - windowStart >= windowMs) {
        count = 0;
        windowStart = now;
      }
    }

    if (count >= aiHourlyLimit) {
      throw new HttpsError(
        "resource-exhausted",
        "The AI assistant is rate limited. Please try again later.",
      );
    }

    transaction.set(ref, {
      count: count + 1,
      windowStart,
      updatedAt: now,
    });
  });
}

async function deleteQuery(query) {
  // A Firestore batch supports at most 500 operations. Continue in bounded
  // batches so an account with substantial community activity is fully erased.
  while (true) {
    const snapshot = await query.limit(400).get();
    if (snapshot.empty) {
      return;
    }
    const batch = firestore().batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}

exports.generateAiReply = onCall(
  {region: functionRegion, secrets: [nvidiaApiKey], timeoutSeconds: 60},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in is required to use the AI assistant.");
    }

    const prompt = asText(request.data?.prompt, maxPromptLength);
    if (!prompt) {
      throw new HttpsError("invalid-argument", "A non-empty prompt is required.");
    }

    await assertAiQuota(request.auth.uid);

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

const communityCounterTriggerOptions = (document) => ({
  document,
  region: functionRegion,
  database: firestoreDatabaseId,
});

exports.incrementCommunityCommentCount = onDocumentCreated(
  communityCounterTriggerOptions("communityPosts/{postId}/comments/{commentId}"),
  (event) => updateCommunityPostCounter(event, "commentCount", 1),
);

exports.decrementCommunityCommentCount = onDocumentDeleted(
  communityCounterTriggerOptions("communityPosts/{postId}/comments/{commentId}"),
  (event) => updateCommunityPostCounter(event, "commentCount", -1),
);

exports.incrementCommunityVoteCount = onDocumentCreated(
  communityCounterTriggerOptions("communityPosts/{postId}/votes/{userId}"),
  (event) => updateCommunityPostCounter(event, "upvoteCount", 1),
);

exports.decrementCommunityVoteCount = onDocumentDeleted(
  communityCounterTriggerOptions("communityPosts/{postId}/votes/{userId}"),
  (event) => updateCommunityPostCounter(event, "upvoteCount", -1),
);

exports.deleteUserAccount = onCall(
  {region: functionRegion, timeoutSeconds: 60},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in is required to delete an account.");
    }

    const uid = request.auth.uid;
    const db = firestore();
    const userRef = db.collection("users").doc(uid);

    await db.recursiveDelete(userRef);

    const posts = await db
      .collection("communityPosts")
      .where("authorUserId", "==", uid)
      .get();
    for (const post of posts.docs) {
      await db.recursiveDelete(post.ref);
    }

    await deleteQuery(
      db.collectionGroup("comments").where("authorUserId", "==", uid),
    );
    await deleteQuery(
      db.collectionGroup("votes").where("userId", "==", uid),
    );
    await db.collection("aiUsage").doc(uid).delete();
    await getStorage().bucket().file(`users/${uid}/profile.jpg`).delete({
      ignoreNotFound: true,
    });

    await getAuth().deleteUser(uid);
    return {deleted: true};
  },
);
