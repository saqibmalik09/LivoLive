const { SignJWT } = require("jose");
const db = require("./db");

const TOKEN_TTL_SECONDS = 6 * 60 * 60;

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

async function signToken({ apiKey, apiSecret, identity, name, room, canPublish }) {
  const now = Math.floor(Date.now() / 1e3);
  return await new SignJWT({
    name: name,
    video: {
      roomJoin: true,
      room: room,
      canPublish: canPublish,
      canSubscribe: true,
      canPublishData: true,
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

/**
 * Mints a LiveKit join token directly, with no Orbit middleman.
 *
 * Publish permission comes from the durable room_seats table only — never from
 * the client's own open_mic/on_seat claim, exactly as the Orbit path does.
 */
async function mintVoiceToken({ userId, userName, payload = {}, settings, timings = {} }) {
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
    });
  } catch (e) {
    console.error("[voice:livekit] sign failed", e?.message || e);
    return { ok: false, error: "livekit_token_failed", status: 500, data: { timings } };
  }
  mark("livekit_sign_ms", t);

  console.log(
    `[voice:livekit] ok room=${room} user=${userId} publish=${canPublish} seat=${onSeat}`,
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
      timings: timings,
    },
  };
}

module.exports = {
  mintVoiceToken: mintVoiceToken,
  livekitRoomName: livekitRoomName,
};
