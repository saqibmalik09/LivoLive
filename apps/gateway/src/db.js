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
async function loadRoomSeats(roomId) {
  const { rows: rows } = await query(
    `SELECT s.id, s.room_id, s.user_id, s.seat_index, s.is_muted, s.is_locked, s.updated_at,\n            u.username, u.avatar_url, u.vip_level\n     FROM room_seats s\n     LEFT JOIN users u ON u.id = s.user_id\n     WHERE s.room_id = $1\n     ORDER BY s.seat_index ASC`,
    [roomId],
  );
  return rows.map((r) => ({
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
  // The claim must land BEFORE the old seat is released. Previously the DELETE
  // sat in its own CTE, and a data-modifying CTE always runs — so a rejected
  // claim (seat taken or locked) still vacated the seat the user was already
  // on, leaving them on no seat while the UI still showed them seated. That
  // mismatch is what surfaced as a duplicated user plus an error on mic move.
  // Referencing `ins` from `cleared` makes the delete conditional on the insert
  // actually returning a row.
  const { rows: rows } = await query(
    `WITH ins AS (\n       INSERT INTO room_seats (room_id, user_id, seat_index, is_muted, is_locked)\n       VALUES ($1, $2, $3, $4, false)\n       ON CONFLICT (room_id, seat_index)\n       DO UPDATE SET user_id = EXCLUDED.user_id, is_muted = EXCLUDED.is_muted,\n                     is_locked = false, updated_at = now()\n      ${conflictWhere}\n       RETURNING id, room_id, user_id, seat_index, is_muted, is_locked\n     ), cleared AS (\n       DELETE FROM room_seats\n       WHERE room_id = $1 AND user_id = $2 AND seat_index <> $3\n         AND EXISTS (SELECT 1 FROM ins)\n       RETURNING seat_index\n     )\n     SELECT ins.*, (SELECT seat_index FROM cleared LIMIT 1) AS vacated_seat_index\n     FROM ins`,
    [roomId, userId, seatIndex, !!isMuted],
  );
  if (rows[0]) return rows[0];
  const { rows: holder } = await query(
    `SELECT user_id, is_locked FROM room_seats\n     WHERE room_id = $1 AND seat_index = $2\n     LIMIT 1`,
    [roomId, seatIndex],
  );
  if (!holder[0]) return null;
  const err = new Error("seat_unavailable");
  err.code = "seat_unavailable";
  err.occupantId = holder[0].user_id ?? null;
  err.locked = !!holder[0].is_locked;
  throw err;
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
