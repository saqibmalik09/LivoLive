const { Pool: Pool } = require("pg");
let pool = null;
function getPool() {
  if (pool) return pool;
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.warn("[db] DATABASE_URL missing — durable writes disabled");
    return null;
  }
  pool = new Pool({
    connectionString: connectionString,
    ssl: connectionString.includes("supabase.com")
      ? { rejectUnauthorized: false }
      : undefined,
    max: 8,
  });
  pool.on("error", (err) => console.error("[db] pool error:", err.message));
  return pool;
}
async function query(text, params) {
  const p = getPool();
  if (!p) throw new Error("DATABASE_URL not configured");
  return p.query(text, params);
}

let gamePool = null;
function gamePoolMax() {
  const n = Number(process.env.BAISHUN_DB_POOL_MAX);
  return Number.isInteger(n) && n > 0 ? n : 6;
}
function getGamePool() {
  if (gamePool) return gamePool;
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) return null;
  gamePool = new Pool({
    connectionString: connectionString,
    ssl: connectionString.includes("supabase.com")
      ? { rejectUnauthorized: false }
      : undefined,
    max: gamePoolMax(),
  });
  gamePool.on("error", (err) =>
    console.error("[db] game pool error:", err.message),
  );
  return gamePool;
}

function connectGameClient(waitMs) {
  const p = getGamePool();
  if (!p) return Promise.reject(new Error("DATABASE_URL not configured"));
  return new Promise((resolve, reject) => {
    let settled = false;
    const timer = setTimeout(
      () => {
        if (settled) return;
        settled = true;
        const err = new Error("game db wait timeout");
        err.code = "GAME_DB_WAIT_TIMEOUT";
        reject(err);
      },
      Math.max(1, Math.floor(waitMs)),
    );
    p.connect().then(
      (client) => {
        if (settled) {
          client.release();
          return;
        }
        settled = true;
        clearTimeout(timer);
        resolve(client);
      },
      (err) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        reject(err);
      },
    );
  });
}

async function withGameClient(waitMs, fn) {
  const client = await connectGameClient(waitMs);
  let failed = false;
  try {
    return await fn(client);
  } catch (err) {
    failed = true;
    throw err;
  } finally {
    client.release(failed);
  }
}

let giftPool = null;
function giftPoolMax() {
  const n = Number(process.env.GIFT_DB_POOL_MAX);
  return Number.isInteger(n) && n > 0 ? n : 6;
}
function getGiftPool() {
  if (giftPool) return giftPool;
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) return null;
  giftPool = new Pool({
    connectionString: connectionString,
    ssl: connectionString.includes("supabase.com")
      ? { rejectUnauthorized: false }
      : undefined,
    max: giftPoolMax(),
    connectionTimeoutMillis: 15e3,
    statement_timeout: 15e3,
  });
  giftPool.on("error", (err) =>
    console.error("[db] gift pool error:", err.message),
  );
  return giftPool;
}
async function giftQuery(text, params) {
  const p = getGiftPool();
  if (!p) throw new Error("DATABASE_URL not configured");
  return p.query(text, params);
}

async function loadRoomSeats(roomId) {
  const { rows: rows } = await query(
    `SELECT s.id, s.room_id, s.user_id, s.seat_index, s.is_muted, s.is_locked, s.updated_at,\n            u.username, u.avatar_url, u.vip_level\n     FROM room_seats s\n     LEFT JOIN users u ON u.id = s.user_id\n     WHERE s.room_id = $1\n     ORDER BY s.seat_index ASC`,
    [roomId],
  );
  const seats = rows.map((r) => ({
    id: r.id,
    room_id: r.room_id,
    user_id: r.user_id,
    seat_index: r.seat_index,
    is_muted: r.is_muted,
    is_locked: r.is_locked,
    updated_at: r.updated_at,
    user: r.user_id
      ? {
          id: r.user_id,
          username: r.username,
          avatar_url: r.avatar_url,
          vip_level: r.vip_level,
        }
      : null,
  }));
  await attachSeatWear(seats);
  return seats;
}
function wearText(value) {
  return value == null ? "" : String(value);
}
function isSeatFrameCategory(category) {
  return (
    category === "profile photo frame" ||
    (category.includes("frame") && !category.includes("card"))
  );
}
function isSeatTitle(category, name) {
  if (
    category === "profile photo frame" ||
    category === "car" ||
    category === "entrance show" ||
    category.includes("bubble") ||
    category.includes("gift") ||
    category.includes("lucky") ||
    category.includes("profile card")
  ) {
    return false;
  }
  if (
    category.includes("title") ||
    category.includes("nameplate") ||
    category.includes("name plate")
  ) {
    return true;
  }
  return (name || "").includes("title");
}
function isSeatMedal(category, sourceType) {
  return (
    sourceType === "medal" ||
    category.includes("medal") ||
    (category.includes("badge") && !category.includes("title"))
  );
}
async function attachSeatWear(seats) {
  const ids = [];
  for (const seat of seats) {
    if (seat && seat.user_id && !ids.includes(seat.user_id)) {
      ids.push(seat.user_id);
    }
  }
  if (!ids.length) return;
  let inventory;
  let levels;
  try {
    const [invRes, levelRes] = await Promise.all([
      query(
        `SELECT ui.user_id, si.image_url, si.svga_url, si.name,
                lower(coalesce(si.source_type, '')) AS source_type,
                lower(coalesce(sc.name, '')) AS category
         FROM user_inventory ui
         JOIN shop_items si ON si.id = ui.item_id
         LEFT JOIN shop_categories sc ON sc.id = si.category_id
         WHERE ui.user_id = ANY($1::uuid[])
           AND ui.is_equipped = true
           AND (ui.expires_at IS NULL OR ui.expires_at > now())`,
        [ids],
      ),
      query(
        `SELECT u.id AS user_id,
                COALESCE(u.wealth_level, 1) AS wealth_level,
                COALESCE(u.charm_level, 1) AS charm_level,
                COALESCE(u.vip_level, 0) AS vip_level,
                wl.badge_url AS wealth_badge,
                (SELECT cl.image_url FROM charm_level_assets cl
                  WHERE cl.level = COALESCE(u.charm_level, 1)
                    AND cl.feature_key = 'badge'
                  LIMIT 1) AS charm_badge,
                (SELECT v.image_url FROM vip_level_assets v
                  WHERE v.level = u.vip_level
                    AND v.feature_key = 'has_vip_title'
                  LIMIT 1) AS vip_badge,
                (SELECT fa.image_url FROM families f
                  JOIN family_level_assets fa
                    ON fa.feature_key = 'badge' AND fa.level <= f.level
                  WHERE f.id = u.family_id
                  ORDER BY fa.level DESC
                  LIMIT 1) AS family_badge,
                (SELECT f.level FROM families f WHERE f.id = u.family_id) AS family_level,
                cp.cp_level,
                cpc.badge_url AS cp_badge,
                cpc.frame_url AS cp_frame
         FROM users u
         LEFT JOIN level_configs wl
           ON wl.category = 'user_wealth'
          AND wl.level = COALESCE(u.wealth_level, 1)
         LEFT JOIN LATERAL (
           SELECT c.cp_level
           FROM couples c
           WHERE c.user1_id = u.id OR c.user2_id = u.id
           ORDER BY c.cp_level DESC NULLS LAST
           LIMIT 1
         ) cp ON true
         LEFT JOIN cp_level_configs cpc
           ON cp.cp_level IS NOT NULL
          AND cpc.level = GREATEST(cp.cp_level, 1)
         WHERE u.id = ANY($1::uuid[])`,
        [ids],
      ),
    ]);
    inventory = invRes.rows || [];
    levels = levelRes.rows || [];
  } catch (err) {
    console.warn("[seats] wear attach skipped:", err.message);
    return;
  }
  const agencyByUser = new Map();
  try {
    const { rows: agencyRows } = await query(
      `SELECT u.id AS user_id,
              COALESCE(owned.name, mem.name, 'Agency') AS name,
              COALESCE(owned.id, mem.id) AS agency_id,
              alc.badge_url,
              alc.level
       FROM users u
       LEFT JOIN LATERAL (
         SELECT a.id, a.name FROM agencies a WHERE a.owner_id = u.id LIMIT 1
       ) owned ON true
       LEFT JOIN LATERAL (
         SELECT a.id, a.name
         FROM agency_members m
         JOIN agencies a ON a.id = m.agency_id
         WHERE m.user_id = u.id
         LIMIT 1
       ) mem ON owned.id IS NULL
       JOIN agency_rankings ar
         ON ar.agency_id = COALESCE(owned.id, mem.id)
        AND ar.ranking_type = 'weekly'
       JOIN LATERAL (
         SELECT c.level, c.badge_url
         FROM agency_level_configs c
         WHERE c.min_exp <= COALESCE(ar.score, 0)
         ORDER BY c.min_exp DESC
         LIMIT 1
       ) alc ON alc.badge_url IS NOT NULL AND alc.badge_url <> ''
       WHERE u.id = ANY($1::uuid[])`,
      [ids],
    );
    for (const row of agencyRows || []) {
      agencyByUser.set(String(row.user_id), row);
    }
  } catch (err) {
    console.warn("[seats] agency badge skipped:", err.message);
  }
  const invByUser = new Map();
  for (const row of inventory) {
    const id = String(row.user_id);
    const list = invByUser.get(id);
    if (list) list.push(row);
    else invByUser.set(id, [row]);
  }
  const levelByUser = new Map();
  for (const row of levels) levelByUser.set(String(row.user_id), row);
  for (const seat of seats) {
    if (!seat || !seat.user || !seat.user_id) continue;
    const id = String(seat.user_id);
    const items = invByUser.get(id) || [];
    const level = levelByUser.get(id);
    let frameImage = "";
    let frameSvga = "";
    const badges = [];
    for (const item of items) {
      const category = wearText(item.category);
      const name = wearText(item.name);
      const image = wearText(item.image_url).trim();
      const svga = wearText(item.svga_url).trim();
      if (!frameImage && !frameSvga && isSeatFrameCategory(category)) {
        frameImage = image;
        frameSvga = svga;
        continue;
      }
      if (!image) continue;
      if (isSeatTitle(category, name.toLowerCase())) {
        badges.push({
          name: name || "Item",
          image_url: image,
          type: "title",
          priority: 35,
          isEquipped: true,
        });
      } else if (isSeatMedal(category, wearText(item.source_type))) {
        badges.push({
          name: name || "Item",
          image_url: image,
          type: "medal",
          priority: 45,
          isEquipped: true,
        });
      }
    }
    const cpLevel = Number(level && level.cp_level) || 0;
    if (!frameImage && !frameSvga && cpLevel > 0) {
      frameImage = wearText(level.cp_frame).trim();
    }
    if (level) {
      const wealthLevel = Number(level.wealth_level) || 1;
      const wealthUrl = wearText(level.wealth_badge).trim();
      if (wealthUrl) {
        badges.push({
          name: `Wealth Lv.${wealthLevel}`,
          image_url: wealthUrl,
          level: wealthLevel,
          type: "wealth",
          priority: 1,
        });
      }
      const charmLevel = Number(level.charm_level) || 1;
      const charmUrl = wearText(level.charm_badge).trim();
      if (charmUrl) {
        badges.push({
          name: `Charm Lv.${charmLevel}`,
          image_url: charmUrl,
          level: charmLevel,
          type: "charm",
          priority: 2,
        });
      }
      const vipLevel = Number(level.vip_level) || 0;
      const vipUrl = wearText(level.vip_badge).trim();
      if (vipLevel > 0 && vipUrl) {
        badges.push({
          name: `VIP ${vipLevel}`,
          image_url: vipUrl,
          type: "vip",
          priority: 0,
        });
      }
      const familyUrl = wearText(level.family_badge).trim();
      const familyLevel = Number(level.family_level) || 0;
      if (familyUrl && familyLevel > 0) {
        badges.push({
          name: `Family Lv.${familyLevel}`,
          image_url: familyUrl,
          level: familyLevel,
          type: "family",
          priority: 4,
        });
      }
      const cpUrl = wearText(level.cp_badge).trim();
      if (level.cp_level != null && cpUrl) {
        const badgeLevel = Math.max(cpLevel, 1);
        badges.push({
          name: `CP Lv.${badgeLevel}`,
          image_url: cpUrl,
          level: badgeLevel,
          type: "cp",
          priority: 3,
        });
      }
    }
    const agency = agencyByUser.get(id);
    const agencyUrl = wearText(agency && agency.badge_url).trim();
    if (agencyUrl) {
      badges.push({
        name: wearText(agency.name).trim() || "Agency",
        image_url: agencyUrl,
        level: Number(agency.level) || 0,
        type: "agency",
        priority: 5,
        refId: agency.agency_id ? String(agency.agency_id) : null,
      });
    }
    badges.sort((a, b) => a.priority - b.priority);
    seat.user.frame_image_url = frameImage;
    seat.user.frame_svga_url = frameSvga;
    seat.user.badges = badges;
  }
}
async function loadRoomMeta(roomId) {
  const { rows: rows } = await query(
    `SELECT id, title, host_id, announcement, admin_only_chat, online_users_count,\n            youtube_state, shared_audio_state, background_url, mic_count, party_mode\n     FROM rooms WHERE id = $1 LIMIT 1`,
    [roomId],
  );
  return rows[0] || null;
}
async function updateRoomSharedAudioState(roomId, sharedAudioState) {
  if (!roomId) return null;
  const { rows: rows } = await query(
    `UPDATE rooms\n     SET shared_audio_state = $2::jsonb\n     WHERE id = $1\n     RETURNING id`,
    [roomId, JSON.stringify(sharedAudioState ?? {})],
  );
  return rows[0] || null;
}
const SUPER_BD_TTL_MS = 6e4;
const superBdCache = new Map();
async function isSuperBd(userId) {
  if (!userId) return false;
  const hit = superBdCache.get(userId);
  if (hit && hit.expires > Date.now()) return hit.value;
  const { rows: rows } = await query(
    `SELECT 1 FROM business_staff\n     WHERE user_id = $1 AND is_active = true AND role = 'super_bd'\n     LIMIT 1`,
    [userId],
  );
  const value = !!rows[0];
  superBdCache.set(userId, {
    value: value,
    expires: Date.now() + SUPER_BD_TTL_MS,
  });
  return value;
}
async function seatClaim({
  roomId: roomId,
  userId: userId,
  seatIndex: seatIndex,
  isMuted: isMuted,
}) {
  const bypassLock = await isSuperBd(userId);
  const conflictWhere = bypassLock
    ? ` WHERE (room_seats.user_id IS NULL\n              OR room_seats.user_id = EXCLUDED.user_id)`
    : ` WHERE room_seats.is_locked = false\n         AND (room_seats.user_id IS NULL\n              OR room_seats.user_id = EXCLUDED.user_id)`;
  const p = getPool();
  if (!p) throw new Error("DATABASE_URL not configured");
  const client = await p.connect();
  try {
    await client.query("BEGIN");
    const { rows: clearedRows } = await client.query(
      `DELETE FROM room_seats
       WHERE room_id = $1 AND user_id = $2 AND seat_index <> $3
       RETURNING seat_index`,
      [roomId, userId, seatIndex],
    );
    const { rows: rows } = await client.query(
      `INSERT INTO room_seats (room_id, user_id, seat_index, is_muted, is_locked)
       VALUES ($1, $2, $3, $4, false)
       ON CONFLICT (room_id, seat_index)
       DO UPDATE SET user_id = EXCLUDED.user_id, is_muted = EXCLUDED.is_muted,
                     is_locked = false, updated_at = now()
      ${conflictWhere}
       RETURNING id, room_id, user_id, seat_index, is_muted, is_locked`,
      [roomId, userId, seatIndex, !!isMuted],
    );
    if (rows[0]) {
      await client.query("COMMIT");
      return {
        ...rows[0],
        vacated_seat_index: clearedRows[0]
          ? clearedRows[0].seat_index
          : null,
      };
    }
    await client.query("ROLLBACK");
    const { rows: holder } = await client.query(
      `SELECT user_id, is_locked FROM room_seats
       WHERE room_id = $1 AND seat_index = $2
       LIMIT 1`,
      [roomId, seatIndex],
    );
    if (!holder[0]) return null;
    const err = new Error("seat_unavailable");
    err.code = "seat_unavailable";
    err.occupantId = holder[0].user_id ?? null;
    err.locked = !!holder[0].is_locked;
    throw err;
  } catch (e) {
    try {
      await client.query("ROLLBACK");
    } catch (_) {
    }
    throw e;
  } finally {
    client.release();
  }
}
async function seatLeave({
  roomId: roomId,
  userId: userId,
  seatRowId: seatRowId,
}) {
  let seatIndex = null;
  if (seatRowId) {
    const { rows: rows } = await query(
      `SELECT seat_index FROM room_seats\n       WHERE id = $1 AND room_id = $2 AND user_id = $3\n       LIMIT 1`,
      [seatRowId, roomId, userId],
    );
    if (rows[0]) seatIndex = rows[0].seat_index;
    await query(
      `DELETE FROM room_seats WHERE id = $1 AND room_id = $2 AND user_id = $3`,
      [seatRowId, roomId, userId],
    );
  }
  if (seatIndex == null) {
    const { rows: rows } = await query(
      `SELECT seat_index FROM room_seats\n       WHERE room_id = $1 AND user_id = $2\n       ORDER BY seat_index ASC\n       LIMIT 1`,
      [roomId, userId],
    );
    if (rows[0]) seatIndex = rows[0].seat_index;
  }
  await query(`DELETE FROM room_seats WHERE room_id = $1 AND user_id = $2`, [
    roomId,
    userId,
  ]);
  return seatIndex;
}
async function seatLeaveOtherRooms({ userId: userId, keepRoomId: keepRoomId }) {
  if (!userId) return [];
  const { rows: rows } = await query(
    `DELETE FROM room_seats\n     WHERE user_id = $1\n       AND ($2::uuid IS NULL OR room_id <> $2::uuid)\n     RETURNING room_id, seat_index`,
    [userId, keepRoomId || null],
  );
  return rows || [];
}
async function seatMute({
  roomId: roomId,
  userId: userId,
  seatIndex: seatIndex,
  isMuted: isMuted,
}) {
  const primary = await query(
    `UPDATE room_seats SET is_muted = $1, updated_at = now()\n     WHERE room_id = $2 AND user_id = $3\n     RETURNING id, room_id, user_id, seat_index, is_muted, is_locked`,
    [!!isMuted, roomId, userId],
  );
  if (primary.rowCount > 0) {
    return primary.rows[0];
  }
  if (seatIndex == null || Number.isNaN(Number(seatIndex))) {
    const err = new Error("seat mute: no seat row for user");
    err.status = 404;
    throw err;
  }
  const upsert = await query(
    `INSERT INTO room_seats (room_id, user_id, seat_index, is_muted, is_locked)\n     VALUES ($1, $2, $3, $4, false)\n     ON CONFLICT (room_id, seat_index)\n     DO UPDATE SET\n       user_id = EXCLUDED.user_id,\n       is_muted = EXCLUDED.is_muted,\n       is_locked = false,\n       updated_at = now()\n     WHERE room_seats.is_locked = false\n        OR room_seats.user_id IS NULL\n        OR room_seats.user_id = EXCLUDED.user_id\n     RETURNING id, room_id, user_id, seat_index, is_muted, is_locked`,
    [roomId, userId, seatIndex, !!isMuted],
  );
  if (!upsert.rowCount) {
    const err = new Error("seat mute: seat locked or unavailable");
    err.status = 409;
    throw err;
  }
  return upsert.rows[0];
}
async function seatLock({
  roomId: roomId,
  seatIndex: seatIndex,
  isLocked: isLocked,
}) {
  if (isLocked) {
    await query(
      `INSERT INTO room_seats (room_id, seat_index, is_locked, is_muted)\n       VALUES ($1, $2, true, false)\n       ON CONFLICT (room_id, seat_index)\n       DO UPDATE SET is_locked = true, user_id = NULL, updated_at = now()`,
      [roomId, seatIndex],
    );
  } else {
    await query(
      `UPDATE room_seats SET is_locked = false, updated_at = now()\n       WHERE room_id = $1 AND seat_index = $2`,
      [roomId, seatIndex],
    );
  }
}
async function insertChat({
  roomId: roomId,
  userId: userId,
  content: content,
  eventId: eventId,
  type: type = "chat",
  metadata: metadata = {},
}) {
  const meta = metadata && typeof metadata === "object" ? { ...metadata } : {};
  meta.event_id = eventId;
  const { rows: rows } = await query(
    `INSERT INTO room_messages (room_id, user_id, content, type, metadata)\n     VALUES ($1, $2, $3, $4, $5::jsonb)\n     RETURNING id, room_id, user_id, content, type, metadata, created_at`,
    [roomId, userId, content, type, JSON.stringify(meta)],
  );
  return rows[0];
}
async function getConversationForUser(conversationId, userId) {
  const { rows: rows } = await query(
    `SELECT id, participant_1_id, participant_2_id, status, last_message_at\n     FROM conversations\n     WHERE id = $1\n       AND (participant_1_id = $2 OR participant_2_id = $2)\n     LIMIT 1`,
    [conversationId, userId],
  );
  return rows[0] || null;
}
async function insertDmMessage({
  conversationId: conversationId,
  senderId: senderId,
  content: content,
  messageType: messageType = "text",
  mediaUrl: mediaUrl = null,
  metadata: metadata = {},
}) {
  const meta = metadata && typeof metadata === "object" ? { ...metadata } : {};
  const tempId = meta.temp_id ? String(meta.temp_id) : null;
  if (tempId) {
    const { rows: existing } = await query(
      `SELECT id, conversation_id, sender_id, content, message_type, media_url,\n              metadata, is_read, created_at\n       FROM chat_messages\n       WHERE conversation_id = $1\n         AND metadata->>'temp_id' = $2\n       LIMIT 1`,
      [conversationId, tempId],
    );
    if (existing[0]) {
      return { row: existing[0], duplicate: true };
    }
  }
  const { rows: rows } = await query(
    `INSERT INTO chat_messages\n       (conversation_id, sender_id, content, message_type, media_url, metadata)\n     VALUES ($1, $2, $3, $4, $5, $6::jsonb)\n     RETURNING id, conversation_id, sender_id, content, message_type, media_url,\n               metadata, is_read, created_at`,
    [
      conversationId,
      senderId,
      content ?? null,
      messageType || "text",
      mediaUrl ?? null,
      JSON.stringify(meta),
    ],
  );
  const nowIso = new Date().toISOString();
  await Promise.all([
    query(
      `UPDATE conversations SET last_message_at = $2::timestamptz WHERE id = $1`,
      [conversationId, nowIso],
    ),
    query(`UPDATE users SET updated_at = $2::timestamptz WHERE id = $1`, [
      senderId,
      nowIso,
    ]),
  ]);
  return { row: rows[0], duplicate: false };
}
async function markDmRead({
  conversationId: conversationId,
  readerId: readerId,
}) {
  const { rows: rows } = await query(
    `UPDATE chat_messages\n     SET is_read = true\n     WHERE conversation_id = $1\n       AND sender_id <> $2\n       AND is_read = false\n     RETURNING id`,
    [conversationId, readerId],
  );
  return rows.map((r) => r.id);
}
async function fetchDmSince({
  conversationId: conversationId,
  afterTs: afterTs,
  afterId: afterId,
  limit: limit = 100,
}) {
  const cap = Math.min(Math.max(Number(limit) || 100, 1), 100);
  if (afterId) {
    const { rows: rows } = await query(
      `SELECT id, conversation_id, sender_id, content, message_type, media_url,\n              metadata, is_read, created_at\n       FROM chat_messages\n       WHERE conversation_id = $1\n         AND created_at > (\n           SELECT created_at FROM chat_messages WHERE id = $2\n         )\n       ORDER BY created_at ASC\n       LIMIT $3`,
      [conversationId, afterId, cap],
    );
    return rows;
  }
  if (afterTs) {
    const { rows: rows } = await query(
      `SELECT id, conversation_id, sender_id, content, message_type, media_url,\n              metadata, is_read, created_at\n       FROM chat_messages\n       WHERE conversation_id = $1\n         AND created_at > $2::timestamptz\n       ORDER BY created_at ASC\n       LIMIT $3`,
      [conversationId, afterTs, cap],
    );
    return rows;
  }
  const { rows: rows } = await query(
    `SELECT id, conversation_id, sender_id, content, message_type, media_url,\n            metadata, is_read, created_at\n     FROM chat_messages\n     WHERE conversation_id = $1\n     ORDER BY created_at DESC\n     LIMIT $2`,
    [conversationId, cap],
  );
  return rows;
}
async function fetchInboxForUser({
  userId: userId,
  afterTs: afterTs = null,
  limit: limit = 100,
}) {
  const cap = Math.min(Math.max(Number(limit) || 100, 1), 200);
  const params = [userId];
  let sinceClause = "";
  if (afterTs) {
    params.push(afterTs);
    sinceClause = `AND c.last_message_at > $2::timestamptz`;
  }
  params.push(cap);
  const limitIdx = params.length;
  const { rows: rows } = await query(
    `SELECT\n        c.id,\n        c.participant_1_id,\n        c.participant_2_id,\n        c.status,\n        c.last_message_at,\n        c.created_at,\n        CASE WHEN c.participant_1_id = $1 THEN c.participant_2_id\n             ELSE c.participant_1_id END AS other_user_id,\n        u.username AS other_username,\n        u.avatar_url AS other_avatar_url,\n        u.updated_at AS other_updated_at,\n        u.short_id AS other_short_id,\n        lm.id AS last_message_id,\n        lm.content AS last_message_content,\n        lm.message_type AS last_message_type,\n        lm.media_url AS last_message_media_url,\n        lm.sender_id AS last_message_sender_id,\n        lm.created_at AS last_message_created_at,\n        lm.metadata AS last_message_metadata,\n        (\n          SELECT COUNT(*)::int FROM chat_messages m\n          WHERE m.conversation_id = c.id\n            AND m.sender_id <> $1\n            AND m.is_read = false\n        ) AS unread_count\n     FROM conversations c\n     JOIN users u ON u.id = CASE\n       WHEN c.participant_1_id = $1 THEN c.participant_2_id\n       ELSE c.participant_1_id END\n     LEFT JOIN LATERAL (\n       SELECT id, content, message_type, media_url, sender_id, created_at, metadata\n       FROM chat_messages\n       WHERE conversation_id = c.id\n       ORDER BY created_at DESC\n       LIMIT 1\n     ) lm ON true\n     WHERE (c.participant_1_id = $1 OR c.participant_2_id = $1)\n       ${sinceClause}\n     ORDER BY c.last_message_at DESC NULLS LAST\n     LIMIT $${limitIdx}`,
    params,
  );
  return rows;
}
async function countUnreadForUser(conversationId, userId) {
  const { rows: rows } = await query(
    `SELECT COUNT(*)::int AS n FROM chat_messages\n     WHERE conversation_id = $1 AND sender_id <> $2 AND is_read = false`,
    [conversationId, userId],
  );
  return rows[0]?.n ?? 0;
}
async function upsertMember({ roomId: roomId, userId: userId }) {
  const { rows: existing } = await query(
    `SELECT role FROM room_members WHERE room_id = $1 AND user_id = $2`,
    [roomId, userId],
  );
  if (existing[0] && existing[0].role !== "member") return;
  await query(
    `INSERT INTO room_members (room_id, user_id, role, joined_at)\n     VALUES ($1, $2, 'member', now())\n     ON CONFLICT (room_id, user_id)\n     DO UPDATE SET joined_at = EXCLUDED.joined_at\n     WHERE room_members.role = 'member'`,
    [roomId, userId],
  );
}
async function reportPresence(roomId, count) {
  await query(`SELECT report_room_presence($1::uuid, $2::int)`, [
    roomId,
    count,
  ]);
}
async function reportActivity(roomId, isOnMic) {
  await query(`SELECT report_room_activity($1::uuid, $2::boolean)`, [
    roomId,
    !!isOnMic,
  ]);
}
async function loadSeatGiftTotals(roomId) {
  const { rows: rows } = await query(
    `SELECT e.host_id AS user_id, COALESCE(SUM(e.host_amount), 0)::int AS total\n     FROM earning_logs e\n     INNER JOIN gift_logs g ON g.id = e.gift_log_id\n     WHERE g.room_id = $1 AND e.host_amount > 0\n     GROUP BY e.host_id`,
    [roomId],
  );
  const out = {};
  for (const r of rows) {
    if (r.user_id) out[r.user_id] = Number(r.total) || 0;
  }
  return out;
}
async function canManageRoom(roomId, userId) {
  if (!roomId || !userId) return false;
  const { rows: hosts } = await query(
    `SELECT 1 FROM rooms WHERE id = $1 AND host_id = $2 LIMIT 1`,
    [roomId, userId],
  );
  if (hosts[0]) return true;
  const { rows: members } = await query(
    `SELECT 1 FROM room_members\n     WHERE room_id = $1 AND user_id = $2 AND role IN ('host', 'admin')\n     LIMIT 1`,
    [roomId, userId],
  );
  return !!members[0];
}
async function loadUserPublic(userId) {
  if (!userId || String(userId).startsWith("anon:")) {
    return { id: userId || null };
  }
  try {
    const { rows: rows } = await query(
      `SELECT id, username, avatar_url, vip_level, short_id\n       FROM public.users\n       WHERE id = $1\n       LIMIT 1`,
      [userId],
    );
    if (rows[0]) {
      return {
        id: rows[0].id,
        username: rows[0].username || "User",
        avatar_url: rows[0].avatar_url || null,
        vip_level: rows[0].vip_level ?? 0,
        short_id: rows[0].short_id ?? null,
      };
    }
  } catch (err) {
    console.warn("[db] loadUserPublic failed:", err.message);
  }
  return { id: userId, username: "User", avatar_url: null };
}
async function resolveSeatTargetUserId({
  roomId: roomId,
  actorUserId: actorUserId,
  requestedUserId: requestedUserId,
}) {
  const requested = requestedUserId ? String(requestedUserId) : "";
  if (!requested || requested === actorUserId) return actorUserId;
  const allowed =
    (await canManageRoom(roomId, actorUserId)) ||
    (await isSuperBd(actorUserId));
  if (!allowed) {
    const err = new Error("not allowed to manage this seat");
    err.statusCode = 403;
    throw err;
  }
  if (await isSuperBd(requested)) {
    const err = new Error("cannot moderate a Super Admin");
    err.statusCode = 403;
    throw err;
  }
  return requested;
}

async function getActiveRoomKick(roomId, userId) {
  if (!roomId || !userId) return null;
  const { rows } = await query(
    `SELECT id, expires_at, reason
     FROM room_kicks
     WHERE room_id = $1
       AND user_id = $2
       AND (expires_at IS NULL OR expires_at > now())
     ORDER BY kicked_at DESC NULLS LAST
     LIMIT 1`,
    [roomId, userId],
  );
  return rows[0] || null;
}

module.exports = {
  getPool: getPool,
  query: query,
  getGamePool: getGamePool,
  withGameClient: withGameClient,
  getGiftPool: getGiftPool,
  giftQuery: giftQuery,
  loadRoomSeats: loadRoomSeats,
  loadRoomMeta: loadRoomMeta,
  updateRoomSharedAudioState: updateRoomSharedAudioState,
  isSuperBd: isSuperBd,
  getActiveRoomKick: getActiveRoomKick,
  seatClaim: seatClaim,
  seatLeave: seatLeave,
  seatLeaveOtherRooms: seatLeaveOtherRooms,
  seatMute: seatMute,
  seatLock: seatLock,
  insertChat: insertChat,
  getConversationForUser: getConversationForUser,
  insertDmMessage: insertDmMessage,
  markDmRead: markDmRead,
  fetchDmSince: fetchDmSince,
  fetchInboxForUser: fetchInboxForUser,
  countUnreadForUser: countUnreadForUser,
  upsertMember: upsertMember,
  reportPresence: reportPresence,
  reportActivity: reportActivity,
  loadSeatGiftTotals: loadSeatGiftTotals,
  canManageRoom: canManageRoom,
  resolveSeatTargetUserId: resolveSeatTargetUserId,
  loadUserPublic: loadUserPublic,
};
