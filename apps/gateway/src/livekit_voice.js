const crypto = require("crypto");
const { SignJWT, jwtVerify } = require("jose");
const db = require("./db");

const TOKEN_TTL_SECONDS = 6 * 60 * 60;
const ADMIN_TOKEN_TTL_SECONDS = 60;
const PERMISSION_SYNC_TIMEOUT_MS = 2000;
const PERMISSION_SYNC_FIRST_ATTEMPT_MS = Number(
  process.env.LIVEKIT_PERM_SYNC_FIRST_ATTEMPT_MS || 600,
);
// How long a token mint is willing to wait for the admin-API permission sync
// before replying anyway. The sync keeps running in the background; the caller
// sees perm_sync = "pending" instead of a token that arrives seconds late.
const PERMISSION_SYNC_WAIT_MS = Number(
  process.env.LIVEKIT_PERM_SYNC_WAIT_MS || 250,
);
function sleep(ms) {
  return new Promise((resolve) => {
    const timer = setTimeout(resolve, ms);
    if (typeof timer.unref === "function") timer.unref();
  });
}

function resolveConfig(settings) {
  return {
    url: String(settings.livekit_url || "").trim() || process.env.LIVEKIT_URL || "",
    apiKey:
      String(settings.livekit_api_key || "").trim() || process.env.LIVEKIT_API_KEY || "",
    apiSecret:
      String(settings.livekit_api_secret || "").trim() ||
      process.env.LIVEKIT_API_SECRET ||
      "",
  };
}

// Same naming the Orbit path uses, so a room keeps one identity across backends.
function livekitRoomName(roomId) {
  return `sklive_${String(roomId).replace(/-/g, "")}`;
}

// openPublish: the token itself carries the right to publish the microphone, so
// taking a seat never needs a live admin call to LiveKit (that call is what
// stalled 0.6-1.5 s under load). Only the microphone source is allowed, and the
// SFU enforces that. Whether the user may actually speak is decided by the seat
// table and enforced from LiveKit's track_published webhook.
async function signToken({
  apiKey,
  apiSecret,
  identity,
  name,
  room,
  canPublish,
  openPublish = false,
}) {
  const now = Math.floor(Date.now() / 1e3);
  return await new SignJWT({
    name: name,
    video: {
      roomJoin: true,
      room: room,
      canPublish: !!canPublish || !!openPublish,
      canSubscribe: true,
      canPublishData: true,
      ...(openPublish ? { canPublishSources: ["microphone"] } : {}),
    },
  })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuer(apiKey)
    .setSubject(identity)
    .setJti(`${identity}-${now}`)
    .setNotBefore(now - 10)
    .setExpirationTime(now + TOKEN_TTL_SECONDS)
    .sign(new TextEncoder().encode(apiSecret));
}

// Server-to-LiveKit admin calls (grant/revoke publish) should not travel the
// public proxy that phones use: it adds TLS and proxy latency and jitter that a
// call between two containers on the same host does not need. Set
// LIVEKIT_ADMIN_URL to LiveKit's internal address (for example
// http://172.17.0.1:7880) to take that hop out; unset keeps the public URL.
function adminBaseFrom(wsUrl) {
  const internal = String(process.env.LIVEKIT_ADMIN_URL || "").trim();
  if (internal) return internal.replace(/\/$/, "");
  return httpBaseFrom(wsUrl);
}

function httpBaseFrom(wsUrl) {
  return String(wsUrl)
    .replace(/^wss:/i, "https:")
    .replace(/^ws:/i, "http:")
    .replace(/\/$/, "");
}

async function signAdminToken({ apiKey, apiSecret, room }) {
  const now = Math.floor(Date.now() / 1e3);
  return await new SignJWT({ video: { roomAdmin: true, room: room } })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuer(apiKey)
    .setSubject(apiKey)
    .setNotBefore(now - 10)
    .setExpirationTime(now + ADMIN_TOKEN_TTL_SECONDS)
    .sign(new TextEncoder().encode(apiSecret));
}

/**
 * Applies publish permission to a participant's *live* connection.
 *
 * This is what Orbit's /join and /leave used to do for us. Without it the app's
 * 700ms waitForPublishPermission() always times out and it falls back to a full
 * reconnect to pick up the new token — the ~5s delay on taking the mic and on
 * unmuting. A 404 simply means the user is not connected yet (first join), in
 * which case the token's own grant is what counts.
 *
 * Never throws: on any failure we return a reason and the caller proceeds, which
 * just restores the previous reconnect behaviour rather than breaking voice.
 */
async function syncLivePermission(args) {
  // Production showed a share of these calls hanging until the 2 s timeout
  // (error_AbortError) while the rest returned in milliseconds — a hung
  // connection, not a slow server. Cutting a stuck attempt early and retrying
  // on a fresh request turns that 2 s stall into roughly the first-attempt
  // budget. The update is idempotent, so a retry is always safe.
  const startedAt = Date.now();
  const first = await syncLivePermissionOnce(args, PERMISSION_SYNC_FIRST_ATTEMPT_MS);
  if (!isTransientSyncFailure(first)) return first;
  console.warn(
    `[voice:livekit] perm attempt 1 ${first} after ${Date.now() - startedAt}ms ` +
      `room=${args.room} can=${!!args.canPublish}, retrying`,
  );
  const remaining = Math.max(
    PERMISSION_SYNC_TIMEOUT_MS - (Date.now() - startedAt),
    PERMISSION_SYNC_FIRST_ATTEMPT_MS,
  );
  return await syncLivePermissionOnce(args, remaining);
}

function isTransientSyncFailure(result) {
  return String(result).startsWith("error_") || /^failed_5/.test(String(result));
}

async function syncLivePermissionOnce(
  { url, apiKey, apiSecret, room, identity, canPublish },
  timeoutMs,
) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const token = await signAdminToken({ apiKey: apiKey, apiSecret: apiSecret, room: room });
    const res = await fetch(
      `${adminBaseFrom(url)}/twirp/livekit.RoomService/UpdateParticipant`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          room: room,
          identity: identity,
          permission: {
            canSubscribe: true,
            canPublish: canPublish,
            canPublishData: true,
          },
        }),
        signal: controller.signal,
      },
    );
    if (res.ok) return "updated";
    if (res.status === 404) return "not_connected";
    return `failed_${res.status}`;
  } catch (e) {
    return `error_${e?.name || "unknown"}`;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Mints a LiveKit join token directly, with no Orbit middleman.
 *
 * Publish permission comes from the durable room_seats table only — never from
 * the client's own open_mic/on_seat claim, exactly as the Orbit path does.
 */
async function mintVoiceToken({
  userId,
  userName,
  payload = {},
  settings,
  timings = {},
  openPublish = false,
}) {
  const mark = (name, startedAt) => {
    timings[name] = Date.now() - startedAt;
  };

  const roomId = String(payload.room_id || "").trim();
  if (!roomId) {
    return { ok: false, error: "room_id_required", status: 400, data: { timings } };
  }

  const cfg = resolveConfig(settings);
  if (!cfg.url || !cfg.apiKey || !cfg.apiSecret) {
    return {
      ok: false,
      error: "livekit_not_configured",
      status: 503,
      data: {
        detail:
          "Set livekit_url, livekit_api_key and livekit_api_secret in system_settings, " +
          "or LIVEKIT_URL / LIVEKIT_API_KEY / LIVEKIT_API_SECRET in the environment",
        timings,
      },
    };
  }

  let t = Date.now();
  const [seatResult, roomResult] = await Promise.all([
    db.query(
      `SELECT seat_index FROM room_seats
       WHERE room_id = $1 AND user_id = $2
       LIMIT 1`,
      [roomId, userId],
    ),
    db.query(`SELECT id FROM rooms WHERE id = $1 LIMIT 1`, [roomId]),
  ]);
  mark("seat_lookup_ms", t);

  if (!roomResult.rows[0]) {
    return { ok: false, error: "room_not_found", status: 404, data: { timings } };
  }

  const onSeat = Boolean(seatResult.rows[0]);
  const canPublish = onSeat;
  const room = livekitRoomName(roomId);

  t = Date.now();
  let token;
  try {
    token = await signToken({
      apiKey: cfg.apiKey,
      apiSecret: cfg.apiSecret,
      identity: String(userId),
      name: String(userName || userId),
      room: room,
      canPublish: canPublish,
      openPublish: openPublish,
    });
  } catch (e) {
    console.error("[voice:livekit] sign failed", e?.message || e);
    return { ok: false, error: "livekit_token_failed", status: 500, data: { timings } };
  }
  mark("livekit_sign_ms", t);

  // Grant/revoke on the live connection too, so an already-connected client does
  // not have to reconnect just to pick up a permission change.
  //
  // The token above is already valid for publishing, so this call is a courtesy
  // for a client that is connected right now — it must never hold up the reply.
  // Waiting on the LiveKit admin API here is what made taking the mic feel like
  // it hung: a slow or unreachable server cost every caller the full timeout
  // before they received a token they could have used immediately.
  t = Date.now();
  // An open token already carries the microphone grant, so there is nothing to
  // sync on the live connection and no admin call is made at all.
  let permSync = "token";
  if (!openPublish) {
    const permSyncPromise = syncLivePermission({
      url: cfg.url,
      apiKey: cfg.apiKey,
      apiSecret: cfg.apiSecret,
      room: room,
      identity: String(userId),
      canPublish: canPublish,
    });
    const syncStartedAt = t;
    permSyncPromise.then(
      (result) => {
        const elapsed = Date.now() - syncStartedAt;
        if (result !== "updated" && result !== "not_connected") {
          console.warn(
            `[voice:livekit] perm sync late room=${room} user=${userId} ` +
              `perm=${result} (${elapsed}ms)`,
          );
        }
      },
      (err) => {
        console.warn(
          `[voice:livekit] perm sync threw room=${room} user=${userId}:`,
          err?.message || err,
        );
      },
    );
    permSync = await Promise.race([
      permSyncPromise,
      sleep(PERMISSION_SYNC_WAIT_MS).then(() => "pending"),
    ]);
  }
  mark("livekit_perm_sync_ms", t);

  console.log(
    `[voice:livekit] ok room=${room} user=${userId} publish=${canPublish} ` +
      `seat=${onSeat} perm=${permSync} (${timings.livekit_perm_sync_ms}ms)`,
  );

  // Field names match what the app's _sessionFromMap expects. orbit_room_id is
  // carried as the room name so the app's caching keeps working unchanged.
  return {
    ok: true,
    data: {
      token: token,
      livekit_url: cfg.url,
      livekit_room: room,
      orbit_room_id: room,
      can_publish: canPublish,
      role: canPublish ? "speaker" : "listener",
      on_seat: onSeat,
      backend: "livekit",
      perm_sync: permSync,
      ...(openPublish ? { lk_open: true } : {}),
      timings: timings,
    },
  };
}

/**
 * Mints a join token for a caller that already knows the seat state — the join
 * handler has just built the snapshot, and the sit handler has just written the
 * row, so neither needs the two lookups mintVoiceToken does.
 *
 * Signing is local HS256, so this costs no network and no database work. That
 * is what lets the voice session ride along in the join ack and the sit ack
 * instead of costing the client another round trip before any audio can start.
 *
 * Returns null when LiveKit is not configured, so callers can simply omit the
 * voice fields rather than failing the join.
 */
async function mintVoiceTokenFor({
  userId,
  userName,
  roomId,
  canPublish,
  settings = {},
  openPublish = false,
}) {
  const cfg = resolveConfig(settings);
  if (!cfg.url || !cfg.apiKey || !cfg.apiSecret) return null;
  const room = livekitRoomName(roomId);
  try {
    const token = await signToken({
      apiKey: cfg.apiKey,
      apiSecret: cfg.apiSecret,
      identity: String(userId),
      name: String(userName || userId),
      room: room,
      canPublish: !!canPublish,
      openPublish: openPublish,
    });
    return {
      token: token,
      livekit_url: cfg.url,
      livekit_room: room,
      orbit_room_id: room,
      // Seat-derived, whatever the token allows: clients read this as "may
      // speak", and an open token is deliberately wider than that.
      can_publish: !!canPublish,
      role: canPublish ? "speaker" : "listener",
      on_seat: !!canPublish,
      backend: "livekit",
      ...(openPublish ? { lk_open: true } : {}),
    };
  } catch (e) {
    console.warn("[voice:livekit] inline sign failed:", e?.message || e);
    return null;
  }
}

// Inverse of livekitRoomName: "sklive_<32 hex>" back to the room uuid.
function roomIdFromLivekitRoom(name) {
  const m = /^sklive_([0-9a-f]{32})$/i.exec(String(name || ""));
  if (!m) return null;
  const h = m[1].toLowerCase();
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

/**
 * Verifies a LiveKit webhook delivery. LiveKit signs the request with the API
 * secret: the Authorization header is an HS256 JWT issued by the API key whose
 * `sha256` claim is the base64 SHA-256 of the raw body. Returns the parsed event
 * or null when the signature, issuer, or body hash does not match.
 */
async function verifyWebhook({ authHeader, rawBody, settings }) {
  const cfg = resolveConfig(settings);
  if (!cfg.apiKey || !cfg.apiSecret) return null;
  const token = String(authHeader || "").replace(/^Bearer\s+/i, "").trim();
  if (!token || !Buffer.isBuffer(rawBody)) return null;
  try {
    const { payload } = await jwtVerify(
      token,
      new TextEncoder().encode(cfg.apiSecret),
      { issuer: cfg.apiKey, algorithms: ["HS256"] },
    );
    const digest = crypto.createHash("sha256").update(rawBody).digest("base64");
    if (payload.sha256 !== digest) return null;
    return JSON.parse(rawBody.toString("utf8"));
  } catch (_) {
    return null;
  }
}

module.exports = {
  mintVoiceToken: mintVoiceToken,
  mintVoiceTokenFor: mintVoiceTokenFor,
  syncLivePermission: syncLivePermission,
  livekitRoomName: livekitRoomName,
  roomIdFromLivekitRoom: roomIdFromLivekitRoom,
  verifyWebhook: verifyWebhook,
};
