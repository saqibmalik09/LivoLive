const db = require("./db");

const CATALOG_URL =
  process.env.WAVE_CATALOG_URL || "https://my.wavegames.online/admin/game/list";
const APP_KEY = String(process.env.WAVE_APP_KEY || "6YR2cWUh2h").trim();
const TENANT_BASE = String(
  process.env.WAVE_TENANT_BASE_URL || "https://gateway.skliveparty.online",
).replace(/\/$/, "");
const PLAY_ORIGIN = String(
  process.env.WAVE_FRONTEND_URL || "https://wavegames.online",
).replace(/\/$/, "");
const CATALOG_TTL_MS = 15_000;
const CATALOG_TIMEOUT_MS = 6_000;
const FLOW_BUDGET_MS = 8_000;

let cached = null;
let cachedUntil = 0;
let inflight = null;

function writeWave(res, success, message, data) {
  res.status(200).json({
    success,
    message,
    data: data == null ? {} : data,
  });
}

function bearer(req) {
  const raw = String(req.headers.authorization || "");
  const match = raw.match(/^Bearer\s+(\S+)/i);
  return match ? match[1] : "";
}

function unescapePlaceholders(value) {
  return String(value || "")
    .replace(/%7Btoken%7D/gi, "{token}")
    .replace(/%7Bembed%7D/gi, "{embed}");
}

function rewritePlayFrontend(play) {
  let url;
  try {
    url = new URL(String(play || "").trim());
  } catch (_) {
    return play;
  }
  const host = url.hostname.toLowerCase();
  if (
    host !== "my.wavegames.online" &&
    host !== "api.wavegames.online" &&
    !host.endsWith(".my.wavegames.online")
  ) {
    return play;
  }
  const front = new URL(PLAY_ORIGIN);
  url.protocol = front.protocol;
  url.host = front.host;
  return url.toString();
}

function withTenantBase(play) {
  const rewritten = rewritePlayFrontend(play);
  if (!rewritten || rewritten.includes("tenantBase=")) return rewritten;
  const sep = rewritten.includes("?") ? "&" : "?";
  return `${rewritten}${sep}tenantBase=${encodeURIComponent(TENANT_BASE)}`;
}

function playUrlFromWave(game, half) {
  const urls = game.urls || {};
  let play = "";
  if (half) play = String(urls.halfUrl || "").trim();
  if (!play) play = String(urls.fullUrl || "").trim();
  if (!play) play = String(urls.urlTemplate || game.urlTemplate || "").trim();
  if (!play) play = String(urls.url || game.url || "").trim();
  play = unescapePlaceholders(play);
  if (play.includes("{embed}")) {
    play = play.replaceAll("{embed}", half ? "half" : "full");
  }
  return play;
}

function mapTray(src, defaultHeight, half) {
  const out = [];
  const seen = new Set();
  for (const game of src || []) {
    const status = String(game.status || "");
    if (game.playable === false && status && status.toLowerCase() !== "active") {
      continue;
    }
    const id = Number(game.gameId || game.id || 0);
    if (!id || seen.has(id)) continue;
    let play = playUrlFromWave(game, half);
    if (!play) continue;
    if (!play.includes("{token}")) {
      play += `${play.includes("?") ? "&" : "?"}token={token}`;
    }
    let height = Number(game.suggestedSheetHeightPercent);
    if (!Number.isFinite(height) || height <= 0) height = defaultHeight;
    if (height > 100) height = 100;
    seen.add(id);
    out.push({
      id,
      game_id: id,
      name: String(game.name || "Game"),
      route_slug: String(game.routeSlug || ""),
      listing_image: String(game.images?.listing || ""),
      play_url: withTenantBase(play),
      sheet_height_percent: height,
    });
  }
  return out;
}

async function fetchCatalog() {
  const url = new URL(CATALOG_URL);
  url.searchParams.set("appKey", APP_KEY);
  const res = await fetch(url, {
    headers: { Accept: "application/json" },
    signal: AbortSignal.timeout(CATALOG_TIMEOUT_MS),
  });
  const raw = await res.json();
  const data = raw && raw.data;
  if (!data || (raw.success === false && !data.fullModeGames && !data.games)) {
    throw new Error(raw?.message || "catalog unavailable");
  }
  const full = mapTray(data.fullModeGames || data.games || [], 100, false);
  const half = mapTray(data.halfModeGames || [], 60, true);
  return {
    frontend_base_url: PLAY_ORIGIN,
    tenant_base_url: TENANT_BASE,
    games: full,
    half_mode_games: half,
    fetched_at: new Date().toISOString(),
  };
}

async function catalog() {
  if (cached && Date.now() < cachedUntil) return cached;
  if (!inflight) {
    inflight = fetchCatalog().finally(() => {
      inflight = null;
    });
  }
  try {
    const next = await inflight;
    cached = next;
    cachedUntil = Date.now() + CATALOG_TTL_MS;
    return next;
  } catch (err) {
    if (cached) return cached;
    throw err;
  }
}

async function loadPlayer(userId, q) {
  const { rows } = await q(
    `SELECT id::text AS id, username, avatar_url, COALESCE(coins, 0)::bigint AS coins
     FROM public.users
     WHERE id = $1::uuid
     LIMIT 1`,
    [userId],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    id: row.id,
    name: String(row.username || "Player"),
    balance: Number(row.coins || 0),
    profilePicture: String(row.avatar_url || ""),
  };
}

async function inFlowTx(fn) {
  return db.withGameClient(FLOW_BUDGET_MS, async (client) => {
    await client.query("BEGIN");
    try {
      const out = await fn((text, params) => client.query(text, params));
      await client.query("COMMIT");
      return out;
    } catch (err) {
      try {
        await client.query("ROLLBACK");
      } catch (_) {}
      throw err;
    }
  });
}

function mount(app, { verifyToken }) {
  app.get("/v1/games/catalog", async (req, res) => {
    try {
      const payload = await verifyToken(bearer(req));
      const userId = payload?.sub ? String(payload.sub) : "";
      if (!userId || userId.startsWith("anon:")) {
        return res.status(401).json({ ok: false, error: "unauthorized" });
      }
      const cat = await catalog();
      return res.json({ ok: true, ...cat });
    } catch (err) {
      console.error("[wave] catalog", err.message);
      return res.status(502).json({
        ok: false,
        error: "games_catalog_unavailable",
      });
    }
  });

  app.get("/wave/game/userInfo", async (req, res) => {
    try {
      const payload = await verifyToken(bearer(req));
      const userId = payload?.sub ? String(payload.sub) : "";
      if (!userId || userId.startsWith("anon:")) {
        return writeWave(res, false, "Missing or invalid token", null);
      }
      const player = await inFlowTx((q) => loadPlayer(userId, q));
      if (!player) {
        return writeWave(res, false, "Invalid token or user not found", null);
      }
      return writeWave(res, true, "User info fetched successfully", player);
    } catch (err) {
      console.error("[wave] userInfo", err.message);
      return writeWave(res, false, "Invalid token or user not found", null);
    }
  });

  app.post("/wave/game/submitFlow", async (req, res) => {
    try {
      const payload = await verifyToken(bearer(req));
      const userId = payload?.sub ? String(payload.sub) : "";
      if (!userId || userId.startsWith("anon:")) {
        return writeWave(res, false, "Missing or invalid token", null);
      }
      const body = req.body || {};
      const betAmount = Math.trunc(Number(body.betAmount));
      const flowType = Math.trunc(Number(body.type));
      const transactionId = String(body.transactionId || "").trim().slice(0, 200);
      const gameName = String(body.gameName || "").trim().slice(0, 80);
      const gameId = Number(body.gameId);
      if (!transactionId) {
        return writeWave(res, false, "transactionId is required", null);
      }
      if (flowType !== 1 && flowType !== 2) {
        return writeWave(res, false, "type must be 1 (debit) or 2 (credit).", null);
      }
      if (!Number.isFinite(betAmount) || betAmount <= 0) {
        return writeWave(res, false, "betAmount must be a positive number.", null);
      }

      const applied = await inFlowTx(async (q) => {
        const { rows } = await q(
          `SELECT public.wave_apply_flow($1::uuid, $2, $3::smallint, $4::bigint, $5, $6::bigint) AS result`,
          [
            userId,
            transactionId,
            flowType,
            betAmount,
            gameName || null,
            Number.isFinite(gameId) && gameId > 0 ? Math.trunc(gameId) : null,
          ],
        );
        return rows[0]?.result || {};
      });

      if (!applied.success) {
        if (applied.code === "insufficient_funds") {
          const player = await inFlowTx((q) => loadPlayer(userId, q));
          return writeWave(res, false, "Not enough balance.", player);
        }
        return writeWave(
          res,
          false,
          String(applied.error || "Could not update balance."),
          null,
        );
      }
      const player = await inFlowTx((q) => loadPlayer(userId, q));
      if (!player) {
        return writeWave(res, false, "Could not update balance.", null);
      }
      return writeWave(res, true, "Balance updated.", player);
    } catch (err) {
      console.error("[wave] submitFlow", err.message);
      return writeWave(res, false, "Could not update balance.", null);
    }
  });

  console.log(
    `[wave] catalog + userInfo/submitFlow enabled tenant=${TENANT_BASE}`,
  );
}

module.exports = { mount };
