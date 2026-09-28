const crypto = require("crypto");
const db = require("./db");
let emitGlobalWinRef = null;
const SIGN_TTL_SEC = 15;
const NONCE_TTL_SEC = 15;
const DEFAULT_CODE_TTL_MS = 5 * 60 * 1e3;
const DEFAULT_SS_TTL_MS = 24 * 60 * 60 * 1e3;
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function envInt(name, fallback) {
  const n = Number(process.env[name]);
  return Number.isFinite(n) && n > 0 ? Math.trunc(n) : fallback;
}
function config() {
  return {
    appId: String(process.env.BAISHUN_APP_ID || "").trim(),
    appKey: String(process.env.BAISHUN_APP_KEY || "").trim(),
    appChannel: String(process.env.BAISHUN_APP_CHANNEL || "sklive").trim(),
    appName: String(process.env.BAISHUN_APP_NAME || "sklive_app").trim(),
    apiBase: String(
      process.env.BAISHUN_API_BASE || "https://game-cn-test.jieyou.shop",
    ).replace(/\/$/, ""),
    codeTtlMs: envInt("BAISHUN_CODE_TTL_MS", DEFAULT_CODE_TTL_MS),
    ssTtlMs: envInt("BAISHUN_SS_TTL_MS", DEFAULT_SS_TTL_MS),
    syncAdminToken: String(process.env.BAISHUN_SYNC_ADMIN_TOKEN || "").trim(),
  };
}
function uniqueId() {
  return `${Date.now()}${Math.floor(Math.random() * 1e6)}`;
}
function makeSignature(nonce, appKey, timestamp) {
  const raw = `${nonce}${appKey}${timestamp}`;
  return crypto
    .createHash("md5")
    .update(raw, "utf8")
    .digest("hex")
    .toLowerCase();
}
function outboundSign(appKey) {
  const signature_nonce = crypto.randomBytes(8).toString("hex");
  const timestamp = Math.floor(Date.now() / 1e3);
  const signature = makeSignature(signature_nonce, appKey, timestamp);
  return {
    signature_nonce: signature_nonce,
    timestamp: timestamp,
    signature: signature,
  };
}
function baishunOk(data, extra = {}) {
  return {
    code: 0,
    message: "succeed",
    unique_id: uniqueId(),
    data: data,
    ...extra,
  };
}
function baishunErr(code, message) {
  return { code: code, message: message, unique_id: uniqueId() };
}
async function checkNonce(redis, nonce) {
  if (!nonce) return false;
  const key = `baishun:nonce:${nonce}`;
  const ok = await redis.set(key, "1", "EX", NONCE_TTL_SEC, "NX");
  return ok === "OK";
}
async function verifyBaishunRequest(req, redis) {
  const cfg = config();
  if (!cfg.appKey) {
    const err = new Error("BAISHUN not configured");
    err.status = 503;
    throw err;
  }
  const body = req.body || {};
  const signature_nonce = String(body.signature_nonce || "").trim();
  const signature = String(body.signature || "")
    .trim()
    .toLowerCase();
  const timestamp = Number(body.timestamp);
  if (!signature_nonce || !signature || !Number.isFinite(timestamp)) {
    return { ok: false, code: 1002, message: "invalid signature params" };
  }
  const skew = Math.abs(Math.floor(Date.now() / 1e3) - timestamp);
  if (skew > SIGN_TTL_SEC) {
    return { ok: false, code: 1002, message: "timestamp expired" };
  }
  const expected = makeSignature(signature_nonce, cfg.appKey, timestamp);
  if (expected !== signature) {
    return { ok: false, code: 1002, message: "signature mismatch" };
  }
  if (redis) {
    const fresh = await checkNonce(redis, signature_nonce);
    if (!fresh) {
      return { ok: false, code: 1002, message: "duplicate nonce" };
    }
  }
  if (cfg.appId && body.app_id != null && String(body.app_id) !== cfg.appId) {
    return { ok: false, code: 1003, message: "invalid app_id" };
  }
  return { ok: true, cfg: cfg };
}
async function resolveUserByExternalId(userIdExternal) {
  const ext = String(userIdExternal || "").trim();
  if (!ext) return null;
  const { rows: rows } = await db.query(
    `SELECT id, username, avatar_url, COALESCE(coins, 0)::bigint AS coins, short_id\n     FROM public.users\n     WHERE short_id::text = $1 OR id::text = $1\n     LIMIT 1`,
    [ext],
  );
  return rows[0] || null;
}
async function loadValidSession(ssToken) {
  const token = String(ssToken || "").trim();
  if (!token) return null;
  const { rows: rows } = await db.query(
    `SELECT s.ss_token, s.user_id, s.expire_date, s.expires_at,\n            u.username, u.avatar_url, u.short_id,\n            COALESCE(u.coins, 0)::bigint AS coins\n     FROM public.baishun_sessions s\n     JOIN public.users u ON u.id = s.user_id\n     WHERE s.ss_token = $1\n       AND s.expires_at > now()\n     LIMIT 1`,
    [token],
  );
  return rows[0] || null;
}
function userInfoPayload(userRow) {
  return {
    user_id: String(userRow.short_id ?? userRow.user_id ?? ""),
    user_name: String(userRow.username || "User"),
    user_avatar: String(userRow.avatar_url || ""),
    balance: Number(userRow.coins || 0),
  };
}
async function mintSsToken(userId) {
  const cfg = config();
  const ssToken = crypto.randomBytes(32).toString("hex");
  const expireDate = Date.now() + cfg.ssTtlMs;
  const expiresAt = new Date(expireDate).toISOString();
  await db.query(
    `INSERT INTO public.baishun_sessions (ss_token, user_id, expire_date, expires_at)\n     VALUES ($1, $2, $3, $4::timestamptz)`,
    [ssToken, userId, expireDate, expiresAt],
  );
  return { ss_token: ssToken, expire_date: expireDate };
}
async function handleGetSstoken(body) {
  const code = String(body.code || "").trim();
  const userExternal = String(body.user_id || "").trim();
  if (!code || !userExternal) {
    return baishunErr(1003, "code and user_id required");
  }
  const user = await resolveUserByExternalId(userExternal);
  if (!user) return baishunErr(1004, "user not found");
  const { rows: rows } = await db.query(
    `UPDATE public.baishun_codes\n     SET used_at = now()\n     WHERE code = $1\n       AND user_id = $2\n       AND used_at IS NULL\n       AND expires_at > now()\n     RETURNING code`,
    [code, user.id],
  );
  if (!rows[0]) return baishunErr(1001, "invalid or used code");
  const token = await mintSsToken(user.id);
  return baishunOk(token, { user_info: userInfoPayload(user) });
}
async function handleGetUserInfo(body) {
  const session = await loadValidSession(body.ss_token);
  if (!session) return baishunErr(1005, "invalid ss_token");
  if (
    body.user_id != null &&
    String(body.user_id) !== String(session.short_id) &&
    String(body.user_id) !== String(session.user_id)
  ) {
    return baishunErr(1004, "user mismatch");
  }
  return baishunOk(userInfoPayload(session));
}
async function handleUpdateSstoken(body) {
  const session = await loadValidSession(body.ss_token);
  if (!session) return baishunErr(1005, "invalid ss_token");
  if (
    body.user_id != null &&
    String(body.user_id) !== String(session.short_id) &&
    String(body.user_id) !== String(session.user_id)
  ) {
    return baishunErr(1004, "user mismatch");
  }
  await db.query(`DELETE FROM public.baishun_sessions WHERE ss_token = $1`, [
    session.ss_token,
  ]);
  const token = await mintSsToken(session.user_id);
  return baishunOk(token);
}
function pattiMinPayout() {
  const raw = String(
    process.env.BAISHUN_PATTI_MIN_PAYOUT ||
      process.env.TULASI_PATTI_MIN_PAYOUT ||
      process.env.TULASI_PATTI_MIN_NET ||
      "",
  ).trim();
  const n = Number(raw);
  return Number.isFinite(n) && n >= 0 ? Math.trunc(n) : 1e3;
}
function winTier(multiplier) {
  if (multiplier >= 450) return "x500";
  if (multiplier >= 225) return "x250";
  return `x${multiplier}`;
}
function parseUuid(value) {
  const s = String(value || "").trim();
  return UUID_RE.test(s) ? s : null;
}
async function roundBetSummary(userId, gameId, gameRoundId) {
  const params = [userId];
  let sql = `\n    SELECT ABS(currency_diff)::bigint AS amount\n    FROM public.baishun_orders\n    WHERE user_id = $1::uuid\n      AND diff_msg = 'bet'\n      AND currency_diff < 0\n      AND created_at > now() - interval '10 minutes'\n  `;
  if (gameId != null && Number.isFinite(gameId)) {
    params.push(Number(gameId));
    sql += ` AND game_id = $${params.length}::int`;
  }
  if (gameRoundId) {
    params.push(String(gameRoundId));
    sql += ` AND game_round_id = $${params.length}`;
  }
  sql += " ORDER BY created_at DESC LIMIT 300";
  const { rows: rows } = await db.query(sql, params);
  const unitCounts = new Map();
  for (const row of rows) {
    const amount = Number(row.amount) || 0;
    if (amount <= 0) continue;
    unitCounts.set(amount, (unitCounts.get(amount) || 0) + 1);
  }
  let betUnit = 0;
  let bestCount = 0;
  for (const [amount, count] of unitCounts) {
    if (
      count > bestCount ||
      (count === bestCount && (betUnit === 0 || amount < betUnit))
    ) {
      betUnit = amount;
      bestCount = count;
    }
  }
  return betUnit;
}
async function loadBaishunGame(gameId) {
  if (gameId == null || !Number.isFinite(Number(gameId))) return null;
  const { rows: rows } = await db.query(
    `SELECT slug, name\n     FROM public.game_configs\n     WHERE config_data->>'provider' = 'baishun'\n       AND (config_data->>'baishun_game_id')::text = $1\n     LIMIT 1`,
    [String(gameId)],
  );
  return rows[0] || null;
}
async function announceBaishunWin({
  userId: userId,
  orderId: orderId,
  payout: payout,
  gameId: gameId,
  gameRoundId: gameRoundId,
  roomId: roomId,
  emitGlobalWin: emitGlobalWin,
}) {
  const minPayout = pattiMinPayout();
  const rewardCoins = Math.trunc(Number(payout) || 0);
  if (rewardCoins < minPayout || rewardCoins <= 0) {
    console.log("[baishun] patti SKIP", {
      payout: rewardCoins,
      min: minPayout,
    });
    return;
  }
  const sourceMessageId = parseUuid(orderId);
  if (!sourceMessageId) {
    console.warn("[baishun] patti SKIP invalid order_id", orderId);
    return;
  }
  const { rows: users } = await db.query(
    `SELECT username, avatar_url FROM public.users WHERE id = $1::uuid LIMIT 1`,
    [userId],
  );
  const profile = users[0] || {};
  const game = await loadBaishunGame(gameId);
  const betUnit = await roundBetSummary(userId, gameId, gameRoundId);
  const multiplier =
    betUnit > 0
      ? Math.min(Math.max(Math.round(rewardCoins / betUnit), 1), 999999)
      : 1;
  const sourceRoomId = parseUuid(roomId);
  const { rows: rows } = await db.query(
    `INSERT INTO public.global_win_announcements (\n       source_message_id,\n       source_room_id,\n       user_id,\n       username,\n       avatar_url,\n       source_label,\n       game_slug,\n       reward_coins,\n       bonus_multiplier,\n       multiplier_tier,\n       variant,\n       server_broadcast\n     ) VALUES (\n       $1::uuid,\n       $2::uuid,\n       $3::uuid,\n       $4,\n       $5,\n       $6,\n       $7,\n       $8::bigint,\n       $9::int,\n       $10,\n       'game',\n       true\n     )\n     ON CONFLICT (source_message_id) DO NOTHING\n     RETURNING id`,
    [
      sourceMessageId,
      sourceRoomId,
      userId,
      String(profile.username || "User").slice(0, 64),
      profile.avatar_url || null,
      String(game?.name || "Game").slice(0, 64),
      game?.slug || null,
      rewardCoins,
      multiplier,
      winTier(multiplier),
    ],
  );
  if (rows[0]?.id) {
    const rowId = rows[0].id;
    const username = String(profile.username || "User").slice(0, 64);
    const sourceLabel = String(game?.name || "Game").slice(0, 64);
    const tier = winTier(multiplier);
    console.log("[baishun] patti OUT", {
      id: rowId,
      userId: userId,
      payout: rewardCoins,
      game: game?.name || gameId,
      multiplier: multiplier,
    });
    if (typeof emitGlobalWin === "function") {
      emitGlobalWin(
        {
          id: rowId,
          user_id: userId,
          username: username,
          avatar_url: profile.avatar_url || null,
          source_label: sourceLabel,
          game_slug: game?.slug || null,
          reward_coins: rewardCoins,
          bonus_multiplier: multiplier,
          multiplier_tier: tier,
          variant: "game",
          room_id: sourceRoomId || undefined,
          created_at: new Date().toISOString(),
        },
        userId,
      );
    }
  }
}
function scheduleBaishunWinPatti(params) {
  void announceBaishunWin({ ...params, emitGlobalWin: emitGlobalWinRef }).catch(
    (err) => {
      console.error("[baishun] patti", err.message);
    },
  );
}
async function handleChangeBalance(body) {
  const session = await loadValidSession(body.ss_token);
  if (!session) return baishunErr(1005, "invalid ss_token");
  if (
    body.user_id != null &&
    String(body.user_id) !== String(session.short_id) &&
    String(body.user_id) !== String(session.user_id)
  ) {
    return baishunErr(1004, "user mismatch");
  }
  const orderId = String(body.order_id || "").trim();
  const currencyDiff = Number(body.currency_diff);
  if (!orderId || !Number.isFinite(currencyDiff)) {
    return baishunErr(1003, "order_id and currency_diff required");
  }
  const { rows: rows } = await db.query(
    `SELECT public.baishun_apply_balance(\n       $1::uuid,\n       $2,\n       $3::bigint,\n       $4,\n       $5::int,\n       $6,\n       $7,\n       $8::jsonb\n     ) AS result`,
    [
      session.user_id,
      orderId,
      Math.trunc(currencyDiff),
      String(body.diff_msg || ""),
      body.game_id != null ? Number(body.game_id) : null,
      body.game_round_id != null ? String(body.game_round_id) : null,
      body.room_id != null ? String(body.room_id) : null,
      JSON.stringify({
        change_time_at: body.change_time_at ?? null,
        extend: body.extend ?? null,
        msg_type: body.msg_type ?? null,
        currency_type: body.currency_type ?? null,
        client_ip: body.client_ip ?? null,
      }),
    ],
  );
  const result = rows[0]?.result || {};
  if (!result.success) {
    const code = Number(result.code) || 1003;
    if (code === 1008) {
      return baishunErr(1008, "insufficient balance");
    }
    return baishunErr(code, String(result.error || "balance update failed"));
  }
  const diffMsg = String(body.diff_msg || "")
    .trim()
    .toLowerCase();
  const payout = Math.trunc(currencyDiff);
  if (!result.already && payout > 0 && diffMsg === "result") {
    scheduleBaishunWinPatti({
      userId: session.user_id,
      orderId: orderId,
      payout: payout,
      gameId: body.game_id != null ? Number(body.game_id) : null,
      gameRoundId:
        body.game_round_id != null ? String(body.game_round_id) : null,
      roomId: body.room_id != null ? String(body.room_id) : null,
    });
  }
  return baishunOk({ currency_balance: Number(result.balance ?? 0) });
}
async function mintLaunchCode(userId) {
  const cfg = config();
  const code = crypto.randomBytes(32).toString("base64url");
  const expiresAt = new Date(Date.now() + cfg.codeTtlMs).toISOString();
  await db.query(
    `INSERT INTO public.baishun_codes (code, user_id, expires_at)\n     VALUES ($1, $2, $3::timestamptz)`,
    [code, userId, expiresAt],
  );
  return { code: code, expires_at: expiresAt };
}
function slugify(name, gameId) {
  const base = String(name || `game${gameId}`)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 48);
  return `baishun_${base}_${gameId}`;
}
async function syncGamelistFromBaishun() {
  const cfg = config();
  if (!cfg.appKey || !cfg.appId) {
    throw new Error("BAISHUN_APP_ID and BAISHUN_APP_KEY required");
  }
  const listTypes = [2, 3];
  let inserted = 0;
  let updated = 0;
  for (const gameListType of listTypes) {
    const sign = outboundSign(cfg.appKey);
    const resp = await fetch(`${cfg.apiBase}/v1/api/gamelist`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        game_list_type: gameListType,
        app_channel: cfg.appChannel,
        app_id: Number(cfg.appId),
        ...sign,
      }),
    });
    const json = await resp.json();
    if (json.code !== 0 || !Array.isArray(json.data)) {
      throw new Error(
        `gamelist type ${gameListType} failed: ${json.msg || json.message || resp.status}`,
      );
    }
    for (const game of json.data) {
      const gameId = Number(game.game_id);
      if (!Number.isFinite(gameId)) continue;
      const slug = slugify(game.name, gameId);
      const configData = {
        provider: "baishun",
        baishun_game_id: gameId,
        download_url: game.download_url || "",
        preview_url: game.preview_url || "",
        game_version: game.game_version || "",
        game_mode: game.game_mode || [],
        game_orientation: game.game_orientation ?? 1,
        safe_height: game.safe_height ?? 800,
        venue_level: game.venue_level || [],
        app_channel: cfg.appChannel,
        app_id: Number(cfg.appId),
      };
      const gameUrl = String(game.download_url || "").trim();
      const iconUrl = String(game.preview_url || "").trim();
      configData.isLandscape = Number(game.game_orientation) === 2;
      const { rows: existing } = await db.query(
        `SELECT id, slug, config_data->>'provider' AS provider\n         FROM public.game_configs\n         WHERE config_data->>'provider' = 'baishun'\n           AND (config_data->>'baishun_game_id')::text = $1\n         LIMIT 1`,
        [String(gameId)],
      );
      if (existing[0]) {
        await db.query(
          `UPDATE public.game_configs\n           SET name = $2,\n               icon_url = CASE WHEN $3 <> '' THEN $3 ELSE icon_url END,\n               game_url = CASE WHEN $4 <> '' THEN $4 ELSE game_url END,\n               config_data = config_data || $5::jsonb\n           WHERE id = $1\n             AND config_data->>'provider' = 'baishun'`,
          [
            existing[0].id,
            String(game.name || slug),
            iconUrl,
            gameUrl,
            JSON.stringify(configData),
          ],
        );
        updated += 1;
        continue;
      }
      const { rowCount: rowCount } = await db.query(
        `INSERT INTO public.game_configs (\n           slug, name, is_active, game_url, icon_url, sort_order,\n           min_bet, max_bet, config_data, webview_height_percent\n         )\n         SELECT $1, $2, false, $3, $4, $5,\n                10, 100000, $6::jsonb, 95\n         WHERE NOT EXISTS (\n           SELECT 1 FROM public.game_configs WHERE slug = $1\n         )`,
        [
          slug,
          String(game.name || slug),
          gameUrl,
          iconUrl,
          600 + gameId,
          JSON.stringify(configData),
        ],
      );
      if (rowCount > 0) inserted += 1;
    }
  }
  return { inserted: inserted, updated: updated };
}
function mount(
  app,
  {
    pubClient: pubClient,
    verifyToken: verifyToken,
    emitGlobalWin: emitGlobalWin,
  },
) {
  emitGlobalWinRef = typeof emitGlobalWin === "function" ? emitGlobalWin : null;
  const cfg = config();
  function merchantHandler(handler) {
    return async (req, res) => {
      try {
        const verified = await verifyBaishunRequest(req, pubClient);
        if (!verified.ok) {
          return res.json(baishunErr(verified.code, verified.message));
        }
        const payload = await handler(req.body || {}, verified.cfg);
        return res.json(payload);
      } catch (err) {
        console.error("[baishun]", err.message);
        const status = err.status || 500;
        return res
          .status(status >= 400 && status < 600 ? status : 500)
          .json(
            baishunErr(
              status === 503 ? 1009 : 1e3,
              err.message || "internal error",
            ),
          );
      }
    };
  }
  app.post("/v1/api/get_sstoken", merchantHandler(handleGetSstoken));
  app.post("/v1/api/get_user_info", merchantHandler(handleGetUserInfo));
  app.post("/v1/api/update_sstoken", merchantHandler(handleUpdateSstoken));
  app.post("/v1/api/change_balance", merchantHandler(handleChangeBalance));
  app.post("/v1/api/internal/baishun_mint_code", async (req, res) => {
    try {
      const auth = String(req.headers.authorization || "").replace(
        /^Bearer\s+/i,
        "",
      );
      const payload = await verifyToken(auth);
      const userId = payload?.sub ? String(payload.sub) : "";
      if (!userId || userId.startsWith("anon:")) {
        return res.status(401).json({ ok: false, error: "unauthorized" });
      }
      const row = await mintLaunchCode(userId);
      return res.json({
        ok: true,
        ...row,
        app_channel: cfg.appChannel,
        app_id: cfg.appId ? Number(cfg.appId) : null,
      });
    } catch (err) {
      console.error("[baishun] mint_code", err.message);
      return res.status(500).json({ ok: false, error: err.message });
    }
  });
  app.post("/v1/api/internal/baishun_sync_gamelist", async (req, res) => {
    try {
      const cfgNow = config();
      const auth = String(req.headers.authorization || "").replace(
        /^Bearer\s+/i,
        "",
      );
      const admin = String(req.headers["x-baishun-admin"] || "").trim();
      let allowed = false;
      if (cfgNow.syncAdminToken && admin === cfgNow.syncAdminToken) {
        allowed = true;
      } else {
        const payload = await verifyToken(auth);
        if (payload?.sub) allowed = true;
      }
      if (!allowed) {
        return res.status(401).json({ ok: false, error: "unauthorized" });
      }
      const result = await syncGamelistFromBaishun();
      return res.json({ ok: true, ...result });
    } catch (err) {
      console.error("[baishun] sync_gamelist", err.message);
      return res.status(500).json({ ok: false, error: err.message });
    }
  });
  const enabled = !!(cfg.appKey && cfg.appId);
  console.log(
    `[baishun] merchant routes ${enabled ? "enabled" : "disabled (set BAISHUN_APP_ID/KEY)"}`,
  );
}
module.exports = {
  mount: mount,
  config: config,
  makeSignature: makeSignature,
  syncGamelistFromBaishun: syncGamelistFromBaishun,
  mintLaunchCode: mintLaunchCode,
};
