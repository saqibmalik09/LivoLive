const { v4: uuidv4 } = require("uuid");
const db = require("./db");
function parseJson(value) {
  if (value == null) return null;
  if (typeof value === "object") return value;
  try {
    return JSON.parse(value);
  } catch (_) {
    return null;
  }
}
function normalizeCategory(name) {
  return String(name || "")
    .trim()
    .toLowerCase();
}
function isLuckyCategory(categoryName) {
  const n = normalizeCategory(categoryName);
  return n === "lucky" || n === "luck";
}
function isLuckyProCategory(categoryName) {
  const n = normalizeCategory(categoryName);
  return n === "lucky pro" || n === "lucky_pro" || n === "luckypro";
}
// Shop items barely change, yet every single tap of a combo re-read the row.
// A short TTL keeps an admin price edit visible within a minute while taking
// the lookup out of the send path.
const GIFT_CACHE_TTL_MS = Number(process.env.GIFT_CACHE_TTL_MS || 60e3);
const GIFT_CACHE_MAX = 500;
const giftCache = new Map();
function cacheGet(cache, key) {
  const hit = cache.get(key);
  if (!hit) return undefined;
  if (hit.expires <= Date.now()) {
    cache.delete(key);
    return undefined;
  }
  return hit.value;
}
function cacheSet(cache, key, value, ttlMs, maxEntries) {
  if (cache.size >= maxEntries) {
    // Oldest insertion first: enough to keep the map bounded without an LRU.
    const oldest = cache.keys().next();
    if (!oldest.done) cache.delete(oldest.value);
  }
  cache.set(key, { value: value, expires: Date.now() + ttlMs });
}
async function loadGift(giftId) {
  const key = String(giftId);
  const cached = cacheGet(giftCache, key);
  if (cached !== undefined) return cached;
  const gift = await loadGiftFromDb(giftId);
  cacheSet(giftCache, key, gift, GIFT_CACHE_TTL_MS, GIFT_CACHE_MAX);
  return gift;
}
async function loadGiftFromDb(giftId) {
  const { rows: rows } = await db.giftQuery(
    `SELECT si.id, si.name, si.price_coins,\n            coalesce(si.image_url, '') AS icon_url,\n            si.svga_url, si.is_full_screen,\n            lower(coalesce(sc.name, '')) AS category_name\n     FROM public.shop_items si\n     LEFT JOIN public.shop_categories sc ON sc.id = si.category_id\n     WHERE si.id = $1 AND si.is_active = TRUE\n     LIMIT 1`,
    [giftId],
  );
  return rows[0] || null;
}
// Display name and avatar for gift text. The same handful of people gift each
// other repeatedly in a room, so this query was re-running per tap.
const PROFILE_CACHE_TTL_MS = Number(process.env.GIFT_PROFILE_CACHE_TTL_MS || 60e3);
const PROFILE_CACHE_MAX = 5000;
const profileCache = new Map();
async function loadUsernames(userIds) {
  const ids = [
    ...new Set(
      (userIds || []).map((id) => String(id || "").trim()).filter(Boolean),
    ),
  ];
  if (!ids.length) return {};
  const out = {};
  const missing = [];
  for (const id of ids) {
    const hit = cacheGet(profileCache, id);
    if (hit !== undefined) out[id] = hit;
    else missing.push(id);
  }
  if (!missing.length) return out;
  const { rows: rows } = await db.giftQuery(
    `SELECT id::text AS id, username, avatar_url\n     FROM public.users\n     WHERE id = ANY($1::uuid[])`,
    [missing],
  );
  for (const r of rows) {
    const profile = {
      username: r.username || "User",
      avatar_url: r.avatar_url || null,
    };
    out[r.id] = profile;
    cacheSet(
      profileCache,
      r.id,
      profile,
      PROFILE_CACHE_TTL_MS,
      PROFILE_CACHE_MAX,
    );
  }
  return out;
}
function seatCreditFromRpc(rpc) {
  const charm = Number(rpc.charm_credit);
  if (Number.isFinite(charm) && charm > 0) return charm;
  const host = Number(rpc.host_received) || Number(rpc.host_share) || 0;
  return host > 0 ? host : 0;
}
async function settleGifts({
  senderId: senderId,
  receiverIds: receiverIds,
  giftId: giftId,
  roomId: roomId,
  quantity: quantity = 1,
}) {
  const targets = [
    ...new Set(
      (receiverIds || []).map((id) => String(id || "").trim()).filter(Boolean),
    ),
  ];
  if (!targets.length) {
    return { success: false, message: "No receivers", results: [] };
  }
  const qty = Math.max(1, Math.trunc(Number(quantity) || 1));
  const settled = [];
  // Prefer one DB round-trip for multi-seat sends (100k-room storms). Falls
  // back to per-receiver calls when the batch RPC is not deployed yet.
  if (targets.length > 1) {
    try {
      const { rows } = await db.giftQuery(
        `SELECT public.send_gifts_batch($1::uuid, $2::uuid[], $3::uuid, $4::uuid, $5::int, 'gateway') AS r`,
        [senderId, targets, giftId, roomId, qty],
      );
      const batch = parseJson(rows[0]?.r);
      const list = Array.isArray(batch?.results)
        ? batch.results
        : Array.isArray(batch)
          ? batch
          : null;
      if (list) {
        for (const row of list) {
          const receiverId = String(row.receiver_id || row.receiverId || "");
          const result =
            row.result && typeof row.result === "object"
              ? row.result
              : row.success != null
                ? row
                : { success: false, message: "invalid batch row" };
          settled.push({ receiver_id: receiverId, result });
        }
      }
    } catch (err) {
      if (
        !/send_gifts_batch|does not exist|function .* does not exist/i.test(
          String(err.message || ""),
        )
      ) {
        console.warn("[gift_settle] batch failed, falling back:", err.message);
      }
    }
  }
  if (!settled.length) {
    for (const receiverId of targets) {
      try {
        const { rows: rows } = await db.giftQuery(
          `SELECT public.send_gift($1::uuid, $2::uuid, $3::uuid, $4::uuid, $5::int, 'gateway') AS r`,
          [senderId, receiverId, giftId, roomId, qty],
        );
        const one = parseJson(rows[0]?.r) || {};
        settled.push({ receiver_id: receiverId, result: one });
      } catch (err) {
        settled.push({
          receiver_id: receiverId,
          result: {
            success: false,
            message: err.message || "send_gift failed",
          },
        });
      }
    }
  }
  const anyOk = settled.some(
    (row) => row.result && row.result.success === true,
  );
  const firstFail = settled.find(
    (row) => !row.result || row.result.success !== true,
  );
  return {
    success: anyOk,
    message: anyOk
      ? null
      : (firstFail && firstFail.result && firstFail.result.message) ||
        "Failed to send gift",
    results: settled,
  };
}
function buildUiMessage({
  roomId: roomId,
  senderId: senderId,
  senderUsername: senderUsername,
  senderAvatar: senderAvatar,
  targetId: targetId,
  receiverName: receiverName,
  gift: gift,
  quantity: quantity,
  animationBatchId: animationBatchId,
  eventId: eventId,
  rpc: rpc,
}) {
  const luckyBonusWon = rpc.lucky_bonus_won === true;
  const luckyBonusCoins = Number(rpc.lucky_bonus_coins) || 0;
  const isLuckyGift = rpc.is_lucky_gift === true;
  const isLuckyProGift = rpc.is_lucky_pro_gift === true;
  const luckyProBonusWon = rpc.lucky_pro_bonus_won === true;
  const luckyProBonusCoins = Number(rpc.lucky_pro_bonus_coins) || 0;
  const giftValue = (Number(gift.price_coins) || 0) * quantity;
  const giftLogId = rpc.gift_log_id ? String(rpc.gift_log_id) : null;
  const totalCost = Number(rpc.total_cost) || giftValue;
  const hostReceived = Number(rpc.host_received) || Number(rpc.host_share) || 0;
  const charmCredit = Number(rpc.charm_credit) || 0;
  let content = `sent ${quantity}x ${gift.name} to ${receiverName}`;
  if (luckyBonusWon || luckyProBonusWon) {
    const coins = luckyProBonusWon ? luckyProBonusCoins : luckyBonusCoins;
    const label = luckyProBonusWon ? "lucky pro" : "lucky";
    content = `${content} - You won ${coins} ${label} bonus!`;
  }
  const metadata = {
    event_id: eventId,
    gift_id: gift.id,
    quantity: quantity,
    target_id: targetId,
    gift_name: gift.name,
    gift_icon: gift.icon_url,
    svga_url: gift.svga_url,
    is_full_screen: gift.is_full_screen === true,
    host_received: hostReceived,
    host_share: hostReceived,
    charm_credit: charmCredit,
    price_coins: gift.price_coins,
    total_cost: totalCost,
    lucky_engine: "gateway",
    receiver_username: receiverName,
    sender_username: senderUsername,
    sender_avatar: senderAvatar,
    is_lucky_gift: isLuckyGift,
    lucky_bonus_won: luckyBonusWon,
    lucky_bonus_coins: luckyBonusCoins,
    is_lucky_pro_gift: isLuckyProGift,
    lucky_pro_bonus_won: luckyProBonusWon,
    lucky_pro_bonus_coins: luckyProBonusCoins,
    bonus_multiplier: 1,
    multiplier_tier: "x1",
    animation_batch_id: animationBatchId,
  };
  if (giftLogId) metadata.gift_log_id = giftLogId;
  return {
    id: eventId,
    room_id: roomId,
    user_id: senderId,
    content: content,
    type: "gift",
    created_at: new Date().toISOString(),
    metadata: metadata,
    user: { username: senderUsername, avatar_url: senderAvatar },
  };
}
async function buildNotifyFromSettle({
  roomId: roomId,
  senderId: senderId,
  senderUsername: senderUsername,
  senderAvatar: senderAvatar,
  gift: gift,
  quantity: quantity,
  animationBatchId: animationBatchId,
  clientOpId: clientOpId,
  settle: settle,
}) {
  const profiles = await loadUsernames(
    settle.results.map((r) => r.receiver_id).concat([senderId]),
  );
  const senderProfile = profiles[String(senderId)] || {};
  const resolvedSenderName =
    String(senderUsername || "").trim() || senderProfile.username || "User";
  const resolvedSenderAvatar = senderAvatar || senderProfile.avatar_url || null;
  const messages = [];
  const seatGiftDeltas = [];
  const outcomes = [];
  let anyLucky = false;
  let anyLuckyPro = false;
  for (const row of settle.results) {
    const receiverId = String(row.receiver_id || "");
    const rpc = row.result && typeof row.result === "object" ? row.result : {};
    const ok = rpc.success === true;
    if (!ok) {
      outcomes.push({
        success: false,
        target_id: receiverId,
        error_message: rpc.message || "Failed to send gift",
      });
      continue;
    }
    if (rpc.is_lucky_gift === true) anyLucky = true;
    if (rpc.is_lucky_pro_gift === true) anyLuckyPro = true;
    const eventId = `${clientOpId || animationBatchId}_${receiverId}`.slice(
      0,
      80,
    );
    const receiverName =
      (profiles[receiverId] && profiles[receiverId].username) || "User";
    const message = buildUiMessage({
      roomId: roomId,
      senderId: senderId,
      senderUsername: resolvedSenderName,
      senderAvatar: resolvedSenderAvatar,
      targetId: receiverId,
      receiverName: receiverName,
      gift: {
        id: gift.id,
        name: gift.name,
        price_coins: gift.price_coins,
        icon_url: gift.icon_url,
        svga_url: gift.svga_url,
        is_full_screen: gift.is_full_screen,
      },
      quantity: quantity,
      animationBatchId: animationBatchId,
      eventId: eventId,
      rpc: rpc,
    });
    messages.push(message);
    const seatAmount = seatCreditFromRpc(rpc);
    if (seatAmount > 0) {
      seatGiftDeltas.push({ user_id: receiverId, amount: seatAmount });
    }
    outcomes.push({
      success: true,
      target_id: receiverId,
      gift_log_id: rpc.gift_log_id ? String(rpc.gift_log_id) : null,
      host_received: Number(rpc.host_received) || Number(rpc.host_share) || 0,
      charm_credit: Number(rpc.charm_credit) || 0,
      seat_credit: seatAmount,
      total_cost: Number(rpc.total_cost) || 0,
      is_lucky_gift: rpc.is_lucky_gift === true,
      is_lucky_pro_gift: rpc.is_lucky_pro_gift === true,
      lucky_gifts_until_bonus:
        rpc.lucky_gifts_until_bonus != null
          ? Number(rpc.lucky_gifts_until_bonus)
          : null,
      new_wealth_level: Number(rpc.new_wealth_level) || 1,
      message: message,
    });
  }
  const successfulTargets = outcomes
    .filter((o) => o.success)
    .map((o) => o.target_id);
  const eventId = `${animationBatchId}_settle`;
  const notifyPayload = {
    event_id: eventId,
    animation_batch_id: animationBatchId,
    sender_id: senderId,
    target_ids: successfulTargets,
    gift_icon: gift.icon_url || "",
    quantity: quantity,
    is_full_screen: gift.is_full_screen === true,
    svga_url: gift.svga_url || "",
    lucky_engine: "gateway",
    settled_on_gateway: true,
    seat_gift_deltas: seatGiftDeltas,
    messages: messages,
    message: messages[0] || {},
  };
  return {
    notifyPayload: notifyPayload,
    outcomes: outcomes,
    successfulTargets: successfulTargets,
    anyLucky: anyLucky,
    anyLuckyPro: anyLuckyPro,
  };
}
// One insert for the whole batch. Gifting every seat used to run one round trip
// per receiver, so a nine-seat gift held a gift-pool connection nine times.
async function persistGiftMessages(messages) {
  const rows = (Array.isArray(messages) ? messages : []).filter(
    (msg) => msg && msg.room_id && msg.user_id,
  );
  if (!rows.length) return;
  const values = [];
  const params = [];
  for (const msg of rows) {
    const i = params.length;
    values.push(`($${i + 1}::uuid, $${i + 2}::uuid, $${i + 3}, 'gift', $${i + 4}::jsonb)`);
    params.push(
      msg.room_id,
      msg.user_id,
      msg.content,
      JSON.stringify(msg.metadata || {}),
    );
  }
  try {
    await db.giftQuery(
      `INSERT INTO public.room_messages (room_id, user_id, content, type, metadata)\n       VALUES ${values.join(", ")}`,
      params,
    );
  } catch (err) {
    console.warn("[gift_settle] room_messages insert failed:", err.message);
  }
}
const RANK_FLUSH_MS = 2e3;
const RANK_FLUSH_BATCH = 5000;
function startGiftRankFlusher() {
  let running = false;
  let stopped = false;
  const timer = setInterval(async () => {
    if (running || stopped) return;
    running = true;
    try {
      for (let i = 0; i < 10; i += 1) {
        const { rows } = await db.giftQuery(
          `SELECT public.flush_gift_rank_queue($1) AS n`,
          [RANK_FLUSH_BATCH],
        );
        if (Number(rows[0]?.n) < RANK_FLUSH_BATCH) break;
      }
    } catch (err) {
      if (err.code === "42883") {
        stopped = true;
        clearInterval(timer);
        console.warn("[gift_rank] flush function not installed — flusher off");
      } else {
        console.warn("[gift_rank] flush failed:", err.message);
      }
    } finally {
      running = false;
    }
  }, RANK_FLUSH_MS);
  timer.unref?.();
  return timer;
}

module.exports = {
  startGiftRankFlusher: startGiftRankFlusher,
  loadGift: loadGift,
  isLuckyCategory: isLuckyCategory,
  isLuckyProCategory: isLuckyProCategory,
  settleGifts: settleGifts,
  buildNotifyFromSettle: buildNotifyFromSettle,
  persistGiftMessages: persistGiftMessages,
  newOpId: () => uuidv4(),
};
