const STATS_TTL_SEC = 8 * 24 * 60 * 60;
const FAIL_TTL_SEC = 48 * 60 * 60;
const USER_FAILS = 50;
const ALL_FAILS = 500;
const WARN_RATE = 0.001;
const WARN_MIN_BETS = 100;

function hourKey(ms) {
  const d = new Date(ms);
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}${p(d.getUTCMonth() + 1)}${p(d.getUTCDate())}${p(d.getUTCHours())}`;
}

function record(redis, o) {
  if (!redis || !o || !o.endpoint) return;
  const code = Number.isFinite(Number(o.code)) ? Number(o.code) : 1000;
  const ms = Math.max(0, Math.round(Number(o.ms) || 0));
  const statsKey = `gh:stats:${hourKey(Date.now())}`;
  const m = redis.multi();
  m.hincrby(statsKey, `${o.endpoint}:${code}`, 1);
  m.hincrby(statsKey, `${o.endpoint}:ms`, ms);
  if (o.isBet) {
    m.hincrby(statsKey, "bet:n", 1);
    if (o.late) m.hincrby(statsKey, "bet:late", 1);
    else if (code !== 0) m.hincrby(statsKey, "bet:fail", 1);
  }
  m.expire(statsKey, STATS_TTL_SEC);
  if (code !== 0) {
    const entry = JSON.stringify({
      ts: new Date().toISOString(),
      endpoint: o.endpoint,
      code: code,
      message: String(o.message || "").slice(0, 120),
      user: o.user != null ? String(o.user) : null,
      game_id: o.gameId != null ? Number(o.gameId) : null,
      order_id: o.orderId != null ? String(o.orderId).slice(0, 80) : null,
      ms: ms,
    });
    if (o.user != null && String(o.user)) {
      const uk = `gh:fail:u:${o.user}`;
      m.lpush(uk, entry);
      m.ltrim(uk, 0, USER_FAILS - 1);
      m.expire(uk, FAIL_TTL_SEC);
    }
    m.lpush("gh:fail:all", entry);
    m.ltrim("gh:fail:all", 0, ALL_FAILS - 1);
    m.expire("gh:fail:all", FAIL_TTL_SEC);
  }
  m.exec().catch(() => {});
}

async function report(redis, { hours = 24, user = null } = {}) {
  const h = Math.min(Math.max(Math.trunc(Number(hours) || 24), 1), 192);
  const now = Date.now();
  const keys = [];
  for (let i = 0; i < h; i += 1) keys.push(hourKey(now - i * 3600e3));
  const p = redis.pipeline();
  for (const k of keys) p.hgetall(`gh:stats:${k}`);
  const res = await p.exec();
  const byHour = keys.map((k, i) => {
    const raw = (res[i] && res[i][1]) || {};
    const out = {};
    for (const [f, v] of Object.entries(raw)) out[f] = Number(v) || 0;
    const bets = out["bet:n"] || 0;
    const bad = (out["bet:late"] || 0) + (out["bet:fail"] || 0);
    return {
      hour_utc: k,
      bets: bets,
      bets_late: out["bet:late"] || 0,
      bets_failed: out["bet:fail"] || 0,
      bad_rate: bets ? bad / bets : 0,
      counts: out,
    };
  });
  const recent = byHour.slice(0, 2);
  const warn = recent.some(
    (r) => r.bets >= WARN_MIN_BETS && r.bad_rate > WARN_RATE,
  );
  const failKey = user ? `gh:fail:u:${user}` : "gh:fail:all";
  const fails = (await redis.lrange(failKey, 0, 49)).map((s) => {
    try {
      return JSON.parse(s);
    } catch (_) {
      return null;
    }
  });
  return {
    status: warn ? "warn" : "ok",
    warn_rule: `late + failed bets > ${WARN_RATE * 100}% of an hour's bets (min ${WARN_MIN_BETS})`,
    hours: byHour,
    recent_failures: fails.filter(Boolean),
    user: user || null,
  };
}

module.exports = { record: record, report: report, hourKey: hourKey };
