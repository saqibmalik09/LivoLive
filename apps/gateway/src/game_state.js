const PHASE_CHANNEL = "game:phase";
const LIVE_TTL_SEC = 120;
function liveKey(slug) {
  return `game:${String(slug)}:live`;
}
function seqKey(slug) {
  return `game:${String(slug)}:seq`;
}
function normalizeSlug(slug) {
  return String(slug || "")
    .trim()
    .toLowerCase()
    .replace(/_/g, "-");
}
const SLUG_ALIASES = {
  "car-roulette": "car_roulette",
  car_roulette: "car_roulette",
  football: "football_roulette",
  "football-roulette": "football_roulette",
  football_roulette: "football_roulette",
  pizza: "pizza_express",
  "pizza-express": "pizza_express",
  pizza_express: "pizza_express",
  greedy: "greedy_king",
  "greedy-king": "greedy_king",
  greedy_king: "greedy_king",
  fruit: "fruit_party",
  "fruit-party": "fruit_party",
  fruit_party: "fruit_party",
  "teen-patti": "teen_patti",
  teen_patti: "teen_patti",
  77: "lucky_777",
  "lucky-777": "lucky_777",
  lucky: "lucky_777",
  lucky_777: "lucky_777",
};
function canonicalSlug(input) {
  const raw = String(input || "").trim();
  if (!raw) return "";
  const lower = raw.toLowerCase();
  if (SLUG_ALIASES[lower]) return SLUG_ALIASES[lower];
  if (SLUG_ALIASES[normalizeSlug(lower)])
    return SLUG_ALIASES[normalizeSlug(lower)];
  return lower.replace(/-/g, "_");
}
function socketRoom(slug) {
  return `game:${canonicalSlug(slug)}`;
}
async function getLiveSnapshot(redis, slug) {
  const key = liveKey(canonicalSlug(slug));
  const raw = await redis.get(key);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}
async function setLiveSnapshot(redis, slug, payload, ttlSec = LIVE_TTL_SEC) {
  const canon = canonicalSlug(slug);
  const seq = await redis.incr(seqKey(canon));
  const snapshot = {
    ...payload,
    slug: canon,
    seq: seq,
    server_now: new Date().toISOString(),
  };
  await redis.set(liveKey(canon), JSON.stringify(snapshot), "EX", ttlSec);
  return snapshot;
}
module.exports = {
  PHASE_CHANNEL: PHASE_CHANNEL,
  LIVE_TTL_SEC: LIVE_TTL_SEC,
  liveKey: liveKey,
  seqKey: seqKey,
  canonicalSlug: canonicalSlug,
  socketRoom: socketRoom,
  getLiveSnapshot: getLiveSnapshot,
  setLiveSnapshot: setLiveSnapshot,
};
