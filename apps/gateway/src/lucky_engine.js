const db = require("./db");
const CONFIG_REFRESH_MS = 3e4;
const PENDING_CREDIT_KEY = "lucky:pending_credits";
const ROLLED_CLAIM_TTL_SEC = Number(
  process.env.LUCKY_ROLLED_TTL_SEC || 86400 * 2,
);
const CREDITED_CLAIM_TTL_SEC = Number(
  process.env.LUCKY_CREDITED_TTL_SEC || 86400 * 2,
);
const PENDING_CREDIT_RETRY_MS = 15e3;
const RTP_MIN = Number(process.env.LUCKY_RTP_MIN || 0.85);
const RTP_MAX = Number(process.env.LUCKY_RTP_MAX || 0.9);
const WIN_GAP_MIN = Number(process.env.LUCKY_WIN_GAP_MIN || 8);
const WIN_GAP_MAX = Number(process.env.LUCKY_WIN_GAP_MAX || 18);
const MIN_WIN_MULT = Number(process.env.LUCKY_MIN_WIN_MULT || 1);
const JACKPOT_SHARE = Number(process.env.LUCKY_JACKPOT_SHARE || 0.55);
const JACKPOT_MIN_MULT = Number(process.env.LUCKY_JACKPOT_MIN_MULT || 100);
const POT_SOFT_CAP_MULT = Number(process.env.LUCKY_POT_SOFT_CAP || 1.35);
const POT_DUE_MIN = Number(process.env.LUCKY_POT_DUE_MIN || 25);
const POT_DUE_MAX = Number(process.env.LUCKY_POT_DUE_MAX || 55);
const LEDGER_TTL_SEC = 60 * 60 * 24 * 45;
let configCache = { lucky: null, lucky_pro: null, loadedAt: 0 };
function randomInt(min, max) {
  const a = Math.trunc(Number(min) || 0);
  const b = Math.trunc(Number(max) || 0);
  if (b <= a) return a;
  return a + Math.floor(Math.random() * (b - a + 1));
}
function randomRatio(min, max) {
  const a = Number(min);
  const b = Number(max);
  if (!(b > a)) return a;
  return a + Math.random() * (b - a);
}
const LADDER = [
  1, 2, 5, 10, 15, 20, 25, 30, 40, 50, 66, 80, 100, 120, 150, 166, 200, 250,
  300, 400, 500,
];
const SMALL_MAX_MULT = 15;
const MID_MAX_MULT = 50;
const TIER_SMALL_WEIGHT = Number(process.env.LUCKY_TIER_SMALL_WEIGHT || 0.5);
const TIER_MID_WEIGHT = Number(process.env.LUCKY_TIER_MID_WEIGHT || 0.45);
function affordableSteps(
  steps,
  {
    base: base,
    budget: budget,
    perWinCap: perWinCap,
    multMin: multMin,
    multMax: multMax,
  },
) {
  const lo = Math.max(MIN_WIN_MULT, Number(multMin) || MIN_WIN_MULT);
  const hi = Number(multMax) || 200;
  const ceiling = perWinCap != null ? Math.min(budget, perWinCap) : budget;
  return steps.filter((m) => m >= lo && m <= hi && m * base <= ceiling);
}
function pickFromPool(pool) {
  if (!pool.length) return null;
  if (Math.random() < 0.55) {
    return pool[randomInt(0, Math.floor((pool.length - 1) / 2))];
  }
  return pool[randomInt(0, pool.length - 1)];
}
function pickRegularMultiplier(opts) {
  const ok = affordableSteps(LADDER, opts).filter(
    (m) => m < JACKPOT_MIN_MULT && m <= MID_MAX_MULT,
  );
  if (!ok.length) return null;
  const small = ok.filter((m) => m <= SMALL_MAX_MULT);
  const mid = ok.filter((m) => m > SMALL_MAX_MULT);
  const roll = Math.random();
  let pool = null;
  if (roll < TIER_SMALL_WEIGHT && small.length) pool = small;
  else if (mid.length) pool = mid;
  else if (small.length) pool = small;
  else pool = ok;
  return pickFromPool(pool);
}
function pickJackpotMultiplier(opts) {
  const jacks = affordableSteps(LADDER, opts).filter(
    (m) => m >= JACKPOT_MIN_MULT,
  );
  if (!jacks.length) return null;
  const best = jacks[jacks.length - 1];
  const cashOutChance =
    best >= 500 ? 1 : best >= 300 ? 0.98 : best >= 200 ? 0.92 : 0.85;
  if (!opts.overdue && Math.random() > cashOutChance) return null;
  const roll = Math.random();
  if (best >= 400 && roll < 0.6) {
    const mega = jacks.filter((m) => m >= 300);
    return mega[mega.length - 1];
  }
  if (best >= 200 && roll < 0.8) {
    const big = jacks.filter((m) => m >= 150 && m <= 300);
    return pickFromPool(big.length ? big : jacks);
  }
  const common = jacks.filter((m) => m <= 200);
  return pickFromPool(common.length ? common : jacks);
}
async function refreshConfig(force = false) {
  if (
    !force &&
    configCache.lucky &&
    Date.now() - configCache.loadedAt < CONFIG_REFRESH_MS
  ) {
    return configCache;
  }
  try {
    const [lucky, pro] = await Promise.all([
      db.query(`SELECT * FROM lucky_gift_config WHERE id = 1`),
      db.query(`SELECT * FROM lucky_pro_gift_config WHERE id = 1`),
    ]);
    configCache = {
      lucky: lucky.rows[0] || null,
      lucky_pro: pro.rows[0] || null,
      loadedAt: Date.now(),
    };
  } catch (err) {
    console.warn("[lucky_engine] config refresh failed:", err.message);
  }
  return configCache;
}
function cfgFor(variant) {
  return variant === "lucky_pro" ? configCache.lucky_pro : configCache.lucky;
}
function redisKeys(variant, senderId, receiverId) {
  const v = variant === "lucky_pro" ? "pro" : "lg";
  return {
    senderCounter: `lucky:${v}:sender:${senderId}`,
    pairCounter: `lucky:${v}:pair:${senderId}:${receiverId}`,
    ledger: `lucky:${v}:ledger:${senderId}`,
    winLock: `lucky:${v}:win_lock:${senderId}`,
    lastBonus: `lucky:${v}:last_bonus:${senderId}`,
    lastBig: `lucky:${v}:last_big:${senderId}`,
    credited: `lucky:credited:${senderId}`,
  };
}
async function loadLedger(redis, ledgerKey) {
  const raw = (await redis.hgetall(ledgerKey)) || {};
  const sends = Number(raw.sends) || 0;
  let target = Number(raw.target);
  let nextAt = Number(raw.next_at);
  let potDueAt = Number(raw.pot_due);
  let dirty = false;
  if (!(target > 0) || !(nextAt > 0) || !(potDueAt > 0)) {
    target = target > 0 ? target : randomRatio(RTP_MIN, RTP_MAX);
    nextAt = nextAt > 0 ? nextAt : sends + randomInt(WIN_GAP_MIN, WIN_GAP_MAX);
    potDueAt =
      potDueAt > 0 ? potDueAt : sends + randomInt(POT_DUE_MIN, POT_DUE_MAX);
    dirty = true;
  }
  if (target < RTP_MIN) {
    target = randomRatio(RTP_MIN, RTP_MAX);
    dirty = true;
  } else if (target > RTP_MAX) {
    target = RTP_MAX;
    dirty = true;
  }
  if (dirty) {
    await redis.hset(ledgerKey, {
      target: String(target),
      next_at: String(nextAt),
      pot_due: String(potDueAt),
    });
  }
  return {
    spend: Number(raw.spend) || 0,
    paid: Number(raw.paid) || 0,
    sends: sends,
    pot: Number(raw.pot) || 0,
    target: target,
    nextAt: nextAt,
    potDueAt: potDueAt,
  };
}
async function roll(
  redis,
  {
    variant: variant,
    senderId: senderId,
    receiverId: receiverId,
    giftId: giftId,
    giftLogId: giftLogId,
    totalCost: totalCost,
    unitPrice: unitPrice = 0,
    batchRecipientCount: batchRecipientCount = 1,
  },
) {
  await refreshConfig();
  const cfg = cfgFor(variant);
  if (!cfg || cfg.is_enabled === false) {
    return { bonus_won: false, reason: "disabled" };
  }
  const recipients = Math.max(1, Math.trunc(Number(batchRecipientCount) || 1));
  const cost = Math.trunc(Number(totalCost) || 0);
  if (cost <= 0 || cost < Number(cfg.min_gift_value_for_bonus || 0)) {
    return { bonus_won: false, reason: "min_value" };
  }
  const base = Math.min(
    cost,
    Math.max(1, Math.trunc(Number(unitPrice) || 0) || cost),
  );
  const logId = String(giftLogId || "").trim();
  if (logId) {
    const claimed = await redis.set(
      `lucky:rolled:${logId}`,
      "1",
      "EX",
      ROLLED_CLAIM_TTL_SEC,
      "NX",
    );
    if (claimed !== "OK") {
      return { bonus_won: false, reason: "duplicate_roll", gift_log_id: logId };
    }
  }
  const keys = redisKeys(variant, senderId, receiverId);
  const led = await loadLedger(redis, keys.ledger);
  const sends = Number(await redis.hincrby(keys.ledger, "sends", 1)) || 1;
  const spend = Number(await redis.hincrby(keys.ledger, "spend", cost)) || cost;
  const totalLeft = Math.max(0, Math.floor(spend * led.target) - led.paid);
  const potAdd = Math.floor(cost * led.target * JACKPOT_SHARE);
  let pot =
    potAdd > 0
      ? Number(await redis.hincrby(keys.ledger, "pot", potAdd)) || 0
      : led.pot;
  const potSoftCap = Math.max(
    500 * base,
    Math.floor(spend * led.target * JACKPOT_SHARE * POT_SOFT_CAP_MULT),
  );
  if (pot > potSoftCap) {
    pot = potSoftCap;
    await redis.hset(keys.ledger, "pot", String(pot));
  }
  await redis.expire(keys.ledger, LEDGER_TTL_SEC);
  const ledgerInfo = {
    gift_count: sends,
    ledger_spend: spend,
    ledger_paid: led.paid,
    ledger_pot: pot,
    ledger_target: Number(led.target.toFixed(3)),
    next_win_at: led.nextAt,
    batch_recipients: recipients,
    batch_spend: cost,
    backup_wins_remaining: 0,
  };
  if (sends < led.nextAt) {
    return { bonus_won: false, reason: "streak", ...ledgerInfo };
  }
  const cooldownSec = Number(cfg.cooldown_seconds) || 0;
  const winLock = await redis.set(
    keys.winLock,
    "1",
    "EX",
    Math.max(cooldownSec, 3),
    "NX",
  );
  if (winLock !== "OK") {
    return { bonus_won: false, reason: "cooldown", ...ledgerInfo };
  }
  const perWinCap =
    cfg.max_bonus_coins_per_win != null
      ? Math.trunc(Number(cfg.max_bonus_coins_per_win))
      : null;
  const bounds = {
    base: base,
    perWinCap: perWinCap,
    multMin: cfg.bonus_multiplier_min,
    multMax: cfg.bonus_multiplier_max,
  };
  const capMult = perWinCap != null ? Math.floor(perWinCap / base) : Infinity;
  const potCeiling = perWinCap != null ? perWinCap : Infinity;
  const overdue = sends >= led.potDueAt;
  const minJackCoins = JACKPOT_MIN_MULT * base;
  let potBudget = 0;
  if (capMult >= JACKPOT_MIN_MULT) {
    potBudget = Math.min(pot, potCeiling);
    if (overdue || pot >= minJackCoins * 0.85) {
      potBudget = Math.min(pot + totalLeft, potCeiling);
    }
  }
  const reservedForPot =
    potBudget >= minJackCoins
      ? Math.min(minJackCoins, totalLeft)
      : Math.min(Math.floor(totalLeft * 0.5), Math.max(0, minJackCoins - pot));
  const regularBudget = Math.max(0, totalLeft - reservedForPot);
  let multiplier = pickJackpotMultiplier({
    ...bounds,
    budget: potBudget,
    overdue: overdue,
  });
  if (multiplier == null && overdue && potBudget >= minJackCoins) {
    const forced = affordableSteps(LADDER, {
      ...bounds,
      budget: potBudget,
    }).filter((m) => m >= JACKPOT_MIN_MULT);
    if (forced.length) {
      multiplier =
        forced[forced.length - 1] >= 300 && Math.random() < 0.5
          ? forced[forced.length - 1]
          : pickFromPool(
              forced.filter((m) => m <= 200).length
                ? forced.filter((m) => m <= 200)
                : forced,
            );
    }
  }
  const isJackpot = multiplier != null && multiplier >= JACKPOT_MIN_MULT;
  if (!isJackpot) {
    multiplier = pickRegularMultiplier({ ...bounds, budget: regularBudget });
  }
  if (multiplier == null) {
    await redis.del(keys.winLock);
    return {
      bonus_won: false,
      reason: "ledger_defer",
      ledger_allowance: regularBudget,
      ...ledgerInfo,
    };
  }
  const bonusCoins = multiplier * base;
  const paid =
    Number(await redis.hincrby(keys.ledger, "paid", bonusCoins)) || 0;
  let potAfter = pot;
  if (isJackpot) {
    const potDrain = Math.min(pot, bonusCoins);
    if (potDrain > 0) {
      potAfter = Math.max(0, pot - potDrain);
      await redis.hincrby(keys.ledger, "pot", -potDrain);
    }
    await redis.hset(
      keys.ledger,
      "pot_due",
      String(sends + randomInt(POT_DUE_MIN, POT_DUE_MAX)),
    );
  }
  await redis.hset(
    keys.ledger,
    "next_at",
    String(sends + randomInt(WIN_GAP_MIN, WIN_GAP_MAX)),
  );
  await redis.expire(keys.ledger, LEDGER_TTL_SEC);
  await redis.set(keys.lastBonus, String(Date.now()), "EX", 60 * 60 * 24);
  if (multiplier >= 100) {
    await redis.set(keys.lastBig, String(Date.now()), "EX", 60 * 60 * 24);
  }
  return {
    bonus_won: true,
    bonus_coins: bonusCoins,
    bonus_multiplier: multiplier,
    bonus_base: base,
    bonus_tier: "standard",
    variant: variant === "lucky_pro" ? "lucky_pro" : "lucky",
    gift_log_id: giftLogId,
    gift_id: giftId,
    receiver_id: receiverId,
    sender_id: senderId,
    gift_value: cost,
    gift_count: sends,
    threshold: led.nextAt,
    batch_recipients: recipients,
    batch_spend: cost,
    ledger_spend: spend,
    ledger_paid: paid,
    ledger_pot: potAfter,
    ledger_target: Number(led.target.toFixed(3)),
    backup_wins_remaining: 0,
    planned_multiplier: multiplier,
    is_jackpot: isJackpot,
    forced_mega: multiplier >= 200,
  };
}
function unitPriceOf(req) {
  const price = Math.trunc(Number(req?.unitPrice) || 0);
  if (price > 0) return price;
  const qty = Math.max(1, Math.trunc(Number(req?.quantity) || 1));
  const total = Math.trunc(Number(req?.totalCost) || 0);
  return Math.max(1, Math.floor(total / qty));
}
async function rollBatch(redis, rollReqs) {
  const list = Array.isArray(rollReqs) ? rollReqs.filter(Boolean) : [];
  if (!list.length) return { bonus_won: false, reason: "empty_batch" };
  if (list.length === 1) {
    return roll(redis, {
      variant: list[0].variant,
      senderId: list[0].senderId,
      receiverId: list[0].receiverId,
      giftId: list[0].giftId,
      giftLogId: list[0].giftLogId,
      totalCost: list[0].totalCost,
      unitPrice: unitPriceOf(list[0]),
      batchRecipientCount: 1,
    });
  }
  const primary = list[0];
  const batchSpend = list.reduce(
    (sum, r) => sum + Math.trunc(Number(r.totalCost) || 0),
    0,
  );
  const batchSize = list.length;
  const primaryLogId = String(primary.giftLogId || "").trim();
  for (let i = 1; i < list.length; i += 1) {
    const sid = String(list[i].giftLogId || "").trim();
    if (!sid || sid === primaryLogId) continue;
    await redis.set(
      `lucky:rolled:${sid}`,
      "1",
      "EX",
      ROLLED_CLAIM_TTL_SEC,
      "NX",
    );
  }
  return roll(redis, {
    variant: primary.variant,
    senderId: primary.senderId,
    receiverId: primary.receiverId,
    giftId: primary.giftId,
    giftLogId: primary.giftLogId,
    totalCost: batchSpend,
    unitPrice: unitPriceOf(primary),
    batchRecipientCount: batchSize,
  });
}
async function creditBonus(result) {
  if (!result?.bonus_won || !result.gift_log_id) return { ok: false };
  try {
    const { rows: rows } = await db.query(
      `SELECT public.credit_lucky_bonus($1,$2,$3,$4,$5,$6,$7,$8,$9) AS r`,
      [
        result.sender_id,
        result.receiver_id,
        result.gift_id,
        result.gift_log_id,
        result.variant === "lucky_pro" ? "lucky_pro" : "lucky",
        result.gift_value,
        result.bonus_coins,
        result.bonus_tier || "standard",
        result.bonus_multiplier || null,
      ],
    );
    const r = rows[0]?.r;
    const parsed = typeof r === "string" ? JSON.parse(r) : r || {};
    return { ok: true, ...parsed };
  } catch (err) {
    console.warn("[lucky_engine] credit failed:", err.message);
    return { ok: false, error: err.message };
  }
}
async function enqueuePendingCredit(redis, result) {
  try {
    await redis.lpush(PENDING_CREDIT_KEY, JSON.stringify(result));
  } catch (err) {
    console.warn("[lucky_engine] enqueue pending failed:", err.message);
  }
}
async function creditOrEnqueue(redis, result) {
  if (!result?.bonus_won) return;
  const claimed = await redis.set(
    `lucky:credited:${result.gift_log_id}`,
    "1",
    "EX",
    CREDITED_CLAIM_TTL_SEC,
    "NX",
  );
  if (claimed !== "OK") return;
  const res = await creditBonus(result);
  if (!res.ok) {
    await redis.del(`lucky:credited:${result.gift_log_id}`);
    await enqueuePendingCredit(redis, result);
  }
}
function startPendingCreditWorker(redis) {
  setInterval(async () => {
    try {
      const raw = await redis.rpop(PENDING_CREDIT_KEY);
      if (!raw) return;
      const result = JSON.parse(raw);
      const res = await creditBonus(result);
      if (!res.ok) {
        await enqueuePendingCredit(redis, result);
      } else {
        await redis.set(
          `lucky:credited:${result.gift_log_id}`,
          "1",
          "EX",
          CREDITED_CLAIM_TTL_SEC,
        );
      }
    } catch (err) {
      console.warn("[lucky_engine] pending worker:", err.message);
    }
  }, PENDING_CREDIT_RETRY_MS).unref?.();
}
function extractGatewayRolls(payload, actorUserId) {
  if (String(payload.lucky_engine || "") !== "gateway") return [];
  const rolls = [];
  const seenLogIds = new Set();
  const pushFromMessage = (message) => {
    if (!message || typeof message !== "object") return;
    const meta =
      message.metadata && typeof message.metadata === "object"
        ? message.metadata
        : {};
    if (String(meta.lucky_engine || payload.lucky_engine || "") !== "gateway") {
      return;
    }
    const isPro = meta.is_lucky_pro_gift === true;
    const isLucky = meta.is_lucky_gift === true || isPro;
    if (!isLucky) return;
    const giftLogId = String(meta.gift_log_id || "").trim();
    if (!giftLogId) return;
    if (seenLogIds.has(giftLogId)) return;
    seenLogIds.add(giftLogId);
    const price = Number(meta.price_coins) || 0;
    const qty = Number(meta.quantity) || 1;
    const totalCost =
      Number(meta.total_cost) || Number(meta.gift_value) || price * qty;
    rolls.push({
      variant: isPro ? "lucky_pro" : "lucky",
      senderId: String(message.user_id || actorUserId || ""),
      receiverId: String(meta.target_id || ""),
      giftId: String(meta.gift_id || ""),
      giftLogId: giftLogId,
      totalCost: totalCost,
      unitPrice: price,
      quantity: qty,
      message: message,
      meta: meta,
    });
  };
  if (Array.isArray(payload.messages) && payload.messages.length > 0) {
    for (const m of payload.messages) pushFromMessage(m);
  } else if (payload.message) {
    pushFromMessage(payload.message);
  }
  if (Array.isArray(payload.lucky_rolls)) {
    for (const r of payload.lucky_rolls) {
      if (!r || typeof r !== "object") continue;
      const giftLogId = String(r.gift_log_id || "").trim();
      if (!giftLogId || seenLogIds.has(giftLogId)) continue;
      seenLogIds.add(giftLogId);
      rolls.push({
        variant: r.variant === "lucky_pro" ? "lucky_pro" : "lucky",
        senderId: String(r.sender_id || actorUserId || ""),
        receiverId: String(r.receiver_id || ""),
        giftId: String(r.gift_id || ""),
        giftLogId: giftLogId,
        totalCost: Number(r.total_cost) || 0,
        unitPrice: Number(r.price_coins) || 0,
        quantity: Number(r.quantity) || 1,
        message: null,
        meta: r,
      });
    }
  }
  return rolls;
}
function applyWinToMessageMeta(meta, win) {
  if (!meta || !win?.bonus_won) return meta;
  const next = { ...meta };
  next.lucky_engine = "gateway";
  next.gift_log_id = win.gift_log_id;
  next.bonus_multiplier = win.bonus_multiplier;
  next.multiplier_tier = `x${win.bonus_multiplier}`;
  if (win.variant === "lucky_pro") {
    next.is_lucky_pro_gift = true;
    next.lucky_pro_bonus_won = true;
    next.lucky_pro_bonus_coins = win.bonus_coins;
    next.lucky_bonus_won = false;
    next.lucky_bonus_coins = 0;
  } else {
    next.is_lucky_gift = true;
    next.lucky_bonus_won = true;
    next.lucky_bonus_coins = win.bonus_coins;
    next.lucky_pro_bonus_won = false;
    next.lucky_pro_bonus_coins = 0;
  }
  return next;
}
module.exports = {
  refreshConfig: refreshConfig,
  roll: roll,
  rollBatch: rollBatch,
  creditOrEnqueue: creditOrEnqueue,
  startPendingCreditWorker: startPendingCreditWorker,
  extractGatewayRolls: extractGatewayRolls,
  applyWinToMessageMeta: applyWinToMessageMeta,
  pickRegularMultiplier: pickRegularMultiplier,
  pickJackpotMultiplier: pickJackpotMultiplier,
};
