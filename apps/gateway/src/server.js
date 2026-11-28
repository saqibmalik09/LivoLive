/*
 * Livo / SK Live Party
 * App maintenance & design by NoxLab AI - https://noxlabai.com
 * Contact: https://noxlabai.com/quote | https://noxlabai.com/book
 * (c) 2026 NoxLab AI - maintenance and design updates
 */
require("dotenv").config();
const http = require("http");
const fs = require("fs");
const path = require("path");
const express = require("express");
const cors = require("cors");
const { Server: Server } = require("socket.io");
const { createAdapter: createAdapter } = require("@socket.io/redis-adapter");
const Redis = require("ioredis");
const {
  createRemoteJWKSet: createRemoteJWKSet,
  createLocalJWKSet: createLocalJWKSet,
  jwtVerify: jwtVerify,
} = require("jose");
const { v4: uuidv4 } = require("uuid");
const db = require("./db");
const state = require("./redis_state");
const dmState = require("./dm_state");
const gameState = require("./game_state");
const orbitVoice = require("./orbit_voice");
const baishunMerchant = require("./baishun_merchant");
const waveGames = require("./wave_games");
const mediaUpload = require("./media_upload");
const luckyEngine = require("./lucky_engine");
const giftSettle = require("./gift_settle");
const { createKeyedQueue: createKeyedQueue } = require("./keyed_queue");
const { bannerTarget: bannerTarget } = require("./banner_mute");
const { topBannerAllowed: topBannerAllowed } = require("./top_banner_rules");
const { applyKeepAlive: applyKeepAlive } = require("./http_tuning");
const { installGracefulShutdown: installGracefulShutdown } = require("./graceful_shutdown");
const giftSendQueue = createKeyedQueue({
  maxPending: Number(process.env.GIFT_SEND_MAX_PENDING) || 50,
});
/** Cross-sender cap so a storm of gifters cannot exhaust the gift DB pool. */
const GIFT_GLOBAL_INFLIGHT_MAX = Math.max(
  8,
  Number(process.env.GIFT_GLOBAL_INFLIGHT_MAX) || 64,
);
let giftGlobalInflight = 0;
const PORT = Number(process.env.PORT || 3e3);
const REDIS_URL = process.env.REDIS_URL || "redis://127.0.0.1:6379";
const SUPABASE_URL = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
const SUPABASE_JWT_SECRET = process.env.SUPABASE_JWT_SECRET || "";
const ALLOW_ANON = process.env.ALLOW_ANON_CONNECT === "1";
const MAINTENANCE_BYPASS_TOKEN = process.env.MAINTENANCE_BYPASS_TOKEN || "";
const MAINTENANCE_POLL_MS = 15e3;
const app = express();
app.use(cors());
app.use(express.json({ limit: "256kb" }));
app.get("/health", async (_req, res) => {
  let redisOk = false;
  let dbOk = false;
  let dbError = null;
  let pool = null;
  try {
    redisOk = (await pubClient.ping()) === "PONG";
  } catch (_) {}
  try {
    const p = db.getPool();
    if (p) {
      pool = {
        total: p.totalCount,
        idle: p.idleCount,
        waiting: p.waitingCount,
        max: p.options?.max ?? null,
      };
      await db.query("SELECT 1");
      dbOk = true;
      pool = {
        total: p.totalCount,
        idle: p.idleCount,
        waiting: p.waitingCount,
        max: p.options?.max ?? null,
      };
    }
  } catch (err) {
    dbError = err?.message || String(err);
  }
  res.json({
    ok: true,
    service: "sk-live-realtime-gateway",
    redis: redisOk,
    db: dbOk,
    db_error: dbError,
    pool: pool,
    auth: localJwks
      ? SUPABASE_JWT_SECRET
        ? "local-jwks+hs256"
        : "local-jwks"
      : SUPABASE_JWT_SECRET
        ? "hs256"
        : remoteJwks
          ? "jwks"
          : "none",
    allow_anon: ALLOW_ANON,
    maintenance: maintenanceOn,
    ts: Date.now(),
  });
});
// LiveKit webhook: the server-side half of open voice tokens. A holder of an
// open token can technically publish their microphone from the moment they join,
// so every microphone track_published event is checked against the seat table.
// Someone with no seat (and no seat tap in flight) loses publish permission.
// The body is read raw because the signature covers the exact bytes.
async function mayPublishNow(roomId, userId) {
  if (preparedGrants.has(`${roomId}:${userId}`)) return true;
  return (await redisSeatIndexForUser(roomId, userId)) != null;
}
async function enforceSeatPublish(event) {
  if (event?.event !== "track_published") return;
  if (String(event.track?.type || "").toUpperCase() !== "AUDIO") return;
  const userId = String(event.participant?.identity || "");
  const roomId = orbitVoice.roomIdFromLivekitRoom(event.room?.name);
  if (!userId || !roomId) return;
  // Users on the grant-on-seat path cannot publish without a grant already.
  if (!isOpenVoice(roomId, userId)) return;
  if (await mayPublishNow(roomId, userId)) return;
  // The seat write can land a moment after the track appears; look again
  // before treating it as unauthorised.
  await new Promise((resolve) => {
    const timer = setTimeout(resolve, SEAT_ENFORCE_GRACE_MS);
    if (typeof timer.unref === "function") timer.unref();
  });
  if (await mayPublishNow(roomId, userId)) return;
  console.warn(
    `[voice:webhook] publish without seat room=${roomId} user=${userId} ` +
      `enforce=${VOICE_WEBHOOK_ENFORCE}`,
  );
  if (!VOICE_WEBHOOK_ENFORCE) return;
  openVoiceRevoked.add(openVoiceKey(roomId, userId));
  const result = await orbitVoice.syncLivePermission({
    userId: userId,
    roomId: roomId,
    canPublish: false,
  });
  if (result !== "updated" && result !== "not_connected") {
    console.warn(
      `[voice:webhook] revoke failed room=${roomId} user=${userId} perm=${result}`,
    );
  }
}
app.post(
  "/livekit/webhook",
  express.raw({ type: "*/*", limit: "256kb" }),
  async (req, res) => {
    const event = await orbitVoice.verifyLivekitWebhook({
      authHeader: req.get("authorization"),
      rawBody: req.body,
    });
    if (!event) return res.status(401).end();
    res.status(200).end();
    void enforceSeatPublish(event).catch((err) =>
      console.warn("[voice:webhook] enforce failed:", err?.message || err),
    );
  },
);
const server = http.createServer(app);
applyKeepAlive(server);
const shutdown = installGracefulShutdown({ server: server });
const io = new Server(server, {
  cors: { origin: "*", methods: ["GET", "POST"] },
  transports: ["websocket", "polling"],
  pingInterval: 2e4,
  pingTimeout: 25e3,
});
const pubClient = new Redis(REDIS_URL, { maxRetriesPerRequest: null });
const subClient = pubClient.duplicate();
const gameSubClient = pubClient.duplicate();
io.adapter(createAdapter(pubClient, subClient));
let localJwks = null;
try {
  const jwksPath = path.join(__dirname, "jwks.local.json");
  if (fs.existsSync(jwksPath)) {
    localJwks = createLocalJWKSet(
      JSON.parse(fs.readFileSync(jwksPath, "utf8")),
    );
    console.log("[auth] local JWKS loaded");
  }
} catch (err) {
  console.warn("[auth] local JWKS load failed:", err.message);
}
let remoteJwks = null;
if (SUPABASE_URL) {
  try {
    remoteJwks = createRemoteJWKSet(
      new URL(`${SUPABASE_URL}/auth/v1/.well-known/jwks.json`),
      { timeoutDuration: 4e3, cooldownDuration: 3e4 },
    );
  } catch (err) {
    console.warn("[auth] remote JWKS init failed:", err.message);
  }
}
async function verifyToken(token) {
  if (!token) return null;
  if (localJwks) {
    try {
      const { payload: payload } = await jwtVerify(token, localJwks, {
        algorithms: ["ES256"],
      });
      return payload;
    } catch (err) {
      if (!/no matching|unsupported|alg/i.test(String(err.message))) {
        console.warn("[auth] local JWKS verify failed:", err.message);
      }
    }
  }
  if (SUPABASE_JWT_SECRET) {
    try {
      const secret = new TextEncoder().encode(SUPABASE_JWT_SECRET);
      const { payload: payload } = await jwtVerify(token, secret, {
        algorithms: ["HS256"],
      });
      return payload;
    } catch (err) {
      console.warn("[auth] HS256 verify failed:", err.message);
    }
  }
  if (remoteJwks) {
    try {
      const { payload: payload } = await Promise.race([
        jwtVerify(token, remoteJwks),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error("jwks timeout")), 4500),
        ),
      ]);
      return payload;
    } catch (err) {
      console.warn("[auth] remote JWKS verify failed:", err.message);
    }
  }
  return null;
}
function ackOk(ack, data = {}) {
  if (typeof ack === "function") ack({ ok: true, ...data });
}
function ackErr(ack, error) {
  if (typeof ack === "function") ack({ ok: false, error: String(error) });
}
function isAnonUser(userId) {
  return !userId || String(userId).startsWith("anon:");
}
async function emitRoomEvent(roomId, eventName, data, actorUserId) {
  const seq = await state.nextSeq(pubClient, roomId);
  const envelope = {
    event_id: data.event_id || uuidv4(),
    event: eventName,
    room_id: roomId,
    user_id: actorUserId,
    seq: seq,
    ts: Date.now(),
    data: data,
  };
  io.to(`room:${roomId}`).emit("room:event", envelope);
  return envelope;
}
async function emitDmEvent(
  conversationId,
  eventName,
  data,
  actorUserId,
  participantIds,
) {
  const seq = await dmState.nextDmSeq(pubClient, conversationId);
  const envelope = {
    event_id: data.event_id || uuidv4(),
    event: eventName,
    conversation_id: conversationId,
    user_id: actorUserId,
    seq: seq,
    ts: Date.now(),
    data: data,
  };
  const targets = (participantIds || []).filter(Boolean);
  for (const uid of targets) {
    io.to(`user:${uid}`).emit("dm:event", envelope);
  }
  return envelope;
}
function dmMessagePreview(row) {
  const type = String(row.message_type || "text");
  if (type === "image") return "📷 Photo";
  if (type === "voice") return "🎤 Voice message";
  if (type === "gift") return "🎁 Gift";
  const content = (row.content || "").toString().trim();
  if (!content) return "Message";
  return content.length > 80 ? `${content.slice(0, 80)}…` : content;
}
function buildInboxPayload({
  conversation: conversation,
  row: row,
  unreadForUser: unreadForUser,
  peerId: peerId,
}) {
  return {
    conversation_id: conversation.id,
    status: conversation.status,
    last_message_at: row?.created_at || conversation.last_message_at,
    last_message: row
      ? {
          id: row.id,
          content: row.content,
          message_type: row.message_type,
          media_url: row.media_url,
          sender_id: row.sender_id,
          created_at: row.created_at,
          metadata: row.metadata,
          preview: dmMessagePreview(row),
        }
      : null,
    unread_count: unreadForUser,
    peer_id: peerId,
  };
}
const APP_PRESENCE_GRACE_MS = Number(process.env.APP_PRESENCE_GRACE_MS || 2e4);
const appOfflineTimers = new Map();
function cancelAppOffline(userId) {
  const t = appOfflineTimers.get(userId);
  if (t) {
    clearTimeout(t);
    appOfflineTimers.delete(userId);
  }
}
async function notifyAppPresence(userId, online) {
  if (!userId || String(userId).startsWith("anon:")) return;
  const watchers = await state.getAppWatchers(pubClient, userId);
  if (!watchers.length) return;
  const envelope = {
    event_id: uuidv4(),
    event: "presence",
    user_id: userId,
    ts: Date.now(),
    data: {
      user_id: userId,
      online: !!online,
      updated_at: new Date().toISOString(),
    },
  };
  for (const wid of watchers) {
    if (!wid || wid === userId) continue;
    io.to(`user:${wid}`).emit("dm:event", envelope);
  }
}
async function markAppOnline(userId) {
  if (!userId || String(userId).startsWith("anon:")) return;
  cancelAppOffline(userId);
  await state.setAppOnline(pubClient, userId);
  await notifyAppPresence(userId, true);
}
function scheduleAppOffline(userId) {
  if (!userId || String(userId).startsWith("anon:")) return;
  cancelAppOffline(userId);
  const timer = setTimeout(async () => {
    appOfflineTimers.delete(userId);
    try {
      if (await userHasLiveSocket(userId)) {
        await state.setAppOnline(pubClient, userId);
        return;
      }
      await state.clearAppOnline(pubClient, userId);
      await notifyAppPresence(userId, false);
      console.log(`[presence] app offline user=${userId}`);
    } catch (err) {
      console.warn("[presence] offline failed:", err.message);
    }
  }, APP_PRESENCE_GRACE_MS);
  appOfflineTimers.set(userId, timer);
}
function emitGlobalWin(winPayload, actorUserId) {
  const data = { ...winPayload };
  if (!data.id) data.id = data.event_id || uuidv4();
  if (!data.created_at) data.created_at = new Date().toISOString();
  const envelope = {
    event_id: data.event_id || data.id || uuidv4(),
    event: "global_win",
    user_id: actorUserId,
    ts: Date.now(),
    data: data,
  };
  if (!topBannerAllowed(data)) return envelope;
  bannerTarget(io).emit("global:win", envelope);
  return envelope;
}
function pickGiftMessageForLog(data, giftLogId) {
  const want = giftLogId != null ? String(giftLogId) : "";
  const candidates = [];
  if (data?.message) candidates.push(data.message);
  if (Array.isArray(data?.messages)) {
    for (const m of data.messages) candidates.push(m);
  }
  if (want) {
    for (const msg of candidates) {
      if (!msg || typeof msg !== "object") continue;
      const meta =
        msg.metadata && typeof msg.metadata === "object" ? msg.metadata : {};
      if (String(meta.gift_log_id || "") === want) return msg;
    }
  }
  return candidates.find((m) => m && typeof m === "object") || null;
}
function profileFromGiftMessage(msg) {
  if (!msg || typeof msg !== "object") {
    return { username: "", avatar_url: null, gift_name: null };
  }
  const meta =
    msg.metadata && typeof msg.metadata === "object" ? msg.metadata : {};
  const user = msg.user && typeof msg.user === "object" ? msg.user : {};
  const username = String(
    meta.sender_username || user.username || meta.username || "",
  ).trim();
  const avatarRaw =
    meta.sender_avatar || user.avatar_url || meta.avatar_url || null;
  const avatar_url =
    avatarRaw != null && String(avatarRaw).trim()
      ? String(avatarRaw).trim()
      : null;
  const gift_name =
    meta.gift_name != null && String(meta.gift_name).trim()
      ? String(meta.gift_name).trim()
      : null;
  return { username: username, avatar_url: avatar_url, gift_name: gift_name };
}
async function resolveLuckySenderProfile({
  data: data,
  win: win,
  socket: socket,
}) {
  const fromMsg = profileFromGiftMessage(
    pickGiftMessageForLog(data, win?.gift_log_id),
  );
  let username = fromMsg.username;
  let avatar_url = fromMsg.avatar_url;
  const gift_name = fromMsg.gift_name;
  if ((!username || username === "User") && socket?.data?.username) {
    username = String(socket.data.username).trim();
  }
  if (!avatar_url && socket?.data?.avatar_url) {
    avatar_url = String(socket.data.avatar_url).trim() || null;
  }
  const senderId = String(win?.sender_id || socket?.data?.userId || "").trim();
  if (senderId && (!username || username === "User" || !avatar_url)) {
    try {
      const profile = await db.loadUserPublic(senderId);
      if (!username || username === "User") {
        username = String(profile.username || "").trim() || username;
      }
      if (!avatar_url && profile.avatar_url) {
        avatar_url = String(profile.avatar_url).trim() || null;
      }
    } catch (err) {
      console.warn("[lucky_engine] profile lookup failed:", err.message);
    }
  }
  if (!username) username = "User";
  return { username: username, avatar_url: avatar_url, gift_name: gift_name };
}
baishunMerchant.mount(app, {
  pubClient: pubClient,
  verifyToken: verifyToken,
  emitGlobalWin: emitGlobalWin,
});
waveGames.mount(app, { verifyToken: verifyToken });
mediaUpload.mount(app, { verifyToken: verifyToken });
const BIG_GIFT_PATTI_THRESHOLD = 5e5;
function emitGlobalBigGift(giftPayload, actorUserId) {
  const data = { ...giftPayload };
  if (!data.id) data.id = data.event_id || uuidv4();
  if (!data.created_at) data.created_at = new Date().toISOString();
  const envelope = {
    event_id: data.event_id || data.id || uuidv4(),
    event: "global_big_gift",
    user_id: actorUserId,
    ts: Date.now(),
    data: data,
  };
  bannerTarget(io).emit("global:big_gift", envelope);
  return envelope;
}
function extractBigGiftPattiFromGiftMessage(message, actorUserId, roomId) {
  if (!message || typeof message !== "object") return null;
  if (String(message.type || "") !== "gift") return null;
  const meta =
    message.metadata && typeof message.metadata === "object"
      ? message.metadata
      : {};
  const priceCoins = Number(meta.price_coins) || 0;
  const quantity = Number(meta.quantity) || 1;
  const giftCoins = priceCoins * quantity;
  if (giftCoins < BIG_GIFT_PATTI_THRESHOLD) return null;
  return {
    id: String(meta.animation_batch_id || meta.event_id || uuidv4()),
    event_id: meta.event_id || meta.animation_batch_id || undefined,
    user_id: String(message.user_id || meta.sender_id || actorUserId || ""),
    username: String(meta.sender_username || "User"),
    avatar_url: meta.sender_avatar != null ? String(meta.sender_avatar) : null,
    gift_name: meta.gift_name != null ? String(meta.gift_name) : null,
    gift_coins: giftCoins,
    room_id:
      meta.room_id != null
        ? String(meta.room_id)
        : roomId != null
          ? String(roomId)
          : undefined,
    created_at: message.created_at || new Date().toISOString(),
  };
}
function extractLuckyWinFromGiftMessage(message, actorUserId, roomId) {
  if (!message || typeof message !== "object") return null;
  if (String(message.type || "") !== "gift") return null;
  const meta =
    message.metadata && typeof message.metadata === "object"
      ? message.metadata
      : {};
  const luckyProWon = meta.lucky_pro_bonus_won === true;
  const luckyWon = meta.lucky_bonus_won === true;
  if (!luckyProWon && !luckyWon) return null;
  const rewardCoins = luckyProWon
    ? Number(meta.lucky_pro_bonus_coins) || 0
    : Number(meta.lucky_bonus_coins) || 0;
  if (rewardCoins <= 0) return null;
  const multiplier = Number(meta.bonus_multiplier) || 1;
  const tier =
    meta.multiplier_tier != null
      ? String(meta.multiplier_tier)
      : `x${multiplier}`;
  const resolvedRoomId =
    meta.room_id != null
      ? String(meta.room_id)
      : message.room_id != null
        ? String(message.room_id)
        : roomId != null
          ? String(roomId)
          : undefined;
  return {
    id: String(meta.animation_batch_id || meta.event_id || uuidv4()),
    event_id: meta.event_id || meta.animation_batch_id || undefined,
    user_id: String(message.user_id || actorUserId || ""),
    username: String(meta.sender_username || "User"),
    avatar_url: meta.sender_avatar != null ? String(meta.sender_avatar) : null,
    source_label: String(meta.gift_name || "Lucky Gift"),
    reward_coins: rewardCoins,
    bonus_multiplier: multiplier,
    multiplier_tier: tier,
    variant: luckyProWon ? "lucky_pro" : "lucky",
    room_id: resolvedRoomId,
    created_at: message.created_at || new Date().toISOString(),
  };
}
/**
 * Collapses concurrent identical async work onto one promise.
 *
 * Opening a room fires several snapshot reads at once (the join ack, the seat
 * repaint, a late presence update). Each one used to run the whole Redis and
 * SQL fan-out again, so a five-person room did five times the work it needed.
 */
function createSingleflight() {
  const inFlight = new Map();
  return function run(key, fn) {
    const existing = inFlight.get(key);
    if (existing) return existing;
    const promise = Promise.resolve()
      .then(fn)
      .finally(() => {
        inFlight.delete(key);
      });
    inFlight.set(key, promise);
    return promise;
  };
}
const snapshotFlight = createSingleflight();
// Resolves seat wear (frame + badges) for a set of users, preferring Redis.
// Only users nobody has rendered recently reach the inventory/level/agency SQL.
async function resolveSeatWear(userIds) {
  let wear;
  try {
    wear = await state.mgetSeatWear(pubClient, userIds);
  } catch (err) {
    console.warn("[seats] wear cache read:", err.message);
    wear = new Map();
  }
  const missing = userIds.filter((id) => !wear.has(id));
  if (!missing.length) return wear;
  const fresh = await db.loadSeatWearForUsers(missing);
  fresh.forEach((value, id) => wear.set(id, value));
  if (fresh.size) {
    state
      .msetSeatWear(pubClient, fresh)
      .catch((err) => console.warn("[seats] wear cache write:", err.message));
  }
  return wear;
}
async function refreshSeatsCache(roomId) {
  try {
    const seats = await db.loadRoomSeats(roomId, {
      wearResolver: resolveSeatWear,
    });
    await state.setSeatsSnapshot(pubClient, roomId, seats);
    return seats;
  } catch (err) {
    console.warn("[seats] refresh failed:", err.message);
    return state.getSeatsSnapshot(pubClient, roomId);
  }
}
// Fills the seat and meta caches for a room if they are cold, so the caller's
// buildSnapshot is a pure Redis read. Never throws and never returns data: the
// point is only to move the Postgres reads off the critical path. Concurrent
// joins into the same room collapse onto one in-flight warm.
const warmFlight = new Map();
function warmRoomCaches(roomId) {
  const inFlight = warmFlight.get(roomId);
  if (inFlight) return inFlight;
  const run = (async () => {
    const [seats, meta] = await Promise.all([
      state.getSeatsSnapshot(pubClient, roomId).catch(() => null),
      state.getMetaSnapshot(pubClient, roomId).catch(() => null),
    ]);
    const work = [];
    if (!Array.isArray(seats)) work.push(refreshSeatsCache(roomId));
    if (!meta) {
      work.push(
        (async () => {
          const loaded = await db.loadRoomMeta(roomId);
          await state.setMetaSnapshot(pubClient, roomId, loaded);
        })(),
      );
    }
    if (work.length) await Promise.allSettled(work);
  })()
    .catch((err) => {
      console.warn("[room:join] cache warm:", err.message);
    })
    .finally(() => {
      warmFlight.delete(roomId);
    });
  warmFlight.set(roomId, run);
  return run;
}
// Presence is pushed to Postgres so room discovery lists stay warm. Ten people
// arriving at once used to mean ten of these round trips inside ten joins; one
// per room per window reports the same number with one query.
const PRESENCE_REPORT_MS = Number(process.env.PRESENCE_REPORT_MS || 3000);
const presenceReportTimers = new Map();
function scheduleReportPresence(roomId) {
  if (!roomId || presenceReportTimers.has(roomId)) return;
  const timer = setTimeout(async () => {
    presenceReportTimers.delete(roomId);
    try {
      const count = await state.presenceCount(pubClient, roomId);
      await db.reportPresence(roomId, count);
    } catch (err) {
      console.warn("[presence] report failed:", err.message);
    }
  }, PRESENCE_REPORT_MS);
  if (typeof timer.unref === "function") timer.unref();
  presenceReportTimers.set(roomId, timer);
}
// Records the joiner as a room member. The host already has a role, so they are
// skipped. Meta comes from the snapshot cache the join just populated.
async function persistRoomMembership(roomId, userId) {
  try {
    let meta = await state.getMetaSnapshot(pubClient, roomId);
    if (!meta) meta = await db.loadRoomMeta(roomId);
    if (meta && String(meta.host_id || "") === String(userId)) return;
    await db.upsertMember({ roomId: roomId, userId: userId });
  } catch (err) {
    console.warn("[presence] join persist:", err.message);
  }
}
const VOICE_INLINE_TIMEOUT_MS = Number(
  process.env.VOICE_INLINE_TIMEOUT_MS || 400,
);
// Open voice tokens. A client that announces `voice_cap: "seat_token"` at
// connect gets a LiveKit token that already allows publishing the microphone,
// so taking a seat needs no live admin call (that call stalled 0.6-1.5 s under
// load). Seats stay authoritative: publishing without one is cut by the
// track_published webhook below. VOICE_OPEN_TOKENS=0 turns the feature off and
// every client falls back to the grant-on-seat path.
const VOICE_OPEN_TOKENS_ON = process.env.VOICE_OPEN_TOKENS !== "0";
const VOICE_WEBHOOK_ENFORCE = process.env.VOICE_WEBHOOK_ENFORCE !== "0";
const SEAT_ENFORCE_GRACE_MS = Number(process.env.SEAT_ENFORCE_GRACE_MS || 2500);
const OPEN_VOICE_MAX = 50000;
// room:user pairs whose current LiveKit token is an open one. Bounded: when
// full the oldest entry goes, which only means that user falls back to the
// grant call on their next seat change.
const openVoiceUsers = new Set();
// Open users whose publish the webhook took away; the next seat action
// re-grants it in the background.
const openVoiceRevoked = new Set();
function openVoiceKey(roomId, userId) {
  return `${roomId}:${userId}`;
}
function markOpenVoice(roomId, userId, open) {
  if (!roomId || !userId) return;
  const key = openVoiceKey(roomId, userId);
  if (!open) {
    openVoiceUsers.delete(key);
    return;
  }
  if (!openVoiceUsers.has(key) && openVoiceUsers.size >= OPEN_VOICE_MAX) {
    openVoiceUsers.delete(openVoiceUsers.values().next().value);
  }
  openVoiceUsers.add(key);
}
function isOpenVoice(roomId, userId) {
  return openVoiceUsers.has(openVoiceKey(roomId, userId));
}
/**
 * Builds the voice session to send with a room:join ack.
 *
 * Publish permission comes from the seat rows in the snapshot, never from
 * anything the client claimed — same rule mintVoiceToken enforces, just
 * without repeating its two lookups.
 *
 * Returns null when LiveKit is unconfigured or the signer failed, so a join
 * still succeeds and the client falls back to asking for a token.
 */
async function voiceSessionFromSnapshot(
  snapshot,
  userId,
  user,
  roomId,
  openPublish = false,
) {
  if (!userId || String(userId).startsWith("anon:")) return null;
  const seats = Array.isArray(snapshot?.seats) ? snapshot.seats : [];
  const canPublish = seats.some((s) => seatOccupantId(s) === String(userId));
  try {
    // Signing is local, but the settings read behind it can touch Postgres on
    // a cold cache. Capped so a slow database can never hold up a join: the
    // client simply asks for a token the old way instead.
    return await Promise.race([
      orbitVoice
        .mintVoiceTokenFor({
          userId: userId,
          userName: user?.username || user?.name || userId,
          roomId: roomId,
          canPublish: canPublish,
          openPublish: openPublish,
        })
        .then((session) => {
          markOpenVoice(roomId, userId, !!session && openPublish);
          return session;
        }),
      new Promise((resolve) => {
        const timer = setTimeout(() => resolve(null), VOICE_INLINE_TIMEOUT_MS);
        if (typeof timer.unref === "function") timer.unref();
      }),
    ]);
  } catch (err) {
    console.warn("[room:join] inline voice session:", err.message);
    return null;
  }
}
// Early publish grant. Tapping a seat grants publish on the user's open LiveKit
// connection before the seat is written, so by the time the claim is acked the
// client can publish with no permission wait. The grant is only given for a seat
// the user could actually take, and it is taken back if they never sit.
const PREPARE_GRANT_TTL_MS = Number(process.env.SEAT_PREPARE_TTL_MS || 25000);
const preparedGrants = new Map();
function clearPreparedGrant(roomId, userId) {
  const key = `${roomId}:${userId}`;
  const timer = preparedGrants.get(key);
  if (timer) clearTimeout(timer);
  preparedGrants.delete(key);
}
// Takes publish away from a user who is no longer on a seat. Without this the
// only way a client lost publish was reconnecting with a new token, which is a
// multi-second stall on every seat leave.
function revokeLivePublish(roomId, userId, reason) {
  if (!roomId || !userId) return;
  clearPreparedGrant(roomId, userId);
  // An open token's holder keeps the microphone grant for the whole session and
  // unpublishes on its own when it leaves the seat; taking it away here would
  // make their next sit wait on the slow admin call again. A publish without a
  // seat is handled by the track_published webhook instead.
  if (isOpenVoice(roomId, userId)) return;
  void orbitVoice
    .syncLivePermission({ userId: userId, roomId: roomId, canPublish: false })
    .then(
      (result) => {
        if (result !== "updated" && result !== "not_connected") {
          console.warn(
            `[voice] revoke publish room=${roomId} user=${userId} ` +
              `reason=${reason} perm=${result}`,
          );
        }
      },
      (e) => console.warn("[voice] revoke publish threw:", e?.message || e),
    );
}
/**
 * Writes a seat and fans the change out. Shared by seat:claim and seat:sit.
 *
 * With `withVoice`, the ack also carries a publish token and the live
 * permission sync is started in the background. That is the whole point of
 * seat:sit: the old sequence was claim, then voice:token, then poll for
 * publish permission, then give up and reconnect to LiveKit — which is where
 * the long wait before anyone could hear you came from. seat:claim behaves
 * exactly as before.
 */
async function handleSeatClaim(socket, payload, ack, { withVoice }) {
  const label = withVoice ? "seat:sit" : "seat:claim";
  try {
    noteSocketActivity(socket, label);
    const roomId = String(payload.roomId || "").trim();
    const seatIndex = Number(payload.seatIndex);
    if (!roomId || Number.isNaN(seatIndex)) {
      return ackErr(ack, "roomId and seatIndex required");
    }
    const userId = socket.data.userId;
    const isMuted =
      payload.isMuted !== false && payload.isMuted !== undefined
        ? !!payload.isMuted
        : !!payload.is_muted;
    const seatRowId = payload.seatRowId || payload.seat_row_id || null;
    const eventId = payload.event_id || uuidv4();
    const user = payload.user || { id: userId };
    await ensureSingleRoomPresence(userId, roomId, user);
    cancelGraceVacate(userId);
    const t0 = Date.now();
    let row;
    try {
      row = await db.seatClaim({
        roomId: roomId,
        userId: userId,
        seatIndex: seatIndex,
        isMuted: isMuted,
      });
    } catch (err) {
      if (err?.code !== "seat_unavailable") throw err;
      const holder = err.occupantId;
      const reclaimable =
        !err.locked &&
        holder &&
        holder !== userId &&
        !(await userHasLiveSocket(holder));
      if (!reclaimable) {
        console.log(
          `[seat:audit] claim DENIED user=${userId} room=${roomId} ` +
            `seat=${seatIndex} holder=${holder ?? "none"} locked=${!!err.locked}`,
        );
        return ackErr(ack, err.locked ? "seat_locked" : "seat_unavailable");
      }
      console.log(
        `[seat:audit] claim reclaim ghost seat=${seatIndex} room=${roomId} ` +
          `from=${holder} to=${userId}`,
      );
      await vacateUserFromRoom(roomId, holder, { id: holder }, "ghost_seat");
      row = await db.seatClaim({
        roomId: roomId,
        userId: userId,
        seatIndex: seatIndex,
        isMuted: isMuted,
      });
    }
    const claimMs = Date.now() - t0;
    if (!row) {
      return ackErr(ack, "seat_unavailable");
    }
    const tSeats = Date.now();
    const seats = await refreshSeatsCache(roomId);
    const seatsMs = Date.now() - tSeats;
    const data = {
      event_id: eventId,
      room_id: roomId,
      actor_user_id: userId,
      action: "take",
      seat_index: seatIndex,
      user_id: userId,
      user: user,
      is_muted: isMuted,
      seat_row_id: row?.id || seatRowId,
    };
    let voice = null;
    if (withVoice) {
      // The seat now backs the grant, so the early-grant expiry is moot.
      clearPreparedGrant(roomId, userId);
      const openPublish = !!socket.data.voiceOpen;
      voice = await orbitVoice
        .mintVoiceTokenFor({
          userId: userId,
          userName: user?.username || user?.name || userId,
          roomId: roomId,
          canPublish: true,
          openPublish: openPublish,
        })
        .catch((e) => {
          console.warn(`[${label}] inline voice:`, e.message);
          return null;
        });
      markOpenVoice(roomId, userId, !!voice && openPublish);
      // An open token needs no live grant. The only exception is a user the
      // webhook cut earlier: their live permission is gone, so give it back in
      // the background (the client falls back on its own if this is slow).
      const needsRegrant =
        !openPublish || openVoiceRevoked.delete(openVoiceKey(roomId, userId));
      // Grants publish on a connection that is already open, so a client that
      // joined as a listener does not have to reconnect. Fire-and-forget: the
      // token in the ack is already valid either way.
      if (needsRegrant) {
        void orbitVoice
          .syncLivePermission({
            userId: userId,
            roomId: roomId,
            canPublish: true,
          })
          .then(
            (result) => {
              if (result !== "updated" && result !== "not_connected") {
                console.warn(
                  `[${label}] perm sync room=${roomId} user=${userId} perm=${result}`,
                );
              }
            },
            (e) => console.warn(`[${label}] perm sync threw:`, e?.message || e),
          );
      }
    }
    ackOk(ack, {
      event_id: eventId,
      seat: row,
      seats: seats,
      ...(voice ? { voice: voice } : {}),
    });
    console.log(
      `[${label}] ok`,
      JSON.stringify({
        roomId: roomId,
        seatIndex: seatIndex,
        claim_ms: claimMs,
        seats_ms: seatsMs,
        voice: withVoice ? !!voice : undefined,
        total_ms: Date.now() - t0,
      }),
    );
    emitRoomEvent(roomId, "room_seat", data, userId).catch((e) =>
      console.warn(`[${label}] fanout failed:`, e.message),
    );
    seatTrace(label, {
      userId: userId,
      roomId: roomId,
      seat_index: seatIndex,
      socketId: socket.id,
      seat_row_id: row?.id || seatRowId,
    });
  } catch (err) {
    console.error(`[${label}]`, err.message);
    ackErr(ack, err.message);
  }
}
function seatOccupantId(seat) {
  if (!seat || typeof seat !== "object") return null;
  const id = seat.user_id ?? seat.userId;
  if (id == null || id === "") return null;
  return String(id);
}
function seatOccupantIndex(seat) {
  if (!seat || typeof seat !== "object") return null;
  const raw = seat.seat_index ?? seat.index;
  if (raw == null || raw === "") return null;
  const n = Number(raw);
  return Number.isNaN(n) || n < 0 ? null : n;
}
async function redisSeatIndexForUser(roomId, userId) {
  if (!roomId || !userId) return null;
  try {
    const seats = await state.getSeatsSnapshot(pubClient, roomId);
    if (!Array.isArray(seats)) return null;
    for (const s of seats) {
      if (seatOccupantId(s) === String(userId)) {
        return seatOccupantIndex(s);
      }
    }
  } catch (_) {}
  return null;
}
function bumpSeatEmit(socket) {
  socket.data.seatEmitGen = (socket.data.seatEmitGen || 0) + 1;
  return socket.data.seatEmitGen;
}
function emitCachedSeats(socket, roomId) {
  const gen = bumpSeatEmit(socket);
  void (async () => {
    try {
      // Gift counts ride with the early seats so the hearts under each seat
      // fill in with the avatars, not after the full snapshot.
      const [seats, seatGiftTotals] = await Promise.all([
        state.getSeatsSnapshot(pubClient, roomId),
        state.getSeatGiftTotals(pubClient, roomId).catch(() => null),
      ]);
      // A cache miss returns null; an empty array is a real answer ("nobody is
      // seated") and is worth sending, so the seats render immediately instead
      // of waiting for the full snapshot.
      if (!Array.isArray(seats)) return;
      if (!socket.connected || socket.data.seatEmitGen !== gen) return;
      socket.emit("room:snapshot", {
        room_id: roomId,
        seats: seats,
        ...(seatGiftTotals ? { seat_gift_totals: seatGiftTotals } : {}),
      });
    } catch (err) {
      console.warn("[room:join] early seats:", err.message);
    }
  })();
}
function buildSnapshot(roomId) {
  return snapshotFlight(`snapshot:${roomId}`, () => loadSnapshot(roomId));
}
async function loadSnapshot(roomId) {
  const [
    cachedSeats,
    cachedMeta,
    presence,
    seqRaw,
    seatGiftTotals,
    cachedYoutube,
    cachedAudio,
  ] = await Promise.all([
    state.getSeatsSnapshot(pubClient, roomId),
    state.getMetaSnapshot(pubClient, roomId),
    state.listPresence(pubClient, roomId),
    pubClient.get(`room:${roomId}:seq`),
    state.getSeatGiftTotals(pubClient, roomId),
    state.getYoutubeState(pubClient, roomId),
    state.getSharedAudioState(pubClient, roomId),
  ]);
  let seats = cachedSeats;
  let meta = cachedMeta;
  if (!seats || !meta) {
    // Cold room. The app asks for a snapshot as the room screen is created and
    // sends room:join a frame later, so both arrive while the cache is still
    // empty. Each used to read seats, seat wear and room meta from Postgres on
    // its own. Going through the shared warm makes that one load; the direct
    // reads below remain only as the fallback if the warm did not fill it.
    await warmRoomCaches(roomId);
    const [warmSeats, warmMeta] = await Promise.all([
      seats ? seats : state.getSeatsSnapshot(pubClient, roomId).catch(() => null),
      meta ? meta : state.getMetaSnapshot(pubClient, roomId).catch(() => null),
    ]);
    seats = warmSeats;
    meta = warmMeta;
  }
  const pending = [];
  if (!seats) {
    pending.push(
      refreshSeatsCache(roomId).then((rows) => {
        seats = rows;
      }),
    );
  }
  if (!meta) {
    pending.push(
      (async () => {
        try {
          meta = await db.loadRoomMeta(roomId);
          await state.setMetaSnapshot(pubClient, roomId, meta);
        } catch (_) {}
      })(),
    );
  }
  if (pending.length) await Promise.all(pending);
  const seq = Number(seqRaw || 0);
  let youtubeState = cachedYoutube;
  if (!youtubeState && meta?.youtube_state) {
    youtubeState =
      typeof meta.youtube_state === "object" ? meta.youtube_state : null;
  }
  let sharedAudioState = cachedAudio;
  if (!sharedAudioState && meta?.shared_audio_state) {
    sharedAudioState =
      typeof meta.shared_audio_state === "object"
        ? meta.shared_audio_state
        : null;
  }
  return {
    seats: seats || [],
    meta: meta,
    presence: presence,
    seat_gift_totals: seatGiftTotals || {},
    youtube_state: youtubeState || null,
    shared_audio_state: sharedAudioState || null,
    seq: seq,
  };
}
function seatTrace(event, extra = {}) {
  console.log(
    "[SEAT-TRACE]",
    JSON.stringify({ ts: new Date().toISOString(), event: event, ...extra }),
  );
}
const DROP_DIAG_GIFT_WINDOW_SEC = Number(
  process.env.DROP_DIAG_GIFT_WINDOW_SEC || 90,
);
function ensureSocketDiag(socket) {
  if (!socket.data.diag) {
    socket.data.diag = {
      connected_at: Date.now(),
      events: {},
      last_event: null,
      last_event_at: null,
      last_heartbeat_at: null,
      gift_marks: [],
    };
  }
  return socket.data.diag;
}
function noteSocketActivity(socket, event, extra = null) {
  const d = ensureSocketDiag(socket);
  const now = Date.now();
  d.events[event] = (d.events[event] || 0) + 1;
  d.last_event = event;
  d.last_event_at = now;
  if (event === "presence:heartbeat") d.last_heartbeat_at = now;
  if (event === "room:gift_sent" || event === "client:diag") {
    d.gift_marks.push({
      at: now,
      event: event,
      ...(extra && typeof extra === "object" ? extra : {}),
    });
    if (d.gift_marks.length > 30)
      d.gift_marks.splice(0, d.gift_marks.length - 30);
  }
}
async function recentGiftsForUser(
  userId,
  windowSec = DROP_DIAG_GIFT_WINDOW_SEC,
) {
  if (!userId || String(userId).startsWith("anon:")) {
    return { skipped: true, reason: "anon_or_missing" };
  }
  try {
    const { rows: rows } = await db.query(
      `SELECT created_at, room_id, amount, gift_id\n       FROM gift_logs\n       WHERE sender_id = $1::uuid\n         AND created_at > now() - make_interval(secs => $2)\n       ORDER BY created_at DESC\n       LIMIT 25`,
      [userId, windowSec],
    );
    if (!rows.length) {
      return { count: 0, window_sec: windowSec };
    }
    const latest = rows[0].created_at;
    return {
      count: rows.length,
      window_sec: windowSec,
      latest_at: latest,
      ms_since_latest: Date.now() - new Date(latest).getTime(),
      total_amount: rows.reduce((s, r) => s + Number(r.amount || 0), 0),
      room_ids: [...new Set(rows.map((r) => r.room_id).filter(Boolean))],
      sample_amounts: rows.slice(0, 8).map((r) => Number(r.amount)),
      hypothesis:
        rows.length >= 5
          ? "gift_burst_before_drop"
          : rows.length > 0
            ? "gift_recent_before_drop"
            : "no_recent_gifts",
    };
  } catch (err) {
    return { error: err.message, window_sec: windowSec };
  }
}
async function lookupSeatIndex(roomId, userId) {
  if (!roomId || !userId) return null;
  try {
    const seats = await state.getSeatsSnapshot(pubClient, roomId);
    const hit = (seats || []).find(
      (s) => String(s.user_id || s.user?.id || "") === String(userId),
    );
    if (hit && hit.seat_index != null) return Number(hit.seat_index);
  } catch (_) {}
  try {
    const { rows: rows } = await db.query(
      `SELECT seat_index FROM room_seats\n       WHERE room_id = $1::uuid AND user_id = $2::uuid\n       LIMIT 1`,
      [roomId, userId],
    );
    return rows[0]?.seat_index != null ? Number(rows[0].seat_index) : null;
  } catch (_) {
    return null;
  }
}
async function emitDropDiag(phase, socketOrNull, fields = {}) {
  const socket = socketOrNull;
  const diag = socket?.data?.diag || null;
  const now = Date.now();
  const userId = fields.userId || socket?.data?.userId || null;
  const roomId = fields.roomId || socket?.data?.roomId || null;
  let gifts = fields.gifts;
  if (gifts === undefined && userId) {
    gifts = await recentGiftsForUser(userId);
  }
  let seatIndex = fields.seat_index;
  if (seatIndex === undefined && roomId && userId) {
    seatIndex = await lookupSeatIndex(roomId, userId);
  }
  const payload = {
    ts: new Date().toISOString(),
    phase: phase,
    userId: userId,
    roomId: roomId,
    socketId: socket?.id || fields.socketId || null,
    sio_reason: fields.sio_reason || null,
    seat_index: seatIndex ?? null,
    connected_ms: diag?.connected_at ? now - diag.connected_at : null,
    last_event: diag?.last_event || null,
    last_event_age_ms:
      diag?.last_event_at != null ? now - diag.last_event_at : null,
    last_heartbeat_age_ms:
      diag?.last_heartbeat_at != null ? now - diag.last_heartbeat_at : null,
    event_counts: diag?.events || null,
    client_gift_marks: diag?.gift_marks?.slice(-5) || [],
    transport: socket?.conn?.transport?.name || null,
    gifts: gifts,
    ...fields.extra,
  };
  if (gifts && !gifts.error && !gifts.skipped && gifts.count > 0) {
    payload.gift_correlation =
      gifts.ms_since_latest != null && gifts.ms_since_latest < 3e4
        ? "LIKELY_GIFT_RELATED"
        : "gifts_in_window_but_not_immediate";
  } else if (gifts && gifts.count === 0) {
    payload.gift_correlation = "NO_RECENT_GIFTS";
  } else if (gifts?.error) {
    payload.gift_correlation = "GIFT_LOOKUP_FAILED";
  }
  console.log("[DROP-DIAG]", JSON.stringify(payload));
}
const recentStaleVacates = new Map();
const STALE_VACATE_DEBOUNCE_MS = Number(
  process.env.STALE_VACATE_DEBOUNCE_MS || 45e3,
);
function shouldSkipStaleVacate(userId, roomId) {
  const key = `${userId}:${roomId}`;
  const last = recentStaleVacates.get(key) || 0;
  if (Date.now() - last < STALE_VACATE_DEBOUNCE_MS) return true;
  recentStaleVacates.set(key, Date.now());
  if (recentStaleVacates.size > 5e3) {
    const cutoff = Date.now() - STALE_VACATE_DEBOUNCE_MS * 2;
    for (const [k, ts] of recentStaleVacates) {
      if (ts < cutoff) recentStaleVacates.delete(k);
    }
  }
  return false;
}
async function vacateUserFromRoom(
  roomId,
  userId,
  userPayload = {},
  reason = "unknown",
  extra = {},
) {
  if (!roomId || !userId) return { seat_index: null, skipped: true };
  const user =
    userPayload && typeof userPayload === "object"
      ? { id: userId, ...userPayload, id: userId }
      : { id: userId };
  let leftSeatIndex = null;
  try {
    leftSeatIndex = await db.seatLeave({ roomId: roomId, userId: userId });
  } catch (err) {
    console.warn("[vacate] seat failed:", err.message);
  }
  if (leftSeatIndex == null) {
    leftSeatIndex = await redisSeatIndexForUser(roomId, userId);
    if (leftSeatIndex != null) {
      console.log(
        `[seat:audit] vacate redis-ghost user=${userId} room=${roomId} ` +
          `seat=${leftSeatIndex} reason=${reason}`,
      );
    }
  }
  let inPresence = false;
  try {
    inPresence = Boolean(
      await pubClient.sismember(`room:${roomId}:presence`, userId),
    );
  } catch (_) {
    inPresence = true;
  }
  seatTrace("vacate", {
    reason: reason,
    roomId: roomId,
    userId: userId,
    seat_index: leftSeatIndex,
    in_presence: inPresence,
    skipped: leftSeatIndex == null && !inPresence,
    ...extra,
  });
  if (leftSeatIndex == null && !inPresence) {
    return { seat_index: null, skipped: true };
  }
  if (leftSeatIndex != null || inPresence) {
    try {
      await stopSharedAudioIfStartedBy(roomId, userId, reason);
    } catch (err) {
      console.warn("[vacate] shared audio stop failed:", err.message);
    }
  }
  if (leftSeatIndex != null) {
    revokeLivePublish(roomId, userId, `vacate_${reason}`);
    try {
      await refreshSeatsCache(roomId);
      await emitRoomEvent(
        roomId,
        "room_seat",
        {
          event_id: uuidv4(),
          room_id: roomId,
          actor_user_id: userId,
          action: "leave",
          seat_index: leftSeatIndex,
          user_id: userId,
          user: user,
        },
        userId,
      );
    } catch (err) {
      console.warn("[vacate] seat fanout failed:", err.message);
    }
  }
  if (inPresence) {
    try {
      await state.presenceLeave(pubClient, roomId, userId);
      const count = await state.presenceCount(pubClient, roomId);
      scheduleReportPresence(roomId);
      if (count === 0) {
        await state.clearSeatGiftTotals(pubClient, roomId);
        await state.clearMediaStates(pubClient, roomId);
      }
      await emitRoomEvent(
        roomId,
        "room_presence",
        {
          event_id: uuidv4(),
          room_id: roomId,
          actor_user_id: userId,
          action: "leave",
          user: user,
        },
        userId,
      );
    } catch (err) {
      console.warn("[vacate] presence failed:", err.message);
    }
  }
  return { seat_index: leftSeatIndex, skipped: false };
}
async function stopSharedAudioIfStartedBy(roomId, userId, reason = "unknown") {
  if (!roomId || !userId) return false;
  let audio = await state.getSharedAudioState(pubClient, roomId);
  if (!audio || typeof audio !== "object") {
    try {
      const meta = await db.loadRoomMeta(roomId);
      audio =
        meta?.shared_audio_state && typeof meta.shared_audio_state === "object"
          ? meta.shared_audio_state
          : null;
    } catch (_) {
      audio = null;
    }
  }
  if (!audio || audio.is_active !== true) return false;
  if (String(audio.started_by || "") !== String(userId)) return false;
  const stopped = {
    is_active: false,
    audio_url: "",
    title: "",
    status: "stopped",
    timestamp: 0,
    duration: 0,
    volume: 1,
    updated_at: new Date().toISOString(),
    started_by: null,
    started_by_name: "",
    sync_kind: "control",
    stop_reason: reason,
  };
  await state.setSharedAudioState(pubClient, roomId, stopped);
  try {
    await db.updateRoomSharedAudioState(roomId, stopped);
  } catch (err) {
    console.warn("[shared-audio] db persist failed:", err.message);
  }
  await emitRoomEvent(
    roomId,
    "shared_audio_state",
    { event_id: uuidv4(), room_id: roomId, actor_user_id: userId, ...stopped },
    userId,
  );
  seatTrace("shared_audio_stop", {
    reason: reason,
    roomId: roomId,
    userId: userId,
  });
  return true;
}
async function ensureSingleRoomPresence(userId, roomId, userPayload = {}) {
  if (!userId || !roomId || String(userId).startsWith("anon:")) return null;
  const vacated = new Set();
  const tracked = await state.getUserPresenceRoom(pubClient, userId);
  if (tracked && tracked !== roomId) {
    console.log(
      `[presence] single-room move user=${userId} ${tracked} -> ${roomId}`,
    );
    await vacateUserFromRoom(tracked, userId, userPayload, "single-room-move", {
      keep_room: roomId,
    });
    vacated.add(tracked);
  }
  try {
    const otherSeats = await db.seatLeaveOtherRooms({
      userId: userId,
      keepRoomId: roomId,
    });
    for (const row of otherSeats) {
      const otherRoom = row.room_id?.toString();
      if (!otherRoom || vacated.has(otherRoom)) continue;
      vacated.add(otherRoom);
      seatTrace("seat-leave-other-room", {
        reason: "single-room-other-seat",
        userId: userId,
        roomId: otherRoom,
        keep_room: roomId,
        seat_index: row.seat_index,
      });
      console.log(
        `[presence] seat-leave other room user=${userId} room=${otherRoom} seat=${row.seat_index}`,
      );
      try {
        await refreshSeatsCache(otherRoom);
        await emitRoomEvent(
          otherRoom,
          "room_seat",
          {
            event_id: uuidv4(),
            room_id: otherRoom,
            actor_user_id: userId,
            action: "leave",
            seat_index: row.seat_index,
            user_id: userId,
            user: { id: userId, ...(userPayload || {}) },
          },
          userId,
        );
        await state.presenceLeave(pubClient, otherRoom, userId);
        scheduleReportPresence(otherRoom);
        await emitRoomEvent(
          otherRoom,
          "room_presence",
          {
            event_id: uuidv4(),
            room_id: otherRoom,
            actor_user_id: userId,
            action: "leave",
            user: { id: userId, ...(userPayload || {}) },
          },
          userId,
        );
      } catch (err) {
        console.warn("[presence] other-room cleanup failed:", err.message);
      }
    }
  } catch (err) {
    console.warn("[presence] seatLeaveOtherRooms failed:", err.message);
  }
  const pending = pendingGraceVacates.get(userId);
  if (pending?.roomId && pending.roomId !== roomId) {
    cancelGraceVacate(userId);
    if (!vacated.has(pending.roomId)) {
      await vacateUserFromRoom(
        pending.roomId,
        userId,
        userPayload,
        "single-room-stale-grace",
        { keep_room: roomId },
      );
      vacated.add(pending.roomId);
    }
  }
  return vacated.size ? [...vacated][0] : null;
}
const SOFT_DISCONNECT_GRACE_MS = Number(
  process.env.SOFT_DISCONNECT_GRACE_MS || 18e4,
);
const SOFT_DISCONNECT_PRESENCE_TTL_SEC = Math.max(
  state.PRESENCE_TTL_SEC,
  Math.ceil(SOFT_DISCONNECT_GRACE_MS / 1e3) + 30,
);
const pendingGraceVacates = new Map();
let _graceGenerationSeq = 0;
function cancelGraceVacate(userId) {
  const pending = pendingGraceVacates.get(userId);
  if (!pending) return null;
  clearTimeout(pending.timer);
  pendingGraceVacates.delete(userId);
  return pending;
}
// Every socket joins a room named after its user, so "is this user connected"
// is a targeted adapter lookup. These two used to pull down *every* connected
// socket and scan it, which the presence sweep did once per stale member.
function userSocketRoom(userId) {
  return `user:${userId}`;
}
async function userHasLiveSocket(userId) {
  if (!userId) return false;
  try {
    const sockets = await io.in(userSocketRoom(userId)).fetchSockets();
    return sockets.length > 0;
  } catch (_) {
    return false;
  }
}
async function getLiveSocketRoomId(userId) {
  if (!userId) return null;
  try {
    const sockets = await io.in(userSocketRoom(userId)).fetchSockets();
    for (const s of sockets) {
      const roomId = s?.data?.roomId;
      if (roomId) return String(roomId);
    }
    return null;
  } catch (_) {
    return null;
  }
}
function scheduleGraceVacate(userId, roomId) {
  if (!userId || !roomId || String(userId).startsWith("anon:")) return;
  cancelGraceVacate(userId);
  const generation = ++_graceGenerationSeq;
  state
    .presenceJoin(
      pubClient,
      roomId,
      userId,
      { id: userId },
      SOFT_DISCONNECT_PRESENCE_TTL_SEC,
    )
    .catch((err) =>
      console.warn("[ws] soft-dc presence hold failed:", err.message),
    );
  const timer = setTimeout(() => {
    const stillMine = pendingGraceVacates.get(userId);
    if (stillMine && stillMine.generation === generation) {
      pendingGraceVacates.delete(userId);
    }
    (async () => {
      try {
        const latest = pendingGraceVacates.get(userId);
        if (latest && latest.generation !== generation) return;
        const tracked = await state.getUserPresenceRoom(pubClient, userId);
        if (tracked && tracked !== roomId) {
          console.log(
            `[ws] grace-vacate skipped (moved rooms) user=${userId} ` +
              `was=${roomId} live=${tracked}`,
          );
          return;
        }
        const socketRoom = await getLiveSocketRoomId(userId);
        if (socketRoom && socketRoom !== roomId) {
          console.log(
            `[ws] grace-vacate skipped (socket in other room) user=${userId} ` +
              `was=${roomId} socketRoom=${socketRoom}`,
          );
          return;
        }
        if (await userHasLiveSocket(userId)) {
          const liveTracked = await state.getUserPresenceRoom(
            pubClient,
            userId,
          );
          if (liveTracked && liveTracked !== roomId) {
            console.log(
              `[ws] grace-vacate skipped (moved during check) user=${userId} ` +
                `was=${roomId} live=${liveTracked}`,
            );
            return;
          }
          const holdRoom = socketRoom || liveTracked || roomId;
          if (holdRoom !== roomId) {
            console.log(
              `[ws] grace-vacate skipped (hold mismatch) user=${userId} ` +
                `was=${roomId} hold=${holdRoom}`,
            );
            return;
          }
          console.log(
            `[ws] grace-vacate skipped (socket alive) user=${userId} room=${holdRoom}`,
          );
          state
            .presenceJoin(
              pubClient,
              holdRoom,
              userId,
              { id: userId },
              SOFT_DISCONNECT_PRESENCE_TTL_SEC,
            )
            .catch(() => {});
          return;
        }
        const sockets = await io.in(`room:${roomId}`).fetchSockets();
        const stillConnected = sockets.some(
          (s) => String(s.data.userId) === String(userId),
        );
        if (stillConnected) {
          console.log(
            `[ws] grace-vacate skipped (reconnected) user=${userId} room=${roomId}`,
          );
          state
            .presenceJoin(
              pubClient,
              roomId,
              userId,
              { id: userId },
              SOFT_DISCONNECT_PRESENCE_TTL_SEC,
            )
            .catch(() => {});
          return;
        }
        const finalTracked = await state.getUserPresenceRoom(pubClient, userId);
        if (finalTracked && finalTracked !== roomId) {
          console.log(
            `[ws] grace-vacate skipped (moved before vacate) user=${userId} ` +
              `was=${roomId} live=${finalTracked}`,
          );
          return;
        }
        console.log(
          `[ws] grace-vacate user=${userId} room=${roomId} after ${SOFT_DISCONNECT_GRACE_MS}ms`,
        );
        emitDropDiag("grace-vacate", null, {
          userId: userId,
          roomId: roomId,
          sio_reason: "disconnect-grace",
          extra: { grace_ms: SOFT_DISCONNECT_GRACE_MS },
        }).catch(() => {});
        await vacateUserFromRoom(
          roomId,
          userId,
          { id: userId },
          "disconnect-grace",
        );
      } catch (err) {
        console.warn("[ws] grace-vacate failed:", err.message);
      }
    })();
  }, SOFT_DISCONNECT_GRACE_MS);
  pendingGraceVacates.set(userId, {
    timer: timer,
    roomId: roomId,
    generation: generation,
  });
}
async function sweepStalePresenceSeats() {
  let cursor = "0";
  let swept = 0;
  do {
    const [next, keys] = await pubClient.scan(
      cursor,
      "MATCH",
      "room:*:presence",
      "COUNT",
      40,
    );
    cursor = next;
    for (const key of keys) {
      if (!key.endsWith(":presence") || key.includes(":presence:")) continue;
      const roomId = key.slice("room:".length, -":presence".length);
      if (!roomId) continue;
      const ids = await pubClient.smembers(key);
      if (!ids.length) continue;
      for (const userId of ids) {
        const alive = await pubClient.exists(
          `room:${roomId}:presence:${userId}`,
        );
        if (alive) continue;
        if (pendingGraceVacates.has(userId)) {
          console.log(
            `[sweep] skip (grace pending) user=${userId} room=${roomId}`,
          );
          continue;
        }
        if (await userHasLiveSocket(userId)) {
          console.log(
            `[sweep] skip (socket alive) user=${userId} room=${roomId}`,
          );
          continue;
        }
        try {
          await vacateUserFromRoom(
            roomId,
            userId,
            { id: userId },
            "sweep-stale-presence",
          );
          swept += 1;
          console.log(`[sweep] vacated stale user=${userId} room=${roomId}`);
        } catch (err) {
          console.warn("[sweep] vacate failed:", err.message);
        }
      }
    }
  } while (cursor !== "0");
  if (swept > 0) console.log(`[sweep] done vacated=${swept}`);
}

const ORPHAN_SEAT_MIN_AGE_MS = Number(
  process.env.ORPHAN_SEAT_MIN_AGE_MS || 15 * 6e4,
);

async function sweepOrphanedSeats() {
  if (!db.getPool()) return;
  let rows;
  try {
    ({ rows: rows } = await db.query(
      `SELECT room_id, user_id FROM room_seats
       WHERE user_id IS NOT NULL
         AND updated_at < now() - make_interval(secs => $1::double precision)
       ORDER BY updated_at ASC
       LIMIT 200`,
      [ORPHAN_SEAT_MIN_AGE_MS / 1000],
    ));
  } catch (err) {
    console.warn("[sweep:orphan] query failed:", err.message);
    return;
  }
  let vacated = 0;
  for (const row of rows) {
    const userId = String(row.user_id);
    const roomId = String(row.room_id);
    if (!userId || !roomId || userId.startsWith("anon:")) continue;
    if (pendingGraceVacates.has(userId)) continue;
    try {
      if (await userHasLiveSocket(userId)) continue;
      if (await pubClient.exists(`room:${roomId}:presence:${userId}`)) continue;
      await vacateUserFromRoom(
        roomId,
        userId,
        { id: userId },
        "sweep-orphan-seat",
      );
      vacated += 1;
      console.log(`[sweep:orphan] vacated user=${userId} room=${roomId}`);
    } catch (err) {
      console.warn("[sweep:orphan] vacate failed:", err.message);
    }
  }
  if (vacated > 0) {
    console.log(`[sweep:orphan] done vacated=${vacated}`);
  }
}

let maintenanceOn = false;
function hasMaintenanceBypass(socket) {
  if (!MAINTENANCE_BYPASS_TOKEN) return false;
  const supplied =
    socket.handshake.auth?.mtoken || socket.handshake.query?.mtoken || "";
  return supplied === MAINTENANCE_BYPASS_TOKEN;
}
async function pollMaintenance() {
  try {
    const { rows: rows } = await db.query(
      `SELECT value FROM system_settings WHERE key = 'app_maintenance_mode' LIMIT 1`,
    );
    const next = String(rows[0]?.value || "false").trim() === "true";
    if (next === maintenanceOn) return;
    maintenanceOn = next;
    console.log(`[maintenance] ${next ? "ON — kicking sockets" : "OFF"}`);
    if (next) await kickAllExceptBypass();
  } catch (err) {
    console.warn("[maintenance] poll failed:", err.message);
  }
}
async function kickAllExceptBypass() {
  try {
    const sockets = await io.fetchSockets();
    let kicked = 0;
    for (const s of sockets) {
      if (hasMaintenanceBypass(s)) continue;
      s.disconnect(true);
      kicked += 1;
    }
    console.log(`[maintenance] kicked=${kicked}`);
  } catch (err) {
    console.warn("[maintenance] kick failed:", err.message);
  }
}
pollMaintenance();
setInterval(pollMaintenance, MAINTENANCE_POLL_MS).unref();
io.use(async (socket, next) => {
  try {
    if (maintenanceOn && !hasMaintenanceBypass(socket)) {
      return next(new Error("maintenance"));
    }
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.query?.token ||
      (socket.handshake.headers.authorization || "").replace(/^Bearer\s+/i, "");
    const payload = await verifyToken(token);
    if (payload?.sub) {
      socket.data.userId = String(payload.sub);
      socket.data.role = payload.role || "authenticated";
      socket.data.voiceOpen =
        VOICE_OPEN_TOKENS_ON && socket.handshake.auth?.voice_cap === "seat_token";
      return next();
    }
    if (ALLOW_ANON) {
      socket.data.userId = `anon:${socket.id}`;
      socket.data.role = "anon";
      return next();
    }
    return next(new Error("unauthorized"));
  } catch (err) {
    return next(err);
  }
});
io.on("connection", (socket) => {
  console.log(`[ws] connect ${socket.id} user=${socket.data.userId}`);
  ensureSocketDiag(socket);
  noteSocketActivity(socket, "connect");
  const dmUserId = socket.data.userId;
  // Anonymous sockets join this room too, so userHasLiveSocket can answer for
  // them without scanning every socket. DM delivery still only targets real
  // user ids, so nothing is routed to an anon room.
  if (dmUserId) socket.join(userSocketRoom(dmUserId));
  if (dmUserId && !String(dmUserId).startsWith("anon:")) {
    socket.data.watching = new Set();
    console.log(`[dm] joined user room user=${dmUserId}`);
    markAppOnline(dmUserId).catch((e) =>
      console.warn("[presence] mark online failed:", e.message),
    );
  }
  if (socket.data.userId) {
    const userId = socket.data.userId;
    const pending = cancelGraceVacate(userId);
    const pendingRoom = pending?.roomId || null;
    (async () => {
      try {
        await new Promise((r) => setTimeout(r, 50));
        const socketRoom = socket.data.roomId
          ? String(socket.data.roomId)
          : null;
        const tracked = await state.getUserPresenceRoom(pubClient, userId);
        if (socketRoom) {
          if (pendingRoom && pendingRoom !== socketRoom) {
            console.log(
              `[ws] reconnect vacate stale grace user=${userId} ` +
                `pending=${pendingRoom} socketRoom=${socketRoom}`,
            );
            await vacateUserFromRoom(
              pendingRoom,
              userId,
              { id: userId },
              "reconnect-vacate-stale-grace",
              { socket_room: socketRoom },
            );
          }
          if (tracked && tracked !== socketRoom) {
            await vacateUserFromRoom(
              tracked,
              userId,
              { id: userId },
              "reconnect-vacate-other-tracked",
              { socket_room: socketRoom },
            );
          }
          await state.presenceJoin(
            pubClient,
            socketRoom,
            userId,
            { id: userId },
            SOFT_DISCONNECT_PRESENCE_TTL_SEC,
          );
          await socket.join(`room:${socketRoom}`);
          console.log(
            `[ws] presence held on reconnect user=${userId} room=${socketRoom}`,
          );
          return;
        }
        if (pendingRoom && tracked && pendingRoom !== tracked) {
          console.log(
            `[ws] reconnect skip hold (moved) user=${userId} ` +
              `pending=${pendingRoom} live=${tracked}`,
          );
          await vacateUserFromRoom(
            pendingRoom,
            userId,
            { id: userId },
            "reconnect-vacate-stale-pending",
            { live_room: tracked },
          );
          await state.presenceJoin(
            pubClient,
            tracked,
            userId,
            { id: userId },
            SOFT_DISCONNECT_PRESENCE_TTL_SEC,
          );
          await socket.join(`room:${tracked}`);
          socket.data.roomId = tracked;
          return;
        }
        const holdRoom = pendingRoom || tracked;
        if (!holdRoom) return;
        if (socket.data.roomId && String(socket.data.roomId) !== holdRoom) {
          console.log(
            `[ws] reconnect hold aborted (joined other) user=${userId} ` +
              `was=${holdRoom} now=${socket.data.roomId}`,
          );
          if (pendingRoom && pendingRoom !== String(socket.data.roomId)) {
            await vacateUserFromRoom(
              pendingRoom,
              userId,
              { id: userId },
              "reconnect-vacate-joined-other",
              { now_room: socket.data.roomId },
            );
          }
          return;
        }
        await state.presenceJoin(
          pubClient,
          holdRoom,
          userId,
          { id: userId },
          SOFT_DISCONNECT_PRESENCE_TTL_SEC,
        );
        await socket.join(`room:${holdRoom}`);
        if (!socket.data.roomId) socket.data.roomId = holdRoom;
        console.log(
          `[ws] presence held on reconnect user=${userId} room=${holdRoom}`,
        );
      } catch (err) {
        console.warn("[ws] reconnect presence hold failed:", err.message);
      }
    })();
  }
  socket.on("room:join", async (payload = {}, ack) => {
    const joinT0 = Date.now();
    try {
      const roomId = String(payload.roomId || "").trim();
      if (!roomId) return ackErr(ack, "roomId required");

      // Start filling the seat and meta caches before the kick lookup rather
      // than after it, so on a cold room the Postgres reads overlap instead of
      // queueing behind each other. It only fills a cache and never throws, so
      // running it for a user who turns out to be kicked costs nothing.
      const cachesWarm = warmRoomCaches(roomId);

      const kickUserId = String(
        (payload.user && payload.user.id) || socket.data.userId || "",
      ).trim();
      if (kickUserId && !kickUserId.startsWith("anon:")) {
        try {
          const kick = await db.getActiveRoomKick(roomId, kickUserId);
          if (kick) {
            return ackErr(ack, "kicked_from_room");
          }
        } catch (err) {
          console.warn("[room:join] kick check failed:", err.message);
        }
      }
      const joinKickMs = Date.now() - joinT0;

      const prevSocketRoom = String(socket.data.roomId || "").trim();
      if (prevSocketRoom && prevSocketRoom !== roomId) {
        try {
          await socket.leave(`room:${prevSocketRoom}`);
        } catch (err) {
          console.warn("[room:join] leave previous socket room:", err.message);
        }
      }
      await socket.join(`room:${roomId}`);
      socket.data.roomId = roomId;
      noteSocketActivity(socket, "room:join", { roomId: roomId });
      seatTrace("room:join", {
        userId: socket.data.userId,
        roomId: roomId,
        prev_room: prevSocketRoom || null,
        socketId: socket.id,
        snapshot_request: !!payload.snapshotRequest,
      });
      const user = payload.user || { id: socket.data.userId };
      const claimedId = String(user.id || "").trim();
      if (
        claimedId &&
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          claimedId,
        ) &&
        String(socket.data.userId || "").startsWith("anon:")
      ) {
        console.warn(
          `[presence] remapping ${socket.data.userId} -> ${claimedId}`,
        );
        // Move the socket's user room with it, otherwise userHasLiveSocket
        // would stop seeing this connection under its real id.
        const prevUserRoom = userSocketRoom(socket.data.userId);
        socket.data.userId = claimedId;
        try {
          await socket.leave(prevUserRoom);
          await socket.join(userSocketRoom(claimedId));
        } catch (err) {
          console.warn("[presence] remap user room:", err.message);
        }
      }
      user.id = socket.data.userId;
      emitCachedSeats(socket, roomId);
      // The cache warm started at the top of this handler runs alongside the
      // presence bookkeeping below. On a cold Redis it reads Postgres, and that
      // read used to start only after three awaited presence writes had
      // finished — which is where a first join into an idle room lost most of
      // its seconds. buildSnapshot still runs after presenceJoin so the
      // snapshot's presence list includes the joiner; by then the warm has
      // landed in Redis, so it is a cache hit and the contents are unchanged.
      const joinPresenceT0 = Date.now();
      if (prevSocketRoom && prevSocketRoom !== roomId) {
        await vacateUserFromRoom(
          prevSocketRoom,
          socket.data.userId,
          user,
          "room:join-leave-previous",
          { join_room: roomId, socketId: socket.id },
        );
      }
      await ensureSingleRoomPresence(socket.data.userId, roomId, user);
      cancelGraceVacate(socket.data.userId);
      await state.presenceJoin(pubClient, roomId, socket.data.userId, user);
      console.log(
        `[presence] room:join user=${socket.data.userId} room=${roomId}` +
          (prevSocketRoom && prevSocketRoom !== roomId
            ? ` (left ${prevSocketRoom})`
            : ""),
      );
      const joinPresenceMs = Date.now() - joinPresenceT0;
      const joinSnapshotT0 = Date.now();
      await cachesWarm;
      const snapshot = await buildSnapshot(roomId);
      bumpSeatEmit(socket);
      socket.emit("room:snapshot", { room_id: roomId, ...snapshot });
      const joinSnapshotMs = Date.now() - joinSnapshotT0;
      const joinPayload = {
        event_id: payload.event_id || uuidv4(),
        room_id: roomId,
        actor_user_id: socket.data.userId,
        action: "join",
        user: user,
        snapshot_request: !!payload.snapshotRequest,
        car_svga: payload.carSvga,
        patti_svga: payload.pattiSvga,
        patti_url: payload.pattiUrl,
      };
      await emitRoomEvent(
        roomId,
        "room_presence",
        joinPayload,
        socket.data.userId,
      );
      // The voice session rides along in the ack. Signing is local, and the
      // seat state is already in the snapshot we just built, so this costs
      // nothing — and it saves the client a separate voice:token round trip
      // before it can connect to LiveKit and hear anybody.
      const voice = await voiceSessionFromSnapshot(
        snapshot,
        socket.data.userId,
        user,
        roomId,
        !!socket.data.voiceOpen,
      );
      ackOk(ack, {
        room: `room:${roomId}`,
        seq: snapshot.seq,
        ...(voice ? { voice: voice } : {}),
      });
      // One line per join with where the time went, so a slow room open can be
      // traced to a stage: kick is the ban lookup, presence is leaving other
      // rooms plus the presence writes, snapshot is the cache fill and read.
      console.log(
        `[room:join] ok room=${roomId} kick=${joinKickMs}ms ` +
          `presence=${joinPresenceMs}ms snapshot=${joinSnapshotMs}ms ` +
          `total=${Date.now() - joinT0}ms`,
      );
      // Durable membership bookkeeping runs after the joiner already has their
      // snapshot. It used to sit in front of the snapshot, so every join waited
      // on a room read, a member upsert and a presence RPC before one seat
      // appeared on screen.
      if (!String(socket.data.userId).startsWith("anon:")) {
        void persistRoomMembership(roomId, socket.data.userId);
      }
      scheduleReportPresence(roomId);
    } catch (err) {
      console.error("[room:join]", err.message);
      ackErr(ack, err.message);
    }
  });
  socket.on("room:leave", async (payload = {}, ack) => {
    try {
      noteSocketActivity(socket, "room:leave");
      const roomId = String(payload.roomId || socket.data.roomId || "").trim();
      if (!roomId) return ackErr(ack, "roomId required");
      const userId = socket.data.userId;
      const { seat_index: leftSeatIndex } = await vacateUserFromRoom(
        roomId,
        userId,
        payload.user || { id: userId },
        "room:leave",
        { socketId: socket.id },
      );
      cancelGraceVacate(userId);
      await socket.leave(`room:${roomId}`);
      if (socket.data.roomId === roomId) socket.data.roomId = null;
      ackOk(ack, { seat_index: leftSeatIndex });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("presence:heartbeat", async (payload = {}, ack) => {
    try {
      noteSocketActivity(socket, "presence:heartbeat");
      const roomId = String(payload.roomId || socket.data.roomId || "").trim();
      if (!roomId) return ackErr(ack, "roomId required");
      const userId = socket.data.userId;
      const user = payload.user || { id: userId };
      const tracked = await state.getUserPresenceRoom(pubClient, userId);
      if (tracked && tracked !== roomId) {
        const pending = pendingGraceVacates.get(userId);
        if (pending?.roomId === roomId) {
          cancelGraceVacate(userId);
        }
        if (
          socket.data.roomId === roomId &&
          socket.rooms.has(`room:${roomId}`)
        ) {
          seatTrace("heartbeat-retrack", {
            userId: userId,
            beat_room: roomId,
            stale_room: tracked,
            socketId: socket.id,
          });
          cancelGraceVacate(userId);
          await state.presenceHeartbeat(pubClient, roomId, userId, user);
          await ensureSingleRoomPresence(userId, roomId, user);
          await socket.join(`room:${roomId}`);
          socket.data.roomId = roomId;
          return ackOk(ack, { retracked: true, live_room: roomId });
        }
        if (shouldSkipStaleVacate(userId, roomId)) {
          seatTrace("heartbeat-stale-debounced", {
            userId: userId,
            beat_room: roomId,
            live_room: tracked,
            socketId: socket.id,
          });
          return ackOk(ack, {
            ignored: true,
            live_room: tracked,
            debounced: true,
          });
        }
        console.log(
          `[presence] ignore stale heartbeat user=${userId} ` +
            `beat=${roomId} live=${tracked}`,
        );
        try {
          const result = await vacateUserFromRoom(
            roomId,
            userId,
            user,
            "stale-heartbeat",
            { live_room: tracked, socketId: socket.id },
          );
          if (result?.skipped) {
            console.log(
              `[presence] stale vacate noop user=${userId} room=${roomId}`,
            );
          }
        } catch (err) {
          console.warn("[presence] stale-room vacate failed:", err.message);
        }
        return ackOk(ack, { ignored: true, live_room: tracked });
      }
      cancelGraceVacate(userId);
      await state.presenceHeartbeat(pubClient, roomId, userId, user);
      await ensureSingleRoomPresence(userId, roomId, user);
      await socket.join(`room:${roomId}`);
      socket.data.roomId = roomId;
      ackOk(ack);
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("room:snapshot", async (payload = {}, ack) => {
    try {
      const roomId = String(payload.roomId || socket.data.roomId || "").trim();
      if (!roomId) return ackErr(ack, "roomId required");
      emitCachedSeats(socket, roomId);
      const snapshot = await buildSnapshot(roomId);
      bumpSeatEmit(socket);
      ackOk(ack, snapshot);
      socket.emit("room:snapshot", { room_id: roomId, ...snapshot });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  // seat:claim is unchanged. seat:sit is the same write plus a publish token in
  // the same ack, so taking the mic costs one round trip instead of claim →
  // voice:token → wait for permission → reconnect.
  socket.on("seat:claim", (payload = {}, ack) =>
    handleSeatClaim(socket, payload, ack, { withVoice: false }),
  );
  socket.on("seat:sit", (payload = {}, ack) =>
    handleSeatClaim(socket, payload, ack, { withVoice: true }),
  );
  socket.on("seat:prepare", async (payload = {}, ack) => {
    try {
      noteSocketActivity(socket, "seat:prepare");
      const roomId = String(payload.roomId || "").trim();
      const seatIndex = Number(payload.seatIndex);
      if (!roomId || Number.isNaN(seatIndex)) {
        return ackErr(ack, "roomId and seatIndex required");
      }
      const userId = socket.data.userId;
      if (!userId || String(userId).startsWith("anon:")) {
        return ackErr(ack, "unauthorized");
      }
      if (!socket.rooms.has(`room:${roomId}`)) {
        return ackErr(ack, "not_in_room");
      }
      const prepT0 = Date.now();
      const seats = await state.getSeatsSnapshot(pubClient, roomId);
      const prepSeatsMs = Date.now() - prepT0;
      const seat = Array.isArray(seats)
        ? seats.find((s) => seatOccupantIndex(s) === seatIndex)
        : null;
      if (seat?.is_locked) return ackErr(ack, "seat_locked");
      const holder = seatOccupantId(seat);
      if (holder && holder !== String(userId)) {
        return ackErr(ack, "seat_unavailable");
      }
      const prepSyncT0 = Date.now();
      // Holder of an open token: the microphone grant is already in the token,
      // so there is nothing to wait for. Reply now; the prepared marker below is
      // what lets the webhook tell this publish from an unauthorised one.
      const openToken = !!socket.data.voiceOpen && isOpenVoice(roomId, userId);
      let perm = "token";
      if (!openToken) {
        perm = await orbitVoice.syncLivePermission({
          userId: userId,
          roomId: roomId,
          canPublish: true,
        });
      } else if (openVoiceRevoked.delete(openVoiceKey(roomId, userId))) {
        void orbitVoice.syncLivePermission({
          userId: userId,
          roomId: roomId,
          canPublish: true,
        });
      }
      console.log(
        `[seat:prepare] ok perm=${perm} seats=${prepSeatsMs}ms sync=${Date.now() - prepSyncT0}ms total=${Date.now() - prepT0}ms`,
      );
      clearPreparedGrant(roomId, userId);
      const timer = setTimeout(async () => {
        preparedGrants.delete(`${roomId}:${userId}`);
        const seated = await redisSeatIndexForUser(roomId, userId);
        if (seated == null) revokeLivePublish(roomId, userId, "prepare_expired");
      }, PREPARE_GRANT_TTL_MS);
      if (typeof timer.unref === "function") timer.unref();
      preparedGrants.set(`${roomId}:${userId}`, timer);
      // revokes_on_leave tells the client this gateway takes publish back on
      // seat leave, so it can stay connected instead of reconnecting.
      ackOk(ack, { perm: perm, revokes_on_leave: true });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("seat:leave", async (payload = {}, ack) => {
    try {
      noteSocketActivity(socket, "seat:leave");
      const roomId = String(payload.roomId || "").trim();
      const seatIndex = Number(payload.seatIndex ?? payload.seat_index ?? -1);
      if (!roomId) return ackErr(ack, "roomId required");
      const actorUserId = socket.data.userId;
      const eventId = payload.event_id || uuidv4();
      const targetUserId = await db.resolveSeatTargetUserId({
        roomId: roomId,
        actorUserId: actorUserId,
        requestedUserId:
          payload.user_id || payload.targetUserId || payload.userId || null,
      });
      const leftSeatIndex = await db.seatLeave({
        roomId: roomId,
        userId: targetUserId,
        seatRowId: payload.seatRowId || payload.seat_row_id,
      });
      const resolvedSeatIndex =
        Number.isInteger(seatIndex) && seatIndex >= 0
          ? seatIndex
          : leftSeatIndex != null
            ? leftSeatIndex
            : -1;
      await refreshSeatsCache(roomId);
      revokeLivePublish(roomId, targetUserId, "seat_leave");
      const data = {
        event_id: eventId,
        room_id: roomId,
        actor_user_id: actorUserId,
        action: "leave",
        seat_index: resolvedSeatIndex,
        user_id: targetUserId,
        user: payload.user || { id: targetUserId },
      };
      const envelope = await emitRoomEvent(
        roomId,
        "room_seat",
        data,
        actorUserId,
      );
      seatTrace("seat:leave", {
        actor_user_id: actorUserId,
        target_user_id: targetUserId,
        kicked: actorUserId !== targetUserId,
        roomId: roomId,
        seat_index: resolvedSeatIndex,
        requested_seat_index: seatIndex,
        socketId: socket.id,
      });
      ackOk(ack, { event_id: envelope.event_id });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("seat:mute", async (payload = {}, ack) => {
    try {
      const roomId = String(payload.roomId || "").trim();
      const seatIndex = Number(payload.seatIndex ?? payload.seat_index);
      const isMuted = !!(payload.isMuted ?? payload.is_muted);
      if (!roomId) {
        return ackErr(ack, "roomId required");
      }
      const actorUserId = socket.data.userId;
      const targetUserId = await db.resolveSeatTargetUserId({
        roomId: roomId,
        actorUserId: actorUserId,
        requestedUserId:
          payload.user_id || payload.targetUserId || payload.userId || null,
      });
      const seat = await db.seatMute({
        roomId: roomId,
        userId: targetUserId,
        seatIndex: Number.isNaN(seatIndex) ? null : seatIndex,
        isMuted: isMuted,
      });
      await refreshSeatsCache(roomId);
      const resolvedIndex =
        seat?.seat_index != null ? Number(seat.seat_index) : seatIndex;
      const data = {
        event_id: payload.event_id || uuidv4(),
        room_id: roomId,
        actor_user_id: actorUserId,
        action: "mute",
        seat_index: resolvedIndex,
        user_id: targetUserId,
        is_muted: isMuted,
      };
      const envelope = await emitRoomEvent(
        roomId,
        "room_seat",
        data,
        actorUserId,
      );
      ackOk(ack, {
        event_id: envelope.event_id,
        is_muted: isMuted,
        seat_index: resolvedIndex,
        seat: seat,
      });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("seat:lock", async (payload = {}, ack) => {
    try {
      const roomId = String(payload.roomId || "").trim();
      const seatIndex = Number(payload.seatIndex ?? payload.seat_index);
      const isLocked = !!(payload.isLocked ?? payload.is_locked);
      if (!roomId || Number.isNaN(seatIndex)) {
        return ackErr(ack, "roomId and seatIndex required");
      }
      await db.seatLock({
        roomId: roomId,
        seatIndex: seatIndex,
        isLocked: isLocked,
      });
      await refreshSeatsCache(roomId);
      const data = {
        event_id: payload.event_id || uuidv4(),
        room_id: roomId,
        actor_user_id: socket.data.userId,
        action: isLocked ? "lock" : "unlock",
        seat_index: seatIndex,
        is_locked: isLocked,
      };
      const envelope = await emitRoomEvent(
        roomId,
        "room_seat",
        data,
        socket.data.userId,
      );
      ackOk(ack, { event_id: envelope.event_id });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("chat:send", async (payload = {}, ack) => {
    try {
      if (isAnonUser(socket.data.userId)) {
        return ackErr(ack, "authenticated users only");
      }
      const roomId = String(payload.roomId || "").trim();
      const content = String(payload.content || "").trim();
      if (!roomId || !content)
        return ackErr(ack, "roomId and content required");
      const eventId = payload.event_id || uuidv4();
      const metadata =
        payload.metadata && typeof payload.metadata === "object"
          ? payload.metadata
          : {};
      const user = await db.loadUserPublic(socket.data.userId);
      const row = await db.insertChat({
        roomId: roomId,
        userId: socket.data.userId,
        content: content,
        eventId: eventId,
        type: payload.type || "chat",
        metadata: metadata,
      });
      const data = {
        event_id: eventId,
        room_id: roomId,
        actor_user_id: socket.data.userId,
        user_id: socket.data.userId,
        content: content,
        type: payload.type || "chat",
        metadata: row?.metadata || { ...metadata, event_id: eventId },
        user: user,
        created_at: row?.created_at || new Date().toISOString(),
        sent_at: row?.created_at || new Date().toISOString(),
        id: row?.id,
      };
      const envelope = await emitRoomEvent(
        roomId,
        "room_chat",
        data,
        socket.data.userId,
      );
      ackOk(ack, { event_id: envelope.event_id, message: row });
    } catch (err) {
      console.error("[chat:send]", err.message);
      ackErr(ack, err.message);
    }
  });
  async function processGiftNotify(socket, payload = {}, ack) {
    try {
      if (isAnonUser(socket.data.userId)) {
        return ackErr(ack, "authenticated users only");
      }
      const roomId = String(payload.roomId || "").trim();
      if (!roomId) return ackErr(ack, "roomId required");
      const targetIds = Array.isArray(payload.target_ids)
        ? payload.target_ids.map((id) => String(id)).filter(Boolean)
        : [];
      const messages = Array.isArray(payload.messages) ? payload.messages : [];
      const data = {
        event_id: payload.event_id || uuidv4(),
        room_id: roomId,
        actor_user_id: socket.data.userId,
        message: payload.message || {},
        ...(messages.length ? { messages: messages } : {}),
        seat_gift_delta: payload.seat_gift_delta,
        seat_gift_deltas: payload.seat_gift_deltas,
        target_ids: targetIds,
        animation_batch_id:
          payload.animation_batch_id || payload.event_id || null,
        sender_id: socket.data.userId,
        gift_icon: payload.gift_icon || payload.giftIcon || "",
        quantity: Math.min(Math.max(Number(payload.quantity) || 1, 1), 9999),
        is_full_screen: !!(payload.is_full_screen ?? payload.isFullScreen),
        svga_url: payload.svga_url || payload.svgaUrl || "",
        show_duration_ms:
          payload.show_duration_ms != null &&
          Number.isFinite(Number(payload.show_duration_ms))
          ? Math.max(0, Math.min(60000, Number(payload.show_duration_ms)))
          : undefined,
        lucky_engine: payload.lucky_engine || undefined,
        settled_on_gateway: payload.settled_on_gateway === true,
        sent_at: new Date().toISOString(),
      };
      // Seat totals + room_gift emit FIRST. Lucky rolls used to run before
      // fanout and turned every gift into hundreds of ms of Redis work while
      // the whole room waited. Peers must see the gift in ms; wins patch later.
      const deltas = {};
      if (
        payload.seat_gift_delta &&
        typeof payload.seat_gift_delta === "object"
      ) {
        const hasUserKey =
          payload.seat_gift_delta.user_id != null ||
          payload.seat_gift_delta.userId != null;
        if (hasUserKey) {
          const uid = String(
            payload.seat_gift_delta.user_id ||
              payload.seat_gift_delta.userId ||
              "",
          );
          const amount = Math.min(
            Math.max(Number(payload.seat_gift_delta.amount) || 0, 0),
            5e6,
          );
          if (uid && amount > 0) deltas[uid] = (deltas[uid] || 0) + amount;
        } else {
          for (const [uidRaw, amountRaw] of Object.entries(
            payload.seat_gift_delta,
          )) {
            const uid = String(uidRaw || "");
            const amount = Math.min(Math.max(Number(amountRaw) || 0, 0), 5e6);
            if (uid && amount > 0) deltas[uid] = (deltas[uid] || 0) + amount;
          }
        }
      }
      if (Array.isArray(payload.seat_gift_deltas)) {
        for (const row of payload.seat_gift_deltas) {
          if (!row || typeof row !== "object") continue;
          const uid = String(row.user_id || row.userId || "");
          const amount = Math.min(Math.max(Number(row.amount) || 0, 0), 5e6);
          if (uid && amount > 0) deltas[uid] = (deltas[uid] || 0) + amount;
        }
      }
      if (
        !Object.keys(deltas).length &&
        data.message &&
        typeof data.message === "object"
      ) {
        const meta = data.message.metadata || {};
        const targetId = String(meta.target_id || "");
        const charm =
          Number(meta.charm_credit ?? meta.charm_amount) ||
          Number(meta.host_received ?? meta.host_share) ||
          0;
        if (targetId && charm > 0) deltas[targetId] = charm;
      }
      let seatGiftTotals = {};
      try {
        seatGiftTotals = await state.incrSeatGiftTotals(
          pubClient,
          roomId,
          deltas,
        );
      } catch (err) {
        console.warn("[seat_gifts] incr failed:", err.message);
      }
      data.seat_gift_totals = seatGiftTotals;
      if (Object.keys(deltas).length) {
        data.seat_gift_delta = deltas;
      }
      const envelope = await emitRoomEvent(
        roomId,
        "room_gift",
        data,
        socket.data.userId,
      );
      try {
        const bigGift = extractBigGiftPattiFromGiftMessage(
          data.message,
          socket.data.userId,
          roomId,
        );
        if (bigGift) emitGlobalBigGift(bigGift, socket.data.userId);
      } catch (err) {
        console.warn("[global:big_gift] gift extract failed:", err.message);
      }
      ackOk(ack, {
        event_id: envelope.event_id,
        seat_gift_totals: seatGiftTotals,
        lucky_wins: [],
      });

      shutdown
        .track(
          (async () => {
            const gatewayWins = [];
            try {
              const rolls = luckyEngine.extractGatewayRolls(
                payload,
                socket.data.userId,
              );
              const byVariant = new Map();
              for (const rollReq of rolls) {
                const key =
                  rollReq.variant === "lucky_pro" ? "lucky_pro" : "lucky";
                if (!byVariant.has(key)) byVariant.set(key, []);
                byVariant.get(key).push(rollReq);
              }
              for (const group of byVariant.values()) {
                const win = await luckyEngine.rollBatch(
                  pubClient,
                  group.map((rollReq) => ({
                    variant: rollReq.variant,
                    senderId: rollReq.senderId || socket.data.userId,
                    receiverId: rollReq.receiverId,
                    giftId: rollReq.giftId,
                    giftLogId: rollReq.giftLogId,
                    totalCost: rollReq.totalCost,
                    unitPrice: rollReq.unitPrice,
                    quantity: rollReq.quantity,
                  })),
                );
                if (!win?.bonus_won) continue;
                gatewayWins.push(win);
                shutdown
                  .track(luckyEngine.creditOrEnqueue(pubClient, win))
                  .catch((err) => {
                    console.warn(
                      "[lucky_engine] credit enqueue:",
                      err.message,
                    );
                  });
                const senderProfile = await resolveLuckySenderProfile({
                  data: data,
                  win: win,
                  socket: socket,
                });
                const winPayload = {
                  event_id: `lucky_win_${win.gift_log_id}`,
                  gift_log_id: win.gift_log_id,
                  room_id: roomId,
                  user_id: win.sender_id,
                  receiver_id: win.receiver_id,
                  gift_id: win.gift_id,
                  reward_coins: win.bonus_coins,
                  bonus_coins: win.bonus_coins,
                  bonus_multiplier: win.bonus_multiplier,
                  multiplier_tier: `x${win.bonus_multiplier}`,
                  variant: win.variant,
                  bonus_tier: win.bonus_tier,
                  batch_recipients: win.batch_recipients || group.length,
                  batch_spend: win.batch_spend || null,
                  animation_batch_id: data.animation_batch_id,
                  username: senderProfile.username,
                  avatar_url: senderProfile.avatar_url,
                  sender_username: senderProfile.username,
                  sender_avatar: senderProfile.avatar_url,
                  gift_name:
                    senderProfile.gift_name ||
                    (data.message &&
                      data.message.metadata &&
                      data.message.metadata.gift_name) ||
                    null,
                  gift_icon: data.gift_icon || null,
                  created_at: new Date().toISOString(),
                };
                const luckyEnvelope = {
                  event_id: winPayload.event_id,
                  event: "lucky_win",
                  user_id: socket.data.userId,
                  ts: Date.now(),
                  data: winPayload,
                };
                socket.emit("lucky:win", luckyEnvelope);
                io.to(`room:${roomId}`).emit("lucky:win", luckyEnvelope);
                try {
                  emitGlobalWin(
                    {
                      id: winPayload.event_id,
                      event_id: winPayload.event_id,
                      user_id: win.sender_id,
                      username: senderProfile.username,
                      avatar_url: senderProfile.avatar_url,
                      source_label: senderProfile.gift_name || "Lucky Gift",
                      reward_coins: win.bonus_coins,
                      bonus_multiplier: win.bonus_multiplier,
                      multiplier_tier: `x${win.bonus_multiplier}`,
                      variant: win.variant,
                      gift_icon: data.gift_icon || null,
                      room_id: roomId,
                      created_at: winPayload.created_at,
                    },
                    socket.data.userId,
                  );
                } catch (err) {
                  console.warn("[lucky:win] global emit failed:", err.message);
                }
                console.log(
                  `[lucky_engine] win room=${roomId} user=${win.sender_id} ` +
                    `name=${senderProfile.username} coins=${win.bonus_coins} ` +
                    `x${win.bonus_multiplier} variant=${win.variant}`,
                );
              }
            } catch (err) {
              console.warn("[lucky_engine] roll failed:", err.message);
            }
            if (!gatewayWins.length) {
              try {
                const win = extractLuckyWinFromGiftMessage(
                  data.message,
                  socket.data.userId,
                  roomId,
                );
                if (win) emitGlobalWin(win, socket.data.userId);
              } catch (err) {
                console.warn("[global:win] gift extract failed:", err.message);
              }
            }
          })(),
        )
        .catch((err) => {
          console.warn("[lucky_engine] post-emit failed:", err.message);
        });
    } catch (err) {
      ackErr(ack, err.message);
    }
  }
  socket.on("gift:notify", (payload = {}, ack) => {
    processGiftNotify(socket, payload, ack);
  });
  async function handleGiftSend(payload = {}, ack, queuedAt = Date.now()) {
    const startedAt = Date.now();
    try {
      const roomId = String(payload.roomId || payload.room_id || "").trim();
      const giftId = String(payload.gift_id || payload.giftId || "").trim();
      const animationBatchId = String(
        payload.animation_batch_id || payload.animationBatchId || uuidv4(),
      ).trim();
      const clientOpId = String(
        payload.client_op_id || payload.clientOpId || animationBatchId,
      ).trim();
      // Same ceiling gift:notify applies; clients merge combo taps up to it.
      const quantity = Math.min(
        9999,
        Math.max(1, Math.trunc(Number(payload.quantity) || 1)),
      );
      const rawTargets = Array.isArray(payload.target_ids)
        ? payload.target_ids
        : Array.isArray(payload.targetIds)
          ? payload.targetIds
          : [];
      const targetIds = [
        ...new Set(
          rawTargets.map((id) => String(id || "").trim()).filter(Boolean),
        ),
      ];
      if (!roomId) return ackErr(ack, "roomId required");
      if (!giftId) return ackErr(ack, "gift_id required");
      if (!targetIds.length) return ackErr(ack, "target_ids required");
      if (!socket.data.userId) return ackErr(ack, "not authenticated");
      if (isAnonUser(socket.data.userId)) {
        return ackErr(ack, "authenticated users only");
      }
      const claimed = await pubClient.set(
        `gift:send:done:${clientOpId}`,
        "1",
        "EX",
        300,
        "NX",
      );
      if (claimed !== "OK") {
        console.log(`[gift] send duplicate op=${clientOpId} room=${roomId}`);
        let seatGiftTotals = {};
        try {
          seatGiftTotals = await state.getSeatGiftTotals(pubClient, roomId);
        } catch (_) {}
        return ackOk(ack, {
          duplicate: true,
          settled_on_gateway: true,
          client_op_id: clientOpId,
          animation_batch_id: animationBatchId,
          seat_gift_totals: seatGiftTotals,
          outcomes: [],
          lucky_wins: [],
        });
      }
      const gift = await giftSettle.loadGift(giftId);
      if (!gift) {
        await pubClient.del(`gift:send:done:${clientOpId}`);
        return ackErr(ack, "Gift not found or inactive");
      }
      // Every category settles here, not just lucky. The old split sent normal
      // gifts as a Supabase RPC from the phone followed by a second socket call
      // to broadcast — two sequential round trips on the sender's connection
      // while the whole room waited. One socket call settles next to Postgres
      // and broadcasts before the ack. Lucky rolls stay safe: they are gated on
      // the is_lucky metadata the SQL returns, not on reaching this handler.
      const settleT0 = Date.now();
      const settle = await giftSettle.settleGifts({
        senderId: socket.data.userId,
        receiverIds: targetIds,
        giftId: giftId,
        roomId: roomId,
        quantity: quantity,
      });
      const settleMs = Date.now() - settleT0;
      if (!settle.success) {
        await pubClient.del(`gift:send:done:${clientOpId}`);
        return ackErr(ack, settle.message || "Failed to send gift");
      }
      const built = await giftSettle.buildNotifyFromSettle({
        roomId: roomId,
        senderId: socket.data.userId,
        senderUsername: socket.data.username || payload.sender_username,
        senderAvatar: socket.data.avatar_url || payload.sender_avatar,
        gift: gift,
        quantity: quantity,
        animationBatchId: animationBatchId,
        clientOpId: clientOpId,
        settle: settle,
      });
      if (!built.successfulTargets.length) {
        await pubClient.del(`gift:send:done:${clientOpId}`);
        const firstFail = built.outcomes.find((o) => !o.success);
        return ackErr(
          ack,
          firstFail?.error_message || settle.message || "Failed to send gift",
        );
      }
      giftSettle
        .persistGiftMessages(built.notifyPayload.messages)
        .catch(() => {});
      // queue = waiting behind this sender's earlier gifts, settle = the
      // send_gift(s) SQL, pre = idempotency claim + gift lookup + build.
      console.log(
        `[gift] send room=${roomId} from=${socket.data.userId} ` +
          `targets=${built.successfulTargets.length} ` +
          `batch=${animationBatchId} op=${clientOpId} ` +
          `queue=${startedAt - queuedAt}ms settle=${settleMs}ms ` +
          `pre=${Date.now() - startedAt - settleMs}ms`,
      );
      await processGiftNotify(
        socket,
        { roomId: roomId, ...built.notifyPayload },
        (resp) => {
          if (typeof ack !== "function") return;
          if (resp && resp.ok === false) return ack(resp);
          ack({
            ...(resp || { ok: true }),
            settled_on_gateway: true,
            client_op_id: clientOpId,
            animation_batch_id: animationBatchId,
            outcomes: built.outcomes,
            gift: {
              id: gift.id,
              name: gift.name,
              price_coins: gift.price_coins,
              icon_url: gift.icon_url,
              svga_url: gift.svga_url,
              is_full_screen: gift.is_full_screen === true,
              show_duration_ms: built.notifyPayload.show_duration_ms,
              category_name: gift.category_name,
            },
          });
        },
      );
    } catch (err) {
      console.warn("[gift:send] failed:", err.message);
      ackErr(ack, err.message);
    }
  }
  socket.on("gift:send", (payload = {}, ack) => {
    if (giftGlobalInflight >= GIFT_GLOBAL_INFLIGHT_MAX) {
      return ackErr(ack, "Too many gifts at once - please wait a moment");
    }
    giftGlobalInflight += 1;
    const queuedAt = Date.now();
    giftSendQueue
      .run(socket.data.userId || socket.id, () =>
        handleGiftSend(payload, ack, queuedAt),
      )
      .catch((err) => {
        if (err && err.code === "QUEUE_FULL") {
          ackErr(ack, "Too many gifts at once - please wait a moment");
        }
      })
      .finally(() => {
        giftGlobalInflight = Math.max(0, giftGlobalInflight - 1);
      });
  });
  socket.on("win:notify", async (payload = {}, ack) => {
    try {
      if (isAnonUser(socket.data.userId)) {
        return ackErr(ack, "authenticated users only");
      }
      const rewardCoins = Math.min(
        Math.max(Number(payload.reward_coins) || 0, 0),
        5e7,
      );
      if (rewardCoins <= 0) return ackErr(ack, "reward_coins required");
      const multiplier = Math.min(
        Math.max(Number(payload.bonus_multiplier) || 1, 1),
        999999,
      );
      const tierRaw =
        payload.multiplier_tier != null
          ? String(payload.multiplier_tier).slice(0, 32)
          : `x${multiplier}`;
      const profile = await db.loadUserPublic(socket.data.userId);
      const win = {
        id: String(payload.id || payload.event_id || uuidv4()),
        event_id: payload.event_id || undefined,
        user_id: String(socket.data.userId),
        username: String(profile.username || "User"),
        avatar_url:
          profile.avatar_url != null ? String(profile.avatar_url) : null,
        source_label: String(
          payload.source_label || payload.sourceLabel || "Game",
        ).slice(0, 64),
        reward_coins: rewardCoins,
        bonus_multiplier: multiplier,
        multiplier_tier: tierRaw,
        variant: String(payload.variant || "game").slice(0, 32),
        created_at: new Date().toISOString(),
        room_id: payload.roomId || payload.room_id || undefined,
      };
      const envelope = emitGlobalWin(win, socket.data.userId);
      ackOk(ack, { event_id: envelope.event_id });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("game:join", async (payload = {}, ack) => {
    try {
      const slug = gameState.canonicalSlug(payload.slug || payload.gameSlug);
      if (!slug) return ackErr(ack, "slug required");
      const prev = socket.data.gameSlug
        ? gameState.canonicalSlug(socket.data.gameSlug)
        : null;
      if (prev && prev !== slug) {
        try {
          await socket.leave(gameState.socketRoom(prev));
        } catch (_) {}
      }
      await socket.join(gameState.socketRoom(slug));
      socket.data.gameSlug = slug;
      let snapshot = await gameState.getLiveSnapshot(pubClient, slug);
      if (!snapshot) {
        snapshot = {
          slug: slug,
          status: null,
          round_id: null,
          seq: 0,
          server_now: new Date().toISOString(),
          empty: true,
        };
      } else {
        snapshot = { ...snapshot, server_now: new Date().toISOString() };
      }
      socket.emit("game:snapshot", snapshot);
      ackOk(ack, {
        room: gameState.socketRoom(slug),
        slug: slug,
        seq: snapshot.seq || 0,
      });
    } catch (err) {
      console.error("[game:join]", err.message);
      ackErr(ack, err.message);
    }
  });
  socket.on("game:leave", async (payload = {}, ack) => {
    try {
      const slug = gameState.canonicalSlug(
        payload.slug || payload.gameSlug || socket.data.gameSlug,
      );
      if (!slug) return ackErr(ack, "slug required");
      await socket.leave(gameState.socketRoom(slug));
      if (socket.data.gameSlug === slug) socket.data.gameSlug = null;
      ackOk(ack, { left: slug });
    } catch (err) {
      console.error("[game:leave]", err.message);
      ackErr(ack, err.message);
    }
  });
  socket.on("activity:report", async (payload = {}, ack) => {
    try {
      const roomId = String(payload.roomId || socket.data.roomId || "").trim();
      if (!roomId) return ackErr(ack, "roomId required");
      await db.reportActivity(roomId, !!payload.isOnMic);
      ackOk(ack);
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("room:publish", async (payload = {}, ack) => {
    try {
      const roomId = String(payload.roomId || "").trim();
      const eventName = String(payload.event || payload.eventName || "").trim();
      const rawData =
        payload.data && typeof payload.data === "object" ? payload.data : {};
      if (!roomId || !eventName) {
        return ackErr(ack, "roomId and event required");
      }
      const data = { ...rawData };
      const eventId = data.event_id || uuidv4();
      data.event_id = eventId;
      if (!data.room_id) data.room_id = roomId;
      if (!data.actor_user_id) data.actor_user_id = socket.data.userId;
      if (eventName === "room_meta" && payload.persistMeta) {
        try {
          const meta = await db.loadRoomMeta(roomId);
          await state.setMetaSnapshot(pubClient, roomId, meta);
        } catch (_) {}
      }
      if (eventName === "youtube_state" || eventName === "shared_audio_state") {
        const {
          event_id: _eid,
          room_id: _rid,
          actor_user_id: _aid,
          ...mediaState
        } = data;
        if (eventName === "youtube_state") {
          await state.setYoutubeState(pubClient, roomId, mediaState);
        } else {
          await state.setSharedAudioState(pubClient, roomId, mediaState);
        }
      }
      const envelope = await emitRoomEvent(
        roomId,
        eventName,
        data,
        socket.data.userId,
      );
      ackOk(ack, { event_id: envelope.event_id, seq: envelope.seq });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("dm:send", async (payload = {}, ack) => {
    const t0 = Date.now();
    try {
      const userId = socket.data.userId;
      if (!userId || String(userId).startsWith("anon:")) {
        return ackErr(ack, "unauthorized");
      }
      const conversationId = String(
        payload.conversationId || payload.conversation_id || "",
      ).trim();
      if (!conversationId) return ackErr(ack, "conversationId required");
      const messageType = String(
        payload.type || payload.message_type || "text",
      ).trim();
      const content = payload.content != null ? String(payload.content) : null;
      const mediaUrl =
        payload.mediaUrl || payload.media_url
          ? String(payload.mediaUrl || payload.media_url)
          : null;
      const metadata =
        payload.metadata && typeof payload.metadata === "object"
          ? payload.metadata
          : {};
      const eventId = payload.event_id || metadata.temp_id || uuidv4();
      if (!mediaUrl && !(content && content.trim()) && messageType === "text") {
        return ackErr(ack, "content or mediaUrl required");
      }
      const conv = await db.getConversationForUser(conversationId, userId);
      if (!conv) return ackErr(ack, "conversation not found");
      if (conv.status === "blocked") {
        return ackErr(ack, "conversation blocked");
      }
      const { row: row, duplicate: duplicate } = await db.insertDmMessage({
        conversationId: conversationId,
        senderId: userId,
        content: content,
        messageType: messageType,
        mediaUrl: mediaUrl,
        metadata: { ...metadata, event_id: eventId },
      });
      const participants = [conv.participant_1_id, conv.participant_2_id];
      const messageData = {
        event_id: eventId,
        conversation_id: conversationId,
        actor_user_id: userId,
        message: row,
        duplicate: !!duplicate,
      };
      await emitDmEvent(
        conversationId,
        "dm_message",
        messageData,
        userId,
        participants,
      );
      for (const pid of participants) {
        const unread = await db.countUnreadForUser(conversationId, pid);
        const peerId =
          pid === conv.participant_1_id
            ? conv.participant_2_id
            : conv.participant_1_id;
        await emitDmEvent(
          conversationId,
          "dm_inbox",
          {
            event_id: `${eventId}:inbox:${pid}`,
            ...buildInboxPayload({
              conversation: conv,
              row: row,
              unreadForUser: unread,
              peerId: peerId,
            }),
          },
          userId,
          [pid],
        );
      }
      console.log(
        `[DM_GW] dm:send ok conv=${conversationId} dup=${!!duplicate} ` +
          `ms=${Date.now() - t0}`,
      );
      ackOk(ack, { event_id: eventId, message: row, duplicate: !!duplicate });
    } catch (err) {
      console.error("[dm:send]", err.message);
      ackErr(ack, err.message);
    }
  });
  socket.on("dm:read", async (payload = {}, ack) => {
    try {
      const userId = socket.data.userId;
      if (!userId || String(userId).startsWith("anon:")) {
        return ackErr(ack, "unauthorized");
      }
      const conversationId = String(
        payload.conversationId || payload.conversation_id || "",
      ).trim();
      if (!conversationId) return ackErr(ack, "conversationId required");
      const conv = await db.getConversationForUser(conversationId, userId);
      if (!conv) return ackErr(ack, "conversation not found");
      const updatedIds = await db.markDmRead({
        conversationId: conversationId,
        readerId: userId,
      });
      const participants = [conv.participant_1_id, conv.participant_2_id];
      const eventId = payload.event_id || uuidv4();
      await emitDmEvent(
        conversationId,
        "dm_read",
        {
          event_id: eventId,
          conversation_id: conversationId,
          reader_id: userId,
          message_ids: updatedIds,
        },
        userId,
        participants,
      );
      for (const pid of participants) {
        const unread = await db.countUnreadForUser(conversationId, pid);
        const peerId =
          pid === conv.participant_1_id
            ? conv.participant_2_id
            : conv.participant_1_id;
        await emitDmEvent(
          conversationId,
          "dm_inbox",
          {
            event_id: `${eventId}:inbox:${pid}`,
            conversation_id: conversationId,
            status: conv.status,
            last_message_at: conv.last_message_at,
            unread_count: unread,
            peer_id: peerId,
            read_by: userId,
          },
          userId,
          [pid],
        );
      }
      ackOk(ack, { updated: updatedIds.length, message_ids: updatedIds });
    } catch (err) {
      console.error("[dm:read]", err.message);
      ackErr(ack, err.message);
    }
  });
  socket.on("dm:sync", async (payload = {}, ack) => {
    try {
      const userId = socket.data.userId;
      if (!userId || String(userId).startsWith("anon:")) {
        return ackErr(ack, "unauthorized");
      }
      const conversationId = String(
        payload.conversationId || payload.conversation_id || "",
      ).trim();
      if (!conversationId) return ackErr(ack, "conversationId required");
      const conv = await db.getConversationForUser(conversationId, userId);
      if (!conv) return ackErr(ack, "conversation not found");
      const afterTs = payload.after_ts || payload.afterTs || null;
      const afterId = payload.after_id || payload.afterId || null;
      const messages = await db.fetchDmSince({
        conversationId: conversationId,
        afterTs: afterTs,
        afterId: afterId,
        limit: payload.limit || 100,
      });
      console.log(
        `[DM_GW] dm:sync conv=${conversationId} n=${messages.length} ` +
          `after_ts=${afterTs || ""} after_id=${afterId || ""}`,
      );
      ackOk(ack, { messages: messages, conversation_id: conversationId });
    } catch (err) {
      console.error("[dm:sync]", err.message);
      ackErr(ack, err.message);
    }
  });
  socket.on("dm:inbox_sync", async (payload = {}, ack) => {
    try {
      const userId = socket.data.userId;
      if (!userId || String(userId).startsWith("anon:")) {
        return ackErr(ack, "unauthorized");
      }
      const afterTs = payload.after_ts || payload.afterTs || null;
      const rows = await db.fetchInboxForUser({
        userId: userId,
        afterTs: afterTs,
        limit: payload.limit || 100,
      });
      console.log(
        `[DM_GW] dm:inbox_sync user=${userId} n=${rows.length} after_ts=${afterTs || ""}`,
      );
      ackOk(ack, { conversations: rows });
    } catch (err) {
      console.error("[dm:inbox_sync]", err.message);
      ackErr(ack, err.message);
    }
  });
  socket.on("voice:token", async (payload = {}, ack) => {
    try {
      const userId = socket.data.userId;
      if (!userId || String(userId).startsWith("anon:")) {
        return ackErr(ack, "unauthorized");
      }
      const openPublish = !!socket.data.voiceOpen;
      const result = await orbitVoice.mintVoiceToken({
        userId: userId,
        userName: payload.name || userId,
        payload: payload,
        openPublish: openPublish,
      });
      if (!result.ok) {
        if (typeof ack === "function") {
          ack({ ok: false, error: result.error, ...(result.data || {}) });
        }
        return;
      }
      markOpenVoice(
        String(payload.room_id || "").trim(),
        userId,
        openPublish && result.data?.lk_open === true,
      );
      ackOk(ack, result.data);
    } catch (err) {
      console.error("[voice:token]", err);
      ackErr(ack, err.message);
    }
  });
  socket.on("presence:ping", async (payload = {}, ack) => {
    try {
      const userId = socket.data.userId;
      if (!userId || String(userId).startsWith("anon:")) {
        return ackErr(ack, "unauthorized");
      }
      cancelAppOffline(userId);
      await state.setAppOnline(pubClient, userId);
      ackOk(ack, { online: true });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("presence:query", async (payload = {}, ack) => {
    try {
      const userId = socket.data.userId;
      if (!userId || String(userId).startsWith("anon:")) {
        return ackErr(ack, "unauthorized");
      }
      const raw = payload.userIds || payload.user_ids || [];
      const ids = Array.isArray(raw)
        ? raw.map(String).filter(Boolean).slice(0, 200)
        : [];
      const online = await state.mgetAppOnline(pubClient, ids);
      ackOk(ack, { online: online });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("presence:watch", async (payload = {}, ack) => {
    try {
      const userId = socket.data.userId;
      if (!userId || String(userId).startsWith("anon:")) {
        return ackErr(ack, "unauthorized");
      }
      const raw = payload.userIds || payload.user_ids || [];
      const ids = Array.isArray(raw)
        ? raw.map(String).filter(Boolean).slice(0, 200)
        : [];
      if (!socket.data.watching) socket.data.watching = new Set();
      for (const tid of ids) {
        if (tid === userId) continue;
        socket.data.watching.add(tid);
        await state.addAppWatcher(pubClient, tid, userId);
      }
      const online = await state.mgetAppOnline(pubClient, ids);
      ackOk(ack, { online: online });
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("presence:unwatch", async (payload = {}, ack) => {
    try {
      const userId = socket.data.userId;
      if (!userId || String(userId).startsWith("anon:")) {
        return ackErr(ack, "unauthorized");
      }
      const raw = payload.userIds || payload.user_ids || [];
      const ids = Array.isArray(raw) ? raw.map(String).filter(Boolean) : [];
      for (const tid of ids) {
        socket.data.watching?.delete(tid);
        await state.removeAppWatcher(pubClient, tid, userId);
      }
      ackOk(ack);
    } catch (err) {
      ackErr(ack, err.message);
    }
  });
  socket.on("room:gift_sent", (payload = {}, ack) => {
    try {
      noteSocketActivity(socket, "room:gift_sent", {
        gift_id: payload.giftId || payload.gift_id || null,
        count: payload.count ?? 1,
        amount: payload.amount ?? null,
        is_lucky: payload.isLucky ?? payload.is_lucky ?? null,
        trace_id: payload.traceId || payload.trace_id || null,
      });
      if (typeof ack === "function") ackOk(ack, { ok: true });
    } catch (err) {
      if (typeof ack === "function") ackErr(ack, err.message);
    }
  });
  socket.on("client:diag", (payload = {}, ack) => {
    try {
      noteSocketActivity(socket, "client:diag", {
        kind: payload.kind || "note",
        detail: payload.detail || null,
        trace_id: payload.traceId || payload.trace_id || null,
      });
      if (typeof ack === "function") ackOk(ack, { ok: true });
    } catch (err) {
      if (typeof ack === "function") ackErr(ack, err.message);
    }
  });
  socket.on("disconnect", async (reason) => {
    console.log(`[ws] disconnect ${socket.id} reason=${reason}`);
    const roomId = socket.data.roomId;
    const userId = socket.data.userId;
    if (roomId) socket.data.roomId = null;
    seatTrace("disconnect", {
      socketId: socket.id,
      userId: userId || null,
      roomId: roomId || null,
      sio_reason: reason,
    });
    emitDropDiag("socket-disconnect", socket, {
      userId: userId,
      roomId: roomId,
      sio_reason: reason,
    }).catch((err) => console.warn("[DROP-DIAG] failed:", err.message));
    if (userId && socket.data.watching instanceof Set) {
      for (const tid of socket.data.watching) {
        state.removeAppWatcher(pubClient, tid, userId).catch(() => {});
      }
      socket.data.watching.clear();
    }
    if (userId && !String(userId).startsWith("anon:")) {
      const stillLive = await userHasLiveSocket(userId);
      if (!stillLive) {
        scheduleAppOffline(userId);
      }
    }
    if (roomId && userId) {
      if (await userHasLiveSocket(userId)) {
        seatTrace("disconnect-skipped-other-socket", {
          userId: userId,
          roomId: roomId,
          socketId: socket.id,
          sio_reason: reason,
        });
        console.log(
          `[ws] soft-disconnect skipped (other socket live) user=${userId} room=${roomId}`,
        );
        return;
      }
      seatTrace("disconnect-grace-scheduled", {
        userId: userId,
        roomId: roomId,
        socketId: socket.id,
        sio_reason: reason,
        grace_ms: SOFT_DISCONNECT_GRACE_MS,
      });
      console.log(
        `[ws] soft-disconnect user=${userId} room=${roomId} ` +
          `(grace vacate in ${SOFT_DISCONNECT_GRACE_MS}ms)`,
      );
      scheduleGraceVacate(userId, roomId);
    }
  });
});
pubClient.on("error", (err) => console.error("[redis:pub]", err.message));
subClient.on("error", (err) => console.error("[redis:sub]", err.message));
gameSubClient.on("error", (err) =>
  console.error("[redis:game-sub]", err.message),
);
gameSubClient.subscribe(gameState.PHASE_CHANNEL, (err) => {
  if (err) {
    console.error("[game] subscribe failed:", err.message);
    return;
  }
  console.log(`[game] subscribed ${gameState.PHASE_CHANNEL}`);
});
gameSubClient.on("message", (channel, message) => {
  if (channel !== gameState.PHASE_CHANNEL) return;
  let snapshot;
  try {
    snapshot = JSON.parse(message);
  } catch (_) {
    return;
  }
  const slug = gameState.canonicalSlug(snapshot.slug);
  if (!slug) return;
  const event = {
    ...snapshot,
    slug: slug,
    server_now: snapshot.server_now || new Date().toISOString(),
  };
  io.to(gameState.socketRoom(slug)).emit("game:event", event);
});
const PRESENCE_SWEEP_MS = Number(process.env.PRESENCE_SWEEP_MS || 6e4);
setInterval(() => {
  sweepStalePresenceSeats().catch((err) =>
    console.warn("[sweep] error:", err.message),
  );
  sweepOrphanedSeats().catch((err) =>
    console.warn("[sweep:orphan] error:", err.message),
  );
}, PRESENCE_SWEEP_MS).unref?.();
if (!localJwks && !SUPABASE_JWT_SECRET && !remoteJwks) {
  console.error(
    "[auth] FATAL: no JWT verification configured (local JWKS / SUPABASE_JWT_SECRET / remote JWKS)",
  );
  process.exit(1);
}
server.listen(PORT, "0.0.0.0", () => {
  console.log(`[gateway] listening on :${PORT}`);
  console.log(`[gateway] redis=${REDIS_URL.replace(/:[^:@/]+@/, ":***@")}`);
  console.log(`[gateway] db=${db.getPool() ? "configured" : "disabled"}`);
  console.log(
    `[gateway] auth=${localJwks ? (SUPABASE_JWT_SECRET ? "local-jwks+hs256" : "local-jwks") : SUPABASE_JWT_SECRET ? "hs256" : "jwks"} allow_anon=${ALLOW_ANON}`,
  );
  console.log(`[gateway] presence sweep every ${PRESENCE_SWEEP_MS}ms`);
  console.log(
    `[gateway] soft-disconnect grace ${SOFT_DISCONNECT_GRACE_MS}ms ` +
      `(presence hold ${SOFT_DISCONNECT_PRESENCE_TTL_SEC}s)`,
  );
  console.log("[gateway] game phase fan-out enabled");
  console.log("[gateway] SEAT-TRACE enabled (grep [SEAT-TRACE])");
  console.log(
    `[gateway] DROP-DIAG enabled (grep [DROP-DIAG]) gift_window=${DROP_DIAG_GIFT_WINDOW_SEC}s`,
  );
  luckyEngine.refreshConfig(true).catch(() => {});
  luckyEngine.startPendingCreditWorker(pubClient, {
    track: shutdown.track,
    isStopping: shutdown.isStopping,
  });
  console.log("[gateway] lucky engine pending-credit worker started");
  if (db.getGiftPool()) giftSettle.startGiftRankFlusher();
});
