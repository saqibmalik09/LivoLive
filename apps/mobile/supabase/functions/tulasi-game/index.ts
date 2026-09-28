/**
 * Tulasi merchant callbacks (SK Live) — single file for Dashboard editor deploy.
 * Function name: tulasi-game
 * Verify JWT: OFF
 *
 * Merchant 1503241 is shared with Rave Star behind one callback proxy, so the
 * RSA key pair here must be byte-identical to Rave's.
 *
 * Secrets:
 *   TULASI_MERCHANT_PRIVATE_KEY   merchant private PEM (we decrypt requests)
 *   TULASI_PLATFORM_PUBLIC_KEY    platform public PEM (we encrypt responses)
 *   TULASI_MERCHANT_ID=1503241    optional
 *   TULASI_COIN_MAX               optional balance cap sent to H5
 *
 * Paths:
 *   POST /tulasi-game/userInformation
 *   POST /tulasi-game/updateBalance
 *   POST /tulasi-game/updateGameList
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import forge from "https://esm.sh/node-forge@1.3.1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SPLIT_SIZE = 200;
const SPLIT = ":";
const SESSION_TTL_HOURS = 24;
const TULASI_CDN_BASE =
  "https://game-1305970982.cos.ap-singapore.myqcloud.com";

/** H5 clients historically broke on huge INT32 balances; opt-in cap only. */
const TULASI_COIN_MAX = (() => {
  const raw = (Deno.env.get("TULASI_COIN_MAX") || "").trim().toLowerCase();
  if (!raw || raw === "0" || raw === "none" || raw === "off") {
    return Number.MAX_SAFE_INTEGER;
  }
  const n = Number(raw);
  if (!Number.isFinite(n) || n <= 0) return Number.MAX_SAFE_INTEGER;
  return Math.min(Math.trunc(n), Number.MAX_SAFE_INTEGER);
})();

const OUR_MERCHANT_ID = (Deno.env.get("TULASI_MERCHANT_ID") || "1503241").trim();

/** Tulasi tables are keyed by roomId; one id keeps the whole app on one table. */
const TULASI_SHARED_ROOM_ID = "0";

/**
 * Payout needed before the app-wide patti plays. The round's own stake is not
 * subtracted: a win banner shows whenever the player collects this much, even
 * if they staked more across the round.
 */
const TULASI_PATTI_MIN_PAYOUT = (() => {
  const raw = (Deno.env.get("TULASI_PATTI_MIN_PAYOUT") ||
    Deno.env.get("TULASI_PATTI_MIN_NET") || "").trim();
  const n = Number(raw);
  return Number.isFinite(n) && n >= 0 ? Math.trunc(n) : 1000;
})();

/** Some SUBTRACT callbacks land after the ADD, so let the round settle first. */
const TULASI_PATTI_SETTLE_MS = (() => {
  const n = Number((Deno.env.get("TULASI_PATTI_SETTLE_MS") || "").trim());
  return Number.isFinite(n) && n >= 0
    ? Math.min(Math.trunc(n), 10_000)
    : 1800;
})();

/** Verbose payload logging is expensive during 40–60 callback bursts. */
const TULASI_DEBUG = ["1", "true", "on"].includes(
  (Deno.env.get("TULASI_DEBUG") || "").trim().toLowerCase(),
);

type JsonMap = Record<string, unknown>;
type Admin = ReturnType<typeof createClient>;

function log(step: string, extra?: JsonMap) {
  if (!TULASI_DEBUG) return;
  if (extra) console.log(`[tulasi-game] ${step}`, extra);
  else console.log(`[tulasi-game] ${step}`);
}

function timing(extra: JsonMap) {
  console.log("[tulasi-game] TIMING", extra);
}

function clip(v: unknown, max = 500): string {
  const s = v == null ? "" : String(v);
  return s.length <= max ? s : `${s.slice(0, max)}…(${s.length})`;
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}

// ── Crypto ──────────────────────────────────────────────────────────────────

function normalizePem(pem: string): string {
  return String(pem || "").replace(/\\n/g, "\n").trim();
}

let cachedPrivatePem = "";
let cachedPrivateKey:
  | ReturnType<typeof forge.pki.privateKeyFromPem>
  | null = null;
let cachedPublicPem = "";
let cachedPublicKey:
  | ReturnType<typeof forge.pki.publicKeyFromPem>
  | null = null;

function privateKeyFromPem(pem: string) {
  const normalized = normalizePem(pem);
  if (!cachedPrivateKey || cachedPrivatePem !== normalized) {
    cachedPrivatePem = normalized;
    cachedPrivateKey = forge.pki.privateKeyFromPem(normalized);
  }
  return cachedPrivateKey;
}

function publicKeyFromPem(pem: string) {
  const normalized = normalizePem(pem);
  if (!cachedPublicKey || cachedPublicPem !== normalized) {
    cachedPublicPem = normalized;
    cachedPublicKey = forge.pki.publicKeyFromPem(normalized);
  }
  return cachedPublicKey;
}

/** Key fingerprint so a merchant/platform key mix-up is visible in logs. */
function pemMeta(pem: string): JsonMap {
  const n = normalizePem(pem);
  const first = n.split("\n")[0] || "";
  let fp = "";
  try {
    const key = forge.pki.privateKeyFromPem(n);
    const hex = key.n.toString(16);
    fp = `${hex.slice(0, 12)}…${hex.slice(-8)}`;
  } catch {
    try {
      const pub = forge.pki.publicKeyFromPem(n);
      const hex = pub.n.toString(16);
      fp = `${hex.slice(0, 12)}…${hex.slice(-8)}`;
    } catch {
      fp = "parse_fail";
    }
  }
  return { begin: first, chars: n.length, lines: n.split("\n").length, fp };
}

function encryptBigData(publicKeyPem: string, data: string): string {
  const pub = publicKeyFromPem(publicKeyPem);
  const bytes = forge.util.encodeUtf8(data);
  const chunks: string[] = [];
  for (let i = 0; i < bytes.length; i += SPLIT_SIZE) {
    const chunk = bytes.substring(i, Math.min(i + SPLIT_SIZE, bytes.length));
    chunks.push(forge.util.encode64(pub.encrypt(chunk, "RSAES-PKCS1-V1_5")));
  }
  return chunks.join(SPLIT);
}

function decryptBigData(privateKeyPem: string, encryptedText: string): string {
  const priv = privateKeyFromPem(privateKeyPem);
  const parts = String(encryptedText || "")
    .split(SPLIT)
    .map((c) => c.trim())
    .filter(Boolean);
  let out = "";
  for (const chunk of parts) {
    out += priv.decrypt(forge.util.decode64(chunk), "RSAES-PKCS1-V1_5");
  }
  try {
    return forge.util.decodeUtf8(out);
  } catch {
    return out;
  }
}

// ── Request parsing ─────────────────────────────────────────────────────────

function routeName(req: Request): string {
  const url = new URL(req.url);
  const parts = url.pathname.split("/").filter(Boolean);
  const idx = parts.lastIndexOf("tulasi-game");
  if (idx >= 0 && parts[idx + 1]) return parts[idx + 1];
  const q = url.searchParams.get("action") || url.searchParams.get("path");
  if (q) return q;
  const last = parts[parts.length - 1] || "";
  if (last.toLowerCase() === "userinformation") return "userInformation";
  if (last.toLowerCase() === "updatebalance") return "updateBalance";
  if (last.toLowerCase() === "updategamelist") return "updateGameList";
  return last;
}

/**
 * Ciphertext arrives raw, JSON-quoted, `{"data":"…"}`, form-encoded or
 * percent-encoded depending on the gateway. Any stray whitespace corrupts
 * base64 and surfaces as "Encryption block is invalid".
 */
async function readEncryptedBody(req: Request): Promise<string> {
  let raw = (await req.text()).trim();
  if (!raw) return "";

  raw = raw.replace(/^\uFEFF/, "").replace(/[\u200B-\u200D\uFEFF]/g, "");

  if (
    (raw.startsWith('"') && raw.endsWith('"')) ||
    (raw.startsWith("{") && raw.includes('"data"'))
  ) {
    try {
      const parsed = JSON.parse(raw);
      if (typeof parsed === "string") raw = parsed.trim();
      else if (parsed && typeof parsed === "object") {
        const data = (parsed as { data?: unknown }).data;
        if (typeof data === "string" && data.trim()) raw = data.trim();
      }
    } catch {
      /* raw ciphertext */
    }
  }

  if (raw.includes("=") && !raw.includes(SPLIT) && raw.length < 800) {
    try {
      const params = new URLSearchParams(raw);
      const d = params.get("data") || params.get("body") || "";
      if (d) raw = d.trim();
    } catch {
      /* keep */
    }
  }

  if (/%[0-9A-Fa-f]{2}/.test(raw)) {
    try {
      const decoded = decodeURIComponent(raw);
      if (decoded && decoded !== raw) raw = decoded.trim();
    } catch {
      /* keep */
    }
  }

  return raw.replace(/\s+/g, "");
}

function parseObject(plain: string): JsonMap | null {
  try {
    const v = JSON.parse(plain);
    if (!v || typeof v !== "object" || Array.isArray(v)) return null;
    return v as JsonMap;
  } catch {
    return null;
  }
}

function parseArray(plain: string): unknown[] | null {
  try {
    const v = JSON.parse(plain);
    return Array.isArray(v) ? v : null;
  } catch {
    return null;
  }
}

function asObject(v: unknown): JsonMap | null {
  if (!v || typeof v !== "object" || Array.isArray(v)) return null;
  return v as JsonMap;
}

function toBigint(v: unknown): number {
  if (v == null || v === "") return 0;
  const n = Number(v);
  return Number.isFinite(n) ? Math.trunc(Math.abs(n)) : 0;
}

function tulasiCoin(v: unknown): number {
  const n = Number(v);
  if (!Number.isFinite(n) || n <= 0) return 0;
  const whole = Math.trunc(n);
  return whole >= TULASI_COIN_MAX ? TULASI_COIN_MAX : whole;
}

// ── Sessions ────────────────────────────────────────────────────────────────

type SkUser = {
  id: string;
  short_id: number;
  username: string;
  coins: number;
};

type ResolvedSession = {
  user: SkUser;
  gameToken: string;
  sessionExpiresAt: number;
  cacheExpiresAt: number;
};

const SESSION_CACHE_MS = 30_000;
const sessionCache = new Map<string, ResolvedSession>();

function randomToken(): string {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return "sklive_" +
    Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

async function loadUser(admin: Admin, userId: string): Promise<SkUser | null> {
  const { data } = await admin
    .from("users")
    .select("id, short_id, username, coins")
    .eq("id", userId)
    .maybeSingle();
  if (!data?.id || data.short_id == null) return null;
  return {
    id: String(data.id),
    short_id: Number(data.short_id),
    username: String(data.username ?? "User"),
    coins: Number(data.coins ?? 0),
  };
}

/**
 * H5 strips our `sklive_` prefix on some flows, so try both spellings before
 * falling back to a Supabase JWT (what the app puts in the launch URL).
 */
async function findSession(
  admin: Admin,
  token: string,
): Promise<{ game_token: string; user_id: string; expires_at: string } | null> {
  const candidates = new Set<string>([token]);
  if (token.startsWith("sklive_")) candidates.add(token.slice(7));
  else candidates.add(`sklive_${token}`);

  const ordered = [...candidates].filter(Boolean);
  const { data } = await admin
    .from("tulasi_game_sessions")
    .select("game_token, user_id, expires_at")
    .in("game_token", ordered)
    .limit(2);
  const rows = (data ?? []) as Array<{
    game_token: string;
    user_id: string;
    expires_at: string;
  }>;
  for (const candidate of ordered) {
    const row = rows.find((item) => item.game_token === candidate);
    if (row?.user_id) {
      log("findSession HIT", { tried: candidate, user_id: row.user_id });
      return row;
    }
  }
  log("findSession MISS", { token: clip(token, 40) });
  return null;
}

async function mintGameToken(admin: Admin, userId: string): Promise<string> {
  const token = randomToken();
  const expires = new Date(
    Date.now() + SESSION_TTL_HOURS * 60 * 60 * 1000,
  ).toISOString();
  const { error } = await admin.from("tulasi_game_sessions").insert({
    game_token: token,
    user_id: userId,
    expires_at: expires,
  });
  if (error) console.error("[tulasi-game] mint session", error.message);
  return token;
}

/**
 * Resolves `token` / `gameToken` to a user. Returns the game token to echo
 * back so H5 keeps using one value for the whole session.
 */
async function resolveUser(
  admin: Admin,
  token: string,
  gameToken?: string,
): Promise<{ user: SkUser; gameToken: string } | null> {
  for (const candidate of [gameToken?.trim(), token?.trim()]) {
    if (!candidate) continue;
    const cached = sessionCache.get(candidate);
    const now = Date.now();
    if (
      cached &&
      cached.cacheExpiresAt > now &&
      cached.sessionExpiresAt > now
    ) {
      return { user: cached.user, gameToken: cached.gameToken };
    }
    if (cached) sessionCache.delete(candidate);

    const session = await findSession(admin, candidate);
    if (!session) continue;
    const sessionExpiresAt = new Date(session.expires_at).getTime();
    if (sessionExpiresAt <= now) {
      log("session expired", { expires_at: session.expires_at });
      continue;
    }
    const user = await loadUser(admin, String(session.user_id));
    if (user) {
      const resolved: ResolvedSession = {
        user,
        gameToken: session.game_token,
        sessionExpiresAt,
        cacheExpiresAt: Math.min(sessionExpiresAt, now + SESSION_CACHE_MS),
      };
      sessionCache.set(candidate, resolved);
      sessionCache.set(session.game_token, resolved);
      return { user, gameToken: session.game_token };
    }
  }

  const jwt = token?.trim();
  if (!jwt) return null;
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data.user?.id) {
    log("jwt reject", { err: error?.message });
    return null;
  }
  const user = await loadUser(admin, data.user.id);
  if (!user) return null;
  const minted = await mintGameToken(admin, user.id);
  const now = Date.now();
  const resolved: ResolvedSession = {
    user,
    gameToken: minted,
    sessionExpiresAt: now + SESSION_TTL_HOURS * 60 * 60 * 1000,
    cacheExpiresAt: now + SESSION_CACHE_MS,
  };
  sessionCache.set(minted, resolved);
  sessionCache.set(jwt, resolved);
  return { user, gameToken: minted };
}

async function loadGameCoin(admin: Admin, userId: string): Promise<number> {
  const { data } = await admin
    .from("tulasi_game_wallets")
    .select("game_coin")
    .eq("user_id", userId)
    .maybeSingle();
  return Number(data?.game_coin ?? 0);
}

// ── Win patti (app-wide top banner) ─────────────────────────────────────────

/** Mirrors the tier rules in `broadcast_room_win`. */
function winTier(multiplier: number): string {
  if (multiplier >= 450) return "x500";
  if (multiplier >= 225) return "x250";
  return `x${multiplier}`;
}

/** Runs after the H5 response so the callback stays fast. */
function runInBackground(task: Promise<unknown>) {
  const guarded = task.catch((e) =>
    console.error("[tulasi-game] patti background", String(e))
  );
  const runtime = (globalThis as {
    EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void };
  }).EdgeRuntime;
  runtime?.waitUntil?.(guarded);
}

/**
 * Bet summary for the payout's round. Tulasi bills each covered slot as its own
 * SUBTRACT callback, so the repeated/modal amount is the single-slot bet unit.
 * Rave Star uses that unit for the displayed multiplier; total stake remains
 * available for calculating SK Live's net-win banner amount.
 */
async function roundBetSummary(
  admin: Admin,
  userId: string,
  gameId: string,
  gameEndTs: unknown,
): Promise<{ totalStaked: number; betUnit: number }> {
  let query = admin
    .from("tulasi_game_transactions")
    // Snapshots carry the launch JWT, so pull just the round key we compare on.
    .select("coin, created_at, end_ts:snapshot->>gameEndTimestamp")
    .eq("user_id", userId)
    .eq("type", 0)
    .gte("created_at", new Date(Date.now() - 10 * 60 * 1000).toISOString())
    .order("created_at", { ascending: false })
    .limit(300);
  if (gameId) query = query.eq("snapshot->>gameId", gameId);

  const { data, error } = await query;
  if (error) {
    console.error("[tulasi-game] round bets", error.message);
    return { totalStaked: 0, betUnit: 0 };
  }
  const rows = (data ?? []) as Array<
    { coin: unknown; created_at: string; end_ts: string | null }
  >;

  const endKey = gameEndTs == null || gameEndTs === "" ? "" : String(gameEndTs);
  let round = endKey
    ? rows.filter((r) => String(r.end_ts ?? "") === endKey)
    : [];
  if (round.length === 0) {
    const cutoff = Date.now() - 90_000;
    round = rows.filter((r) => Date.parse(r.created_at) >= cutoff);
  }

  let totalStaked = 0;
  const unitCounts = new Map<number, number>();
  for (const row of round) {
    const amount = toBigint(row.coin);
    if (amount <= 0) continue;
    totalStaked += amount;
    unitCounts.set(amount, (unitCounts.get(amount) ?? 0) + 1);
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
  return { totalStaked, betUnit };
}

async function loadTulasiGame(
  admin: Admin,
  gameId: string,
): Promise<{ slug: string; name: string } | null> {
  if (!gameId) return null;
  const { data } = await admin
    .from("game_configs")
    .select("slug, name")
    .eq("config_data->>tulasi_game_id", gameId)
    .limit(1);
  const row = (data ?? [])[0] as { slug?: unknown; name?: unknown } | undefined;
  if (!row?.slug) return null;
  return {
    slug: String(row.slug),
    name: String(row.name ?? row.slug),
  };
}

/**
 * Publishes the top winning banner for a Tulasi payout. The amount shown is the
 * payout the player collected; the round's stake is only used for the displayed
 * multiplier, so a banner still plays on a round the player is down on.
 */
async function announceTulasiWin(
  admin: Admin,
  user: SkUser,
  reqJson: JsonMap,
) {
  const payout = toBigint(reqJson.coin);
  if (payout < TULASI_PATTI_MIN_PAYOUT || payout <= 0) {
    log("patti SKIP", { payout, min: TULASI_PATTI_MIN_PAYOUT });
    return;
  }

  if (TULASI_PATTI_SETTLE_MS > 0) {
    await new Promise((r) => setTimeout(r, TULASI_PATTI_SETTLE_MS));
  }

  const gameId = String(reqJson.gameId ?? "").trim();
  const { totalStaked: staked, betUnit } = await roundBetSummary(
    admin,
    user.id,
    gameId,
    reqJson.gameEndTimestamp,
  );
  // Ignore stakes on losing slots: match Rave Star's single winning-bet unit.
  const multiplier = betUnit > 0
    ? Math.min(Math.max(Math.round(payout / betUnit), 1), 999999)
    : 1;
  const game = await loadTulasiGame(admin, gameId);
  const { data: profile } = await admin
    .from("users")
    .select("avatar_url")
    .eq("id", user.id)
    .maybeSingle();

  const row = {
    user_id: user.id,
    username: user.username,
    avatar_url: profile?.avatar_url ?? null,
    source_label: String(
      game?.name ?? reqJson.gameType ?? "Game",
    ).slice(0, 64),
    reward_coins: payout,
    bonus_multiplier: multiplier,
    multiplier_tier: winTier(multiplier),
    variant: "game",
    game_slug: game?.slug ?? null,
    server_broadcast: true,
  };

  const { error } = await admin.from("global_win_announcements").insert(row);
  if (error) {
    console.error("[tulasi-game] patti insert", error.message);
    return;
  }
  log("patti OUT", { ...row, payout, staked, betUnit });
}

// ── Handlers ────────────────────────────────────────────────────────────────

async function handleUserInformation(
  admin: Admin,
  publicKey: string,
  plain: string,
) {
  const reqJson = parseObject(plain);
  if (!reqJson) return json({ code: 0, msg: "invalid_json" });

  const token = String(reqJson.token ?? "").trim();
  log("userInformation REQ", {
    tokenLen: token.length,
    gameType: reqJson.gameType,
    keys: Object.keys(reqJson),
  });
  if (!token) return json({ code: 0, msg: "token required" });

  const resolved = await resolveUser(admin, token);
  if (!resolved) {
    log("userInformation OUT invalid token");
    return json({ code: 0, msg: "invalid token" });
  }

  const { user, gameToken } = resolved;
  const data = {
    id: user.short_id,
    coin: tulasiCoin(user.coins),
    gameCoin: tulasiCoin(await loadGameCoin(admin, user.id)),
    gameToken,
    nickname: String(user.username || "User").slice(0, 24),
    // Long avatar URLs push the payload into a 2nd RSA chunk and some H5
    // builds only decrypt the first one, which fails login.
    avatar: "",
  };

  const plainOut = JSON.stringify(data);
  const encrypted = encryptBigData(publicKey, plainOut);
  log("userInformation OUT success", {
    ...data,
    rawCoin: user.coins,
    coinCap: TULASI_COIN_MAX,
    plainLen: plainOut.length,
    encChunks: encrypted.split(SPLIT).length,
  });
  return json({ code: 1, msg: "success", data: encrypted });
}

async function handleUpdateBalance(
  admin: Admin,
  publicKey: string,
  plain: string,
  requestTiming?: {
    startedAt: number;
    bodyMs: number;
    decryptMs: number;
  },
) {
  const handlerStartedAt = performance.now();
  const reqJson = parseObject(plain);
  if (!reqJson) return json({ code: 0, msg: "invalid_json" });

  const token = String(reqJson.token ?? "").trim();
  const gameToken = String(reqJson.gameToken ?? "").trim();
  const transactionId = String(reqJson.transactionId ?? "").trim();
  const uidRaw = reqJson.uid;
  const type = Number(reqJson.type);

  log("updateBalance REQ", {
    transactionId,
    uid: uidRaw,
    type,
    coin: reqJson.coin,
    gameCoin: reqJson.gameCoin,
    gameId: reqJson.gameId,
    roomId: reqJson.roomId,
    keys: Object.keys(reqJson),
  });
  if (!token || !transactionId) {
    return json({ code: 0, msg: "token and transactionId required" });
  }

  const resolveStartedAt = performance.now();
  const resolved = await resolveUser(admin, token, gameToken || undefined);
  const resolveMs = performance.now() - resolveStartedAt;
  if (!resolved) {
    log("updateBalance OUT invalid token");
    return json({ code: 0, msg: "invalid token" });
  }
  const { user } = resolved;

  const reqUid = uidRaw == null || uidRaw === "" ? null : Number(uidRaw);
  if (reqUid != null && Number.isFinite(reqUid) && reqUid !== user.short_id) {
    log("updateBalance OUT uid mismatch", { reqUid, short_id: user.short_id });
    return json({ code: 0, msg: "uid mismatch" });
  }

  const rpcStartedAt = performance.now();
  const { data: rpcData, error: rpcErr } = await admin.rpc(
    "tulasi_apply_balance",
    {
      p_user_id: user.id,
      p_transaction_id: transactionId,
      p_type: Number.isFinite(type) ? type : -1,
      p_coin: toBigint(reqJson.coin),
      p_game_coin: toBigint(reqJson.gameCoin),
      p_game_end_ts_ms: reqJson.gameEndTimestamp == null ||
          reqJson.gameEndTimestamp === ""
        ? null
        : Math.trunc(Number(reqJson.gameEndTimestamp)),
      p_snapshot: reqJson,
    },
  );
  const rpcMs = performance.now() - rpcStartedAt;
  if (rpcErr) {
    console.error("[tulasi-game] updateBalance rpc", rpcErr.message);
    return json({ code: 0, msg: rpcErr.message || "balance_failed" });
  }

  const result = asObject(rpcData);
  if (!result || result.success !== true) {
    log("updateBalance OUT rpc reject", { msg: result?.error });
    return json({ code: 0, msg: String(result?.error ?? "balance_failed") });
  }

  const data = {
    id: Number(result.id ?? user.short_id),
    coin: tulasiCoin(result.coin ?? user.coins),
  };
  log("updateBalance OUT success", { ...data, already: result.already });

  // type 1 = payout credited. Retries return already=true and must not re-announce.
  if (type === 1 && result.already !== true) {
    runInBackground(announceTulasiWin(admin, user, reqJson));
  }

  const encryptStartedAt = performance.now();
  const encrypted = encryptBigData(publicKey, JSON.stringify(data));
  const encryptMs = performance.now() - encryptStartedAt;
  const now = performance.now();
  timing({
    route: "updateBalance",
    transactionId,
    type,
    body_ms: Math.round(requestTiming?.bodyMs ?? 0),
    decrypt_ms: Math.round(requestTiming?.decryptMs ?? 0),
    resolve_ms: Math.round(resolveMs),
    rpc_ms: Math.round(rpcMs),
    encrypt_ms: Math.round(encryptMs),
    handler_ms: Math.round(now - handlerStartedAt),
    total_ms: Math.round(
      now - (requestTiming?.startedAt ?? handlerStartedAt),
    ),
    cached_session: resolveMs < 5,
    already: result.already === true,
  });
  return json({
    code: 1,
    msg: "success",
    data: encrypted,
  });
}

function resolveTulasiIcon(item: JsonMap): string {
  const candidates = [item.image, item.banner, item.imagePath, item.bannerPath];
  for (const raw of candidates) {
    const v = String(raw ?? "").trim();
    if (!v) continue;
    if (v.startsWith("http://") || v.startsWith("https://")) return v;
    if (v.startsWith("/")) return `${TULASI_CDN_BASE}${v}`;
    if (v.startsWith("upload/")) return `${TULASI_CDN_BASE}/${v}`;
  }
  return "";
}

function joinUrl(domain: string, identification: string): string {
  const base = domain.trim() || "https://gamesp.tulasigame.com/";
  const withSlash = base.endsWith("/") ? base : `${base}/`;
  return `${withSlash}${identification.replace(/^\/+/, "")}/`;
}

async function handleUpdateGameList(admin: Admin, plain: string) {
  const list = parseArray(plain);
  if (!list) return json({ code: 0, msg: "invalid_json" });

  let upserted = 0;
  let skippedOtherMerchant = 0;
  let sortBase = 500;

  for (const raw of list) {
    if (!raw || typeof raw !== "object") continue;
    const item = raw as JsonMap;

    const itemMerchant = item.merchantId == null || item.merchantId === ""
      ? null
      : String(item.merchantId).trim();
    // The callback is shared, so another merchant's catalog can arrive here.
    if (itemMerchant && itemMerchant !== OUR_MERCHANT_ID) {
      skippedOtherMerchant++;
      continue;
    }

    const tulasiId = String(item.id ?? "").trim();
    const identification = String(item.gameIdentification ?? item.gameName ?? "")
      .trim();
    let slug = identification || (tulasiId ? `tulasi_${tulasiId}` : "");
    if (!slug) continue;

    const columns = "slug, is_active, category_id, sort_order, config_data";
    let { data: existing } = await admin
      .from("game_configs")
      .select(columns)
      .eq("slug", slug)
      .maybeSingle();

    const provider = (existing?.config_data as JsonMap | null)?.provider;
    if (existing && provider && provider !== "tulasi") {
      // A first-party game already owns this slug — keep ours namespaced.
      slug = `tulasi_${slug}`;
      ({ data: existing } = await admin
        .from("game_configs")
        .select(columns)
        .eq("slug", slug)
        .maybeSingle());
    }
    const owned = existing;

    const status = Number(item.status ?? 1);
    const domain = String(item.gameDomain ?? "https://gamesp.tulasigame.com/");
    const gameUrl = `${joinUrl(domain, identification || slug)}` +
      `?merchant=${encodeURIComponent(OUR_MERCHANT_ID)}` +
      `&gameId=${encodeURIComponent(tulasiId || "0")}` +
      // One shared Tulasi table for the whole app, not one per SK room.
      `&roomId=${TULASI_SHARED_ROOM_ID}`;

    const payload: JsonMap = {
      slug,
      name: String(item.name ?? slug),
      icon_url: resolveTulasiIcon(item),
      game_url: gameUrl,
      maintenance_mode: status !== 1,
      config_data: {
        provider: "tulasi",
        tulasi_game_id: tulasiId || null,
        tulasi_merchant_id: itemMerchant ?? OUR_MERCHANT_ID,
        tulasi_banner: item.banner ?? "",
        tulasi_image_path: item.imagePath ?? "",
        tulasi_banner_path: item.bannerPath ?? "",
        tulasi_game_domain: domain,
        tulasi_expiration: item.expirationDate ?? null,
        isLandscape: (() => {
          const prev = owned?.config_data as JsonMap | null;
          const v = prev?.isLandscape ?? prev?.is_landscape;
          return v === true || v === "true" || v === 1 || v === "1";
        })(),
      },
      // Admin owns visibility and placement; sync must not undo those toggles.
      is_active: owned ? owned.is_active : status === 1,
      category_id: owned ? owned.category_id : null,
      sort_order: owned
        ? owned.sort_order
        : (Number.isFinite(Number(tulasiId)) ? Number(tulasiId) : sortBase++),
    };

    const { error } = await admin
      .from("game_configs")
      .upsert(payload, { onConflict: "slug" });
    if (error) {
      console.error("[tulasi-game] game_configs upsert", slug, error.message);
      continue;
    }
    upserted++;
  }

  log("updateGameList OUT success", {
    count: list.length,
    upserted,
    skippedOtherMerchant,
    ourMerchant: OUR_MERCHANT_ID,
  });
  return json({ code: 1, msg: "success", data: "" });
}

// ── Entry ───────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const requestStartedAt = performance.now();
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  const url = new URL(req.url);
  try {
    const route = routeName(req);
    log("IN", {
      method: req.method,
      path: url.pathname,
      route,
      ct: req.headers.get("content-type"),
    });

    const privateKey = Deno.env.get("TULASI_MERCHANT_PRIVATE_KEY") || "";
    const publicKey = Deno.env.get("TULASI_PLATFORM_PUBLIC_KEY") || "";
    if (!privateKey || !publicKey) {
      log("OUT tulasi_not_configured");
      return json({ code: 0, msg: "tulasi_not_configured" }, 503);
    }
    if (TULASI_DEBUG) {
      log("KEYS", {
        merchantId: OUR_MERCHANT_ID,
        merchant: pemMeta(privateKey),
        platform: pemMeta(publicKey),
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, service);

    const bodyStartedAt = performance.now();
    const encryptedText = await readEncryptedBody(req);
    const bodyMs = performance.now() - bodyStartedAt;
    log("BODY", {
      chars: encryptedText.length,
      chunks: encryptedText ? encryptedText.split(SPLIT).length : 0,
      preview: clip(encryptedText, 120),
    });
    if (!encryptedText) return json({ code: 0, msg: "empty_body" });

    let plain: string;
    const decryptStartedAt = performance.now();
    try {
      plain = decryptBigData(privateKey, encryptedText);
    } catch (e) {
      // Almost always a merchant key mismatch — compare the KEYS fingerprint
      // above with the public key registered in the Tulasi dashboard.
      log("DECRYPT_FAIL", { err: String(e) });
      return json({ code: 0, msg: "decrypt_failed" });
    }
    const decryptMs = performance.now() - decryptStartedAt;
    log("PLAIN", { chars: plain.length, text: clip(plain, 800) });

    if (route === "userInformation") {
      return await handleUserInformation(admin, publicKey, plain);
    }
    if (route === "updateBalance") {
      return await handleUpdateBalance(admin, publicKey, plain, {
        startedAt: requestStartedAt,
        bodyMs,
        decryptMs,
      });
    }
    if (route === "updateGameList") {
      return await handleUpdateGameList(admin, plain);
    }

    log("OUT unknown_route", { route });
    return json({ code: 0, msg: `unknown_route:${route}` }, 404);
  } catch (e) {
    log("ERR", { err: String(e) });
    return json({ code: 0, msg: "internal", detail: String(e) }, 500);
  }
});
