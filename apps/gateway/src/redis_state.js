const PRESENCE_TTL_SEC = Number(process.env.PRESENCE_TTL_SEC || 90);
function seatsKey(roomId) {
  return `room:${roomId}:seats`;
}
function presenceKey(roomId) {
  return `room:${roomId}:presence`;
}
function presenceUserKey(roomId, userId) {
  return `room:${roomId}:presence:${userId}`;
}
function presenceListKey(roomId) {
  return `room:${roomId}:presence_list`;
}
function seatWearKey(userId) {
  return `wear:user:${userId}`;
}
function userPresenceRoomKey(userId) {
  return `presence:user:${userId}`;
}
function seqKey(roomId) {
  return `room:${roomId}:seq`;
}
function metaKey(roomId) {
  return `room:${roomId}:meta`;
}
function seatGiftsKey(roomId) {
  return `room:${roomId}:seat_gifts`;
}
function youtubeStateKey(roomId) {
  return `room:${roomId}:youtube_state`;
}
function sharedAudioStateKey(roomId) {
  return `room:${roomId}:shared_audio_state`;
}
const SEAT_GIFTS_TTL_SEC = Number(process.env.SEAT_GIFTS_TTL_SEC || 86400);
const MEDIA_STATE_TTL_SEC = Number(process.env.MEDIA_STATE_TTL_SEC || 3600);
// Presence list cache. Reading presence used to cost 1 SMEMBERS + 1 GET per
// member, so a snapshot in a busy room ran N+1 Redis commands and every join
// paid it again. The rebuilt list is cached for a few seconds and dropped on
// join/leave, so repeat reads are a single GET and staleness stays bounded by
// the per-user TTL the sweep already relies on.
const PRESENCE_LIST_TTL_SEC = Number(process.env.PRESENCE_LIST_TTL_SEC || 15);
// Short enough that buying a frame shows up on your seat without a restart,
// long enough that a busy room resolves wear from Redis instead of SQL.
const SEAT_WEAR_TTL_SEC = Number(process.env.SEAT_WEAR_TTL_SEC || 120);
async function _setJson(redis, key, value, ttlSec) {
  if (!key || value == null) return;
  await redis.set(key, JSON.stringify(value), "EX", ttlSec);
}
async function _getJson(redis, key) {
  const raw = await redis.get(key);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}
async function setYoutubeState(redis, roomId, mediaState) {
  if (!roomId || !mediaState) return;
  await _setJson(
    redis,
    youtubeStateKey(roomId),
    mediaState,
    MEDIA_STATE_TTL_SEC,
  );
}
async function getYoutubeState(redis, roomId) {
  if (!roomId) return null;
  return _getJson(redis, youtubeStateKey(roomId));
}
async function setSharedAudioState(redis, roomId, mediaState) {
  if (!roomId || !mediaState) return;
  await _setJson(
    redis,
    sharedAudioStateKey(roomId),
    mediaState,
    MEDIA_STATE_TTL_SEC,
  );
}
async function getSharedAudioState(redis, roomId) {
  if (!roomId) return null;
  return _getJson(redis, sharedAudioStateKey(roomId));
}
async function clearMediaStates(redis, roomId) {
  if (!roomId) return;
  await redis.del(youtubeStateKey(roomId), sharedAudioStateKey(roomId));
}
async function nextSeq(redis, roomId) {
  return redis.incr(seqKey(roomId));
}
async function setSeatsSnapshot(redis, roomId, seats) {
  await redis.set(seatsKey(roomId), JSON.stringify(seats), "EX", 3600);
}
async function getSeatsSnapshot(redis, roomId) {
  const raw = await redis.get(seatsKey(roomId));
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}
async function setMetaSnapshot(redis, roomId, meta) {
  if (!meta) return;
  await redis.set(metaKey(roomId), JSON.stringify(meta), "EX", 3600);
}
async function getMetaSnapshot(redis, roomId) {
  const raw = await redis.get(metaKey(roomId));
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}
async function incrSeatGiftTotals(redis, roomId, deltas) {
  if (!roomId || !deltas || typeof deltas !== "object") return {};
  const key = seatGiftsKey(roomId);
  const pipe = redis.pipeline();
  let any = false;
  for (const [userId, amount] of Object.entries(deltas)) {
    const n = Number(amount) || 0;
    if (!userId || n <= 0) continue;
    pipe.hincrby(key, String(userId), n);
    any = true;
  }
  if (!any) return getSeatGiftTotals(redis, roomId);
  pipe.expire(key, SEAT_GIFTS_TTL_SEC);
  await pipe.exec();
  return getSeatGiftTotals(redis, roomId);
}
async function setSeatGiftTotals(redis, roomId, totals) {
  if (!roomId || !totals || typeof totals !== "object") return;
  const key = seatGiftsKey(roomId);
  const entries = Object.entries(totals).filter(
    ([id, n]) => id && Number(n) > 0,
  );
  if (!entries.length) return;
  const pipe = redis.pipeline();
  pipe.del(key);
  for (const [userId, amount] of entries) {
    pipe.hset(key, String(userId), String(Number(amount) || 0));
  }
  pipe.expire(key, SEAT_GIFTS_TTL_SEC);
  await pipe.exec();
}
async function clearSeatGiftTotals(redis, roomId) {
  if (!roomId) return;
  await redis.del(seatGiftsKey(roomId));
}
async function getSeatGiftTotals(redis, roomId) {
  const raw = await redis.hgetall(seatGiftsKey(roomId));
  if (!raw || typeof raw !== "object") return {};
  const out = {};
  for (const [userId, amount] of Object.entries(raw)) {
    const n = Number(amount) || 0;
    if (userId && n > 0) out[userId] = n;
  }
  return out;
}
async function presenceJoin(
  redis,
  roomId,
  userId,
  userPayload,
  ttlSec = PRESENCE_TTL_SEC,
) {
  const ttl = Math.max(15, Number(ttlSec) || PRESENCE_TTL_SEC);
  const prev = await redis.get(userPresenceRoomKey(userId));
  const pipe = redis.pipeline();
  if (prev && prev !== roomId) {
    pipe.srem(presenceKey(prev), userId);
    pipe.del(presenceUserKey(prev, userId));
  }
  pipe.sadd(presenceKey(roomId), userId);
  pipe.set(
    presenceUserKey(roomId, userId),
    JSON.stringify(userPayload || { id: userId }),
    "EX",
    ttl,
  );
  pipe.set(userPresenceRoomKey(userId), roomId, "EX", ttl);
  pipe.del(presenceListKey(roomId));
  if (prev && prev !== roomId) pipe.del(presenceListKey(prev));
  await pipe.exec();
}
async function presenceLeave(redis, roomId, userId) {
  const tracked = await redis.get(userPresenceRoomKey(userId));
  const pipe = redis.pipeline();
  pipe.srem(presenceKey(roomId), userId);
  pipe.del(presenceUserKey(roomId, userId));
  if (tracked === roomId) {
    pipe.del(userPresenceRoomKey(userId));
  }
  pipe.del(presenceListKey(roomId));
  await pipe.exec();
}
async function getUserPresenceRoom(redis, userId) {
  if (!userId) return null;
  return redis.get(userPresenceRoomKey(userId));
}
async function presenceHeartbeat(redis, roomId, userId, userPayload, ttlSec) {
  await presenceJoin(redis, roomId, userId, userPayload, ttlSec);
}
async function listPresence(redis, roomId) {
  const cached = await redis.get(presenceListKey(roomId));
  if (cached) {
    try {
      const parsed = JSON.parse(cached);
      if (Array.isArray(parsed)) return parsed;
    } catch {
      // fall through and rebuild
    }
  }
  const users = await rebuildPresenceList(redis, roomId);
  await redis.set(
    presenceListKey(roomId),
    JSON.stringify(users),
    "EX",
    PRESENCE_LIST_TTL_SEC,
  );
  return users;
}
async function rebuildPresenceList(redis, roomId) {
  const ids = await redis.smembers(presenceKey(roomId));
  if (!ids.length) return [];
  const pipe = redis.pipeline();
  for (const id of ids) pipe.get(presenceUserKey(roomId, id));
  const results = await pipe.exec();
  const users = [];
  const stale = [];
  results.forEach((entry, i) => {
    const raw = entry && entry[1];
    if (!raw) {
      stale.push(ids[i]);
      return;
    }
    try {
      users.push(JSON.parse(raw));
    } catch {
      stale.push(ids[i]);
    }
  });
  if (stale.length) {
    const clean = redis.pipeline();
    for (const id of stale) {
      clean.srem(presenceKey(roomId), id);
      clean.del(presenceUserKey(roomId, id));
    }
    await clean.exec();
  }
  return users;
}
async function presenceCount(redis, roomId) {
  return redis.scard(presenceKey(roomId));
}
// Seat wear (frame + badges) per user. The SQL behind it joins inventory,
// level assets, couples and agency rankings, so it is the expensive part of a
// seat snapshot. Cached per user rather than per room: the same person is on a
// seat across rejoins and in several rooms over a session.
async function mgetSeatWear(redis, userIds) {
  const ids = [...new Set((userIds || []).map(String).filter(Boolean))];
  if (!ids.length) return new Map();
  const out = new Map();
  const raw = await redis.mget(ids.map(seatWearKey));
  ids.forEach((id, i) => {
    const value = raw?.[i];
    if (!value) return;
    try {
      const parsed = JSON.parse(value);
      if (parsed && typeof parsed === "object") out.set(id, parsed);
    } catch {
      // treat unparseable as a miss
    }
  });
  return out;
}
async function msetSeatWear(redis, wearByUser, ttlSec = SEAT_WEAR_TTL_SEC) {
  if (!wearByUser || typeof wearByUser.forEach !== "function") return;
  const ttl = Math.max(30, Number(ttlSec) || SEAT_WEAR_TTL_SEC);
  const pipe = redis.pipeline();
  let any = false;
  wearByUser.forEach((wear, userId) => {
    if (!userId || !wear || typeof wear !== "object") return;
    pipe.set(seatWearKey(String(userId)), JSON.stringify(wear), "EX", ttl);
    any = true;
  });
  if (any) await pipe.exec();
}
async function clearSeatWear(redis, userIds) {
  const ids = [...new Set((userIds || []).map(String).filter(Boolean))];
  if (!ids.length) return;
  await redis.del(...ids.map(seatWearKey));
}
const APP_ONLINE_TTL_SEC = Number(process.env.APP_ONLINE_TTL_SEC || 90);
function appOnlineKey(userId) {
  return `app:online:${userId}`;
}
function appWatchersKey(userId) {
  return `app:watchers:${userId}`;
}
async function setAppOnline(redis, userId, ttlSec = APP_ONLINE_TTL_SEC) {
  if (!userId) return;
  await redis.set(
    appOnlineKey(userId),
    JSON.stringify({ at: Date.now() }),
    "EX",
    ttlSec,
  );
}
async function clearAppOnline(redis, userId) {
  if (!userId) return;
  await redis.del(appOnlineKey(userId));
}
async function isAppOnline(redis, userId) {
  if (!userId) return false;
  const n = await redis.exists(appOnlineKey(userId));
  return n === 1;
}
async function mgetAppOnline(redis, userIds) {
  const out = {};
  const ids = [...new Set((userIds || []).map(String).filter(Boolean))];
  if (!ids.length) return out;
  const pipe = redis.pipeline();
  for (const id of ids) pipe.exists(appOnlineKey(id));
  const res = await pipe.exec();
  ids.forEach((id, i) => {
    const row = res?.[i];
    out[id] = Array.isArray(row) ? Number(row[1]) === 1 : false;
  });
  return out;
}
async function addAppWatcher(redis, targetUserId, watcherUserId) {
  if (!targetUserId || !watcherUserId || targetUserId === watcherUserId) return;
  const key = appWatchersKey(targetUserId);
  await redis.sadd(key, watcherUserId);
  await redis.expire(key, 86400);
}
async function removeAppWatcher(redis, targetUserId, watcherUserId) {
  if (!targetUserId || !watcherUserId) return;
  await redis.srem(appWatchersKey(targetUserId), watcherUserId);
}
async function getAppWatchers(redis, targetUserId) {
  if (!targetUserId) return [];
  return redis.smembers(appWatchersKey(targetUserId));
}
module.exports = {
  PRESENCE_TTL_SEC: PRESENCE_TTL_SEC,
  MEDIA_STATE_TTL_SEC: MEDIA_STATE_TTL_SEC,
  APP_ONLINE_TTL_SEC: APP_ONLINE_TTL_SEC,
  SEAT_WEAR_TTL_SEC: SEAT_WEAR_TTL_SEC,
  nextSeq: nextSeq,
  setSeatsSnapshot: setSeatsSnapshot,
  getSeatsSnapshot: getSeatsSnapshot,
  setMetaSnapshot: setMetaSnapshot,
  getMetaSnapshot: getMetaSnapshot,
  incrSeatGiftTotals: incrSeatGiftTotals,
  setSeatGiftTotals: setSeatGiftTotals,
  clearSeatGiftTotals: clearSeatGiftTotals,
  getSeatGiftTotals: getSeatGiftTotals,
  setYoutubeState: setYoutubeState,
  getYoutubeState: getYoutubeState,
  setSharedAudioState: setSharedAudioState,
  getSharedAudioState: getSharedAudioState,
  clearMediaStates: clearMediaStates,
  presenceJoin: presenceJoin,
  presenceLeave: presenceLeave,
  presenceHeartbeat: presenceHeartbeat,
  getUserPresenceRoom: getUserPresenceRoom,
  listPresence: listPresence,
  presenceCount: presenceCount,
  mgetSeatWear: mgetSeatWear,
  msetSeatWear: msetSeatWear,
  clearSeatWear: clearSeatWear,
  setAppOnline: setAppOnline,
  clearAppOnline: clearAppOnline,
  isAppOnline: isAppOnline,
  mgetAppOnline: mgetAppOnline,
  addAppWatcher: addAppWatcher,
  removeAppWatcher: removeAppWatcher,
  getAppWatchers: getAppWatchers,
};
