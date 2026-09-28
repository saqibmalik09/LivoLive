const db = require("./db");
const livekitVoice = require("./livekit_voice");
const FETCH_TIMEOUT_MS = 8e3;
const SETTINGS_TTL_MS = 6e4;
const SETTINGS_KEYS = [
  "voice_backend",
  "orbit_api_url",
  "orbit_livekit_url",
  "orbit_tenant_api_key",
  "livekit_url",
  "livekit_api_key",
  "livekit_api_secret",
  "livekit_test_user_ids",
];
let settingsCache = null;
let settingsCacheAt = 0;
const roomIdCache = new Map();
const ROOM_ID_TTL_MS = 3e5;
function cachedRoomId(roomId) {
  const hit = roomIdCache.get(roomId);
  if (!hit) return null;
  if (Date.now() - hit.at > ROOM_ID_TTL_MS) {
    roomIdCache.delete(roomId);
    return null;
  }
  return hit.orbitRoomId;
}
function rememberRoomId(roomId, orbitRoomId) {
  if (!roomId || !orbitRoomId) return;
  roomIdCache.set(roomId, { orbitRoomId: orbitRoomId, at: Date.now() });
}
async function loadOrbitSettings() {
  const now = Date.now();
  if (settingsCache && now - settingsCacheAt < SETTINGS_TTL_MS) {
    return settingsCache;
  }
  const { rows: rows } = await db.query(
    `SELECT key, value FROM system_settings WHERE key = ANY($1::text[])`,
    [SETTINGS_KEYS],
  );
  const settings = Object.fromEntries(
    (rows || []).map((r) => [r.key, r.value]),
  );
  settingsCache = settings;
  settingsCacheAt = now;
  return settings;
}
function clearSettingsCache() {
  settingsCache = null;
  settingsCacheAt = 0;
}
async function fetchWithTimeout(url, init, timeoutMs = FETCH_TIMEOUT_MS) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}
async function joinOrbitWithRetry(orbitApi, headers, orbitRoomId, userId) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    const joinRes = await fetchWithTimeout(
      `${orbitApi}/api/rooms/${orbitRoomId}/join`,
      {
        method: "POST",
        headers: headers,
        body: JSON.stringify({ userId: userId, openMic: true }),
      },
    );
    if (joinRes.ok) return true;
    const detail = await joinRes.text();
    const retryable =
      joinRes.status === 409 ||
      detail.includes("seat_busy_retry") ||
      detail.includes("no_free_seat");
    console.warn(
      `[voice:token] join attempt ${attempt} status=${joinRes.status}`,
      detail,
    );
    if (!retryable || attempt === 3) return false;
    await new Promise((r) => setTimeout(r, 120 * attempt));
  }
  return false;
}
async function verifyOrbitRoomId(
  orbitApi,
  headers,
  orbitRoomId,
  livekitRoom,
  skRoomId,
) {
  try {
    const res = await fetchWithTimeout(`${orbitApi}/api/rooms/${orbitRoomId}`, {
      method: "GET",
      headers: headers,
    });
    if (!res.ok) return false;
    const payload = await res.json();
    const room = payload?.room ?? payload;
    const name = room?.livekitRoom ?? room?.livekit_room;
    if (typeof name === "string" && name === livekitRoom) return true;
    const metaRoom =
      room?.metadata?.sklive_room_id ?? room?.metadata?.sk_room_id;
    if (metaRoom && String(metaRoom) === skRoomId) return true;
    if (metaRoom && livekitRoom.includes(String(metaRoom).replace(/-/g, ""))) {
      return true;
    }
    return false;
  } catch (e) {
    console.warn("[voice:token] verify room", e?.message || e);
    return false;
  }
}
async function resolveOrbitRoomId(orbitApi, headers, livekitRoom) {
  try {
    const listRes = await fetchWithTimeout(
      `${orbitApi}/api/rooms?livekitRoom=${encodeURIComponent(livekitRoom)}`,
      { method: "GET", headers: headers },
    );
    if (!listRes.ok) return null;
    const payload = await listRes.json();
    const rooms = Array.isArray(payload)
      ? payload
      : Array.isArray(payload?.rooms)
        ? payload.rooms
        : payload?.room
          ? [payload.room]
          : [];
    for (const room of rooms) {
      if (
        room?.livekitRoom === livekitRoom ||
        room?.livekit_room === livekitRoom
      ) {
        return room.id ?? null;
      }
    }
    return rooms[0]?.id ?? null;
  } catch (e) {
    console.warn("[voice:token] resolve room", e?.message || e);
    return null;
  }
}
async function mintVoiceToken({
  userId: userId,
  userName: userName,
  payload: payload = {},
}) {
  const t0 = Date.now();
  const timings = {};
  const mark = (name, startedAt) => {
    timings[name] = Date.now() - startedAt;
  };
  if (!userId || String(userId).startsWith("anon:")) {
    return { ok: false, error: "unauthorized", status: 401 };
  }
  let t = Date.now();
  const roomId = String(payload.room_id || "").trim();
  const openMic = Boolean(payload.open_mic);
  const onSeatClaim = Boolean(payload.on_seat);
  const billingOnly = Boolean(payload.billing_only);
  const leaveSeat = Boolean(payload.leave_seat);
  const cachedOrbitRoomId = String(payload.orbit_room_id || "").trim() || null;
  mark("parse_body_ms", t);
  if (!roomId) {
    return {
      ok: false,
      error: "room_id_required",
      status: 400,
      data: { timings: timings },
    };
  }
  t = Date.now();
  const settings = await loadOrbitSettings();
  mark("settings_ms", t);
  // Allow-list lets specific accounts run on LiveKit while everyone else stays
  // on the current backend — so a new build can be tested against production
  // without moving live users onto an engine their app version lacks.
  const livekitTestIds = String(settings.livekit_test_user_ids || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const forcedLiveKit = livekitTestIds.includes(String(userId));
  const backend = forcedLiveKit ? "livekit" : settings.voice_backend || "zego";
  if (forcedLiveKit) {
    console.log(`[voice] user=${userId} forced to livekit by test allow-list`);
  }
  if (backend === "livekit") {
    return await livekitVoice.mintVoiceToken({
      userId: userId,
      userName: userName,
      payload: payload,
      settings: settings,
      timings: timings,
    });
  }
  if (backend !== "orbit") {
    return {
      ok: false,
      error: "voice_backend_not_orbit",
      status: 400,
      data: { timings: timings },
    };
  }
  const orbitApi =
    String(settings.orbit_api_url || "").replace(/\/$/, "") ||
    (process.env.ORBIT_API_URL || "").replace(/\/$/, "") ||
    "";
  const livekitUrl =
    String(settings.orbit_livekit_url || "") ||
    process.env.ORBIT_LIVEKIT_URL ||
    "";
  const tenantKey =
    String(settings.orbit_tenant_api_key || "").trim() ||
    process.env.ORBIT_TENANT_API_KEY ||
    "";
  if (!orbitApi || !tenantKey || !livekitUrl) {
    return {
      ok: false,
      error: "orbit_not_configured",
      status: 503,
      data: {
        detail:
          "Set ORBIT_API_URL, ORBIT_TENANT_API_KEY (or system_settings), ORBIT_LIVEKIT_URL",
        timings: timings,
      },
    };
  }
  const headers = {
    "content-type": "application/json",
    "x-api-key": tenantKey,
  };
  t = Date.now();
  const [seatResult, roomResult] = await Promise.all([
    db.query(
      `SELECT seat_index FROM room_seats\n       WHERE room_id = $1 AND user_id = $2\n       LIMIT 1`,
      [roomId, userId],
    ),
    db.query(`SELECT id FROM rooms WHERE id = $1 LIMIT 1`, [roomId]),
  ]);
  mark("seat_lookup_ms", t);
  if (!roomResult.rows[0]) {
    return {
      ok: false,
      error: "room_not_found",
      status: 404,
      data: { timings: timings },
    };
  }
  let seat = seatResult.rows[0] || null;
  if (!seat && onSeatClaim) {
    await new Promise((r) => setTimeout(r, 120));
    const { rows: rows } = await db.query(
      `SELECT seat_index FROM room_seats\n       WHERE room_id = $1 AND user_id = $2\n       LIMIT 1`,
      [roomId, userId],
    );
    seat = rows[0] || null;
    timings.seat_retry_ms = 120;
  }
  const onSeat = Boolean(seat);
  const canPublish = onSeat;
  const livekitRoom = `sklive_${roomId.replace(/-/g, "")}`;
  const needsOrbitRoom = openMic || onSeat || leaveSeat;
  const path = leaveSeat
    ? "leave_seat"
    : openMic
      ? "open_mic"
      : onSeat
        ? "seat_mute"
        : "listener";
  let orbitRoomId = null;
  if (needsOrbitRoom) {
    const memo = cachedRoomId(roomId);
    if (memo && (!cachedOrbitRoomId || cachedOrbitRoomId === memo)) {
      orbitRoomId = memo;
      timings.orbit_room_verify_ms = 0;
      timings.orbit_room_upsert_ms = 0;
    }
    if (!orbitRoomId && cachedOrbitRoomId) {
      t = Date.now();
      const verified = await verifyOrbitRoomId(
        orbitApi,
        headers,
        cachedOrbitRoomId,
        livekitRoom,
        roomId,
      );
      mark("orbit_room_verify_ms", t);
      if (verified) {
        orbitRoomId = cachedOrbitRoomId;
        timings.orbit_room_upsert_ms = 0;
        rememberRoomId(roomId, orbitRoomId);
      } else {
        console.warn(
          "[voice:token] cached orbit_room_id rejected",
          cachedOrbitRoomId,
        );
      }
    }
    if (!orbitRoomId) {
      t = Date.now();
      const upsertRes = await fetchWithTimeout(`${orbitApi}/api/rooms`, {
        method: "POST",
        headers: headers,
        body: JSON.stringify({
          title: `SK ${roomId.slice(0, 8)}`,
          livekitRoom: livekitRoom,
          maxSeats: 20,
          metadata: { sklive_room_id: roomId },
        }),
      });
      mark("orbit_room_upsert_ms", t);
      if (upsertRes.ok) {
        const created = await upsertRes.json();
        orbitRoomId = created.room?.id ?? null;
      } else {
        const detail = await upsertRes.text();
        console.warn("[voice:token] room upsert failed", detail);
        if (!detail.includes("rooms_livekit_room_key")) {
          return {
            ok: false,
            error: "orbit_create_failed",
            status: 502,
            data: { detail: detail, timings: timings },
          };
        }
        t = Date.now();
        orbitRoomId = await resolveOrbitRoomId(orbitApi, headers, livekitRoom);
        mark("orbit_room_resolve_ms", t);
        if (!orbitRoomId) {
          return {
            ok: false,
            error: "orbit_resolve_failed",
            status: 502,
            data: { detail: detail, timings: timings },
          };
        }
      }
    }
    rememberRoomId(roomId, orbitRoomId);
  }
  if (leaveSeat && orbitRoomId) {
    t = Date.now();
    const leaveRes = await fetchWithTimeout(
      `${orbitApi}/api/rooms/${orbitRoomId}/leave`,
      {
        method: "POST",
        headers: headers,
        body: JSON.stringify({ userId: userId }),
      },
    );
    mark("orbit_leave_ms", t);
    const leaveOk = leaveRes.ok;
    if (!leaveOk) {
      console.warn("[voice:token] leave failed", await leaveRes.text());
    }
    if (billingOnly) {
      timings.total_ms = Date.now() - t0;
      return {
        ok: leaveOk,
        error: leaveOk ? undefined : "leave_failed",
        status: leaveOk ? 200 : 502,
        data: {
          backend: "orbit",
          billing_only: true,
          leave_seat: true,
          leave_ok: leaveOk,
          orbit_room_id: orbitRoomId,
          can_publish: false,
          on_seat: false,
          timings: timings,
        },
      };
    }
  }
  if (orbitRoomId && billingOnly && !openMic && !leaveSeat && onSeat) {
    void fetchWithTimeout(`${orbitApi}/api/rooms/${orbitRoomId}/seats`, {
      method: "PATCH",
      headers: headers,
      body: JSON.stringify({ userId: userId, isMuted: true }),
    }).catch((err) =>
      console.warn("[voice:token] mute bg", err?.message || err),
    );
    timings.orbit_seats_mute_ms = 0;
  }
  const displayName = userName || userId;
  if (billingOnly) {
    let joinOk = true;
    if (orbitRoomId && openMic && canPublish) {
      t = Date.now();
      joinOk = await joinOrbitWithRetry(orbitApi, headers, orbitRoomId, userId);
      mark("orbit_join_ms", t);
      if (!joinOk) console.warn("[voice:token] billing join failed");
    } else if (orbitRoomId && openMic && !canPublish) {
      joinOk = false;
      console.warn("[voice:token] billing open_mic ignored — not on seat");
    }
    timings.total_ms = Date.now() - t0;
    return {
      ok: true,
      data: {
        backend: "orbit",
        billing_only: true,
        join_ok: joinOk,
        orbit_room_id: orbitRoomId,
        can_publish: canPublish,
        on_seat: onSeat,
        timings: timings,
      },
    };
  }
  if (orbitRoomId && openMic && canPublish) {
    t = Date.now();
    const joinOk = await joinOrbitWithRetry(
      orbitApi,
      headers,
      orbitRoomId,
      userId,
    );
    mark("orbit_join_ms", t);
    if (!joinOk) {
      return {
        ok: false,
        error: "orbit_join_failed",
        status: 502,
        data: { timings: timings },
      };
    }
  }
  if (openMic && !canPublish) {
    return {
      ok: false,
      error: "publish_denied_not_on_seat",
      status: 403,
      data: { can_publish: false, on_seat: false, timings: timings },
    };
  }
  const tokenBody = orbitRoomId
    ? {
        roomId: orbitRoomId,
        userId: userId,
        name: displayName,
        canPublish: canPublish,
      }
    : {
        livekitRoom: livekitRoom,
        userId: userId,
        name: displayName,
        canPublish: canPublish,
      };
  t = Date.now();
  const tokenRes = await fetchWithTimeout(`${orbitApi}/api/token`, {
    method: "POST",
    headers: headers,
    body: JSON.stringify(tokenBody),
  });
  mark("orbit_token_ms", t);
  if (!tokenRes.ok) {
    return {
      ok: false,
      error: "orbit_token_failed",
      status: 502,
      data: { detail: await tokenRes.text(), timings: timings },
    };
  }
  const tokenPayload = await tokenRes.json();
  timings.total_ms = Date.now() - t0;
  console.log(
    "[voice:token] ok",
    JSON.stringify({
      roomId: roomId,
      path: path,
      openMic: openMic,
      onSeat: onSeat,
      canPublish: canPublish,
      timings: timings,
    }),
  );
  return {
    ok: true,
    data: {
      backend: "orbit",
      token: tokenPayload.token,
      livekit_url: livekitUrl,
      livekit_room: tokenPayload.livekitRoom || livekitRoom,
      orbit_room_id: orbitRoomId,
      can_publish: Boolean(tokenPayload.canPublish ?? canPublish),
      on_seat: onSeat,
      timings: timings,
    },
  };
}
module.exports = {
  mintVoiceToken: mintVoiceToken,
  clearSettingsCache: clearSettingsCache,
  loadOrbitSettings: loadOrbitSettings,
};
