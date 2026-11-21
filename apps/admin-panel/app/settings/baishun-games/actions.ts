"use server";
import { createHash, randomBytes, randomUUID } from "crypto";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { revalidatePath } from "next/cache";
import sharp from "sharp";
import { supabaseAdmin } from "@/lib/supabase";
export type BaishunGameRow = {
  id: string;
  slug: string;
  name: string;
  is_active: boolean;
  maintenance_mode: boolean;
  maintenance_message: string;
  icon_url: string | null;
  game_url: string | null;
  sort_order: number;
  webview_height_percent: number;
  config_data: Record<string, unknown>;
  baishun_game_id: number | null;
  is_landscape: boolean;
  category_id: string | null;
  preview_url: string;
  test_game_url: string | null;
  test_user_ids: string[];
};
function asConfig(raw: unknown): Record<string, unknown> {
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  return {};
}
function truthy(v: unknown): boolean {
  return v === true || v === "true" || v === 1 || v === "1";
}
function slugify(name: string, gameId: number): string {
  const base = String(name || `game${gameId}`)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 48);
  return `baishun_${base}_${gameId}`;
}
function mapGame(row: Record<string, unknown>): BaishunGameRow {
  const cfg = asConfig(row.config_data);
  const gidRaw = cfg.baishun_game_id;
  const gid = gidRaw != null && Number.isFinite(Number(gidRaw)) ? Number(gidRaw) : null;
  return {
    id: String(row.id),
    slug: String(row.slug ?? ""),
    name: String(row.name ?? ""),
    is_active: Boolean(row.is_active),
    maintenance_mode: Boolean(row.maintenance_mode),
    maintenance_message:
      row.maintenance_message?.toString() ||
      "This game is under maintenance. Please try again later.",
    icon_url: row.icon_url ? String(row.icon_url) : null,
    game_url: row.game_url ? String(row.game_url) : null,
    sort_order: Number(row.sort_order ?? 0),
    webview_height_percent: Math.min(
      95,
      Math.max(40, Number(row.webview_height_percent ?? 95) || 95),
    ),
    config_data: cfg,
    baishun_game_id: gid,
    is_landscape: truthy(cfg.isLandscape) || truthy(cfg.is_landscape),
    category_id: row.category_id ? String(row.category_id) : null,
    preview_url: String(cfg.preview_url ?? ""),
    test_game_url: row.test_game_url ? String(row.test_game_url) : null,
    test_user_ids: Array.isArray(row.test_user_ids)
      ? (row.test_user_ids as unknown[]).map(String)
      : [],
  };
}
/**
 * Point a game at a candidate URL for named testers only.
 *
 * Everyone not listed keeps loading game_url, so a bad URL can only ever affect
 * the people testing it. Clearing the URL, or removing every tester, switches
 * the override off.
 */
export async function setGameTestUrl(input: {
  id: string;
  test_game_url: string | null;
  test_user_ids: string[];
}) {
  try {
    const url = (input.test_game_url ?? "").trim();
    if (url && !/^https?:\/\//i.test(url)) {
      return { success: false as const, error: "Test URL must start with http:// or https://" };
    }
    const ids = Array.from(new Set((input.test_user_ids ?? []).map((u) => String(u).trim()).filter(Boolean)));
    const { error } = await supabaseAdmin
      .from("game_configs")
      .update({ test_game_url: url || null, test_user_ids: ids })
      .eq("id", input.id);
    if (error) return { success: false as const, error: error.message };
    revalidateBaishun();
    return { success: true as const, testers: ids.length, active: Boolean(url && ids.length) };
  } catch (error: any) {
    return { success: false as const, error: error.message as string };
  }
}

function revalidateBaishun() {
  revalidatePath("/settings/baishun-games");
  revalidatePath("/settings/game-control");
}
function baishunEnv() {
  return {
    appId: String(process.env.BAISHUN_APP_ID || "").trim(),
    appKey: String(process.env.BAISHUN_APP_KEY || "").trim(),
    appChannel: String(process.env.BAISHUN_APP_CHANNEL || "sklive").trim(),
    apiBase: String(process.env.BAISHUN_API_BASE || "https://game-cn-test.jieyou.shop")
      .trim()
      .replace(/\/$/, ""),
  };
}
function outboundSign(appKey: string) {
  const signature_nonce = randomBytes(8).toString("hex");
  const timestamp = Math.floor(Date.now() / 1000);
  const signature = createHash("md5")
    .update(`${signature_nonce}${appKey}${timestamp}`, "utf8")
    .digest("hex")
    .toLowerCase();
  return { signature_nonce, timestamp, signature };
}
/** Prefer sharp→JPEG; if sharp is missing/broken in Alpine Docker, upload raw. */
async function encodeOrPassthroughIcon(
  buf: Buffer,
  mimeHint: string,
): Promise<{ bytes: Buffer; contentType: string; ext: string }> {
  try {
    const jpeg = await sharp(buf)
      .rotate()
      .resize(512, 512, { fit: "inside", withoutEnlargement: true })
      .jpeg({ quality: 88 })
      .toBuffer();
    return { bytes: jpeg, contentType: "image/jpeg", ext: "jpg" };
  } catch (e) {
    console.warn(
      "[baishun] sharp encode failed, raw upload:",
      e instanceof Error ? e.message : e,
    );
    const mime = (mimeHint || "").toLowerCase();
    if (mime.includes("png")) {
      return { bytes: buf, contentType: "image/png", ext: "png" };
    }
    if (mime.includes("webp")) {
      return { bytes: buf, contentType: "image/webp", ext: "webp" };
    }
    if (mime.includes("jpeg") || mime.includes("jpg")) {
      return { bytes: buf, contentType: "image/jpeg", ext: "jpg" };
    }
    throw new Error(
      "Image encode failed and file type is not png/jpeg/webp. Try a JPG or PNG.",
    );
  }
}

async function uploadIconBuffer(slug: string, buf: Buffer, mimeHint: string) {
  const encoded = await encodeOrPassthroughIcon(buf, mimeHint);
  const fileName = `baishun/${slug}.${encoded.ext}`;
  const { publicUrl } = await uploadPublicBucketToR2({
    bucket: "game-icons",
    objectPath: fileName,
    body: encoded.bytes,
    contentType: encoded.contentType,
  });
  return publicUrl;
}

async function rehostIconUrl(slug: string, sourceUrl: string) {
  const resp = await fetch(sourceUrl, {
    signal: AbortSignal.timeout(25000),
    headers: { "User-Agent": "SKLiveAdmin/1.0" },
  });
  if (!resp.ok) {
    throw new Error(`Icon download failed (${resp.status})`);
  }
  const buf = Buffer.from(await resp.arrayBuffer());
  const ct = resp.headers.get("content-type") || "image/jpeg";
  return uploadIconBuffer(slug, buf, ct);
}
function isCoolifyIcon(url: string | null | undefined) {
  const u = (url || "").trim();
  return u.includes("skliveparty.online") || u.includes("/storage/v1/object/public/game-icons/");
}
export async function listBaishunGames(): Promise<BaishunGameRow[]> {
  const { data, error } = await supabaseAdmin
    .from("game_configs")
    .select("*")
    .order("sort_order", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? [])
    .map((row) => mapGame(row as Record<string, unknown>))
    .filter((g) => g.config_data.provider === "baishun");
}
export async function updateBaishunGame(input: {
  id: string;
  name: string;
  is_active: boolean;
  maintenance_mode: boolean;
  maintenance_message?: string;
  icon_url?: string | null;
  game_url?: string | null;
  sort_order?: number;
  webview_height_percent?: number;
  is_landscape?: boolean;
  category_id?: string | null;
}) {
  try {
    const { data: existing, error: loadErr } = await supabaseAdmin
      .from("game_configs")
      .select("config_data")
      .eq("id", input.id)
      .maybeSingle();
    if (loadErr) throw loadErr;
    const cfg = asConfig(existing?.config_data);
    if (cfg.provider !== "baishun") {
      return { success: false as const, error: "Not a Baishun game" };
    }
    const nextCfg = {
      ...cfg,
      isLandscape: Boolean(input.is_landscape),
    };
    const heightPct = Math.min(
      95,
      Math.max(40, Math.floor(Number(input.webview_height_percent) || 95)),
    );
    const { error } = await supabaseAdmin
      .from("game_configs")
      .update({
        name: input.name.trim(),
        is_active: input.is_active,
        maintenance_mode: input.maintenance_mode,
        maintenance_message:
          (input.maintenance_message ?? "").trim() ||
          "This game is under maintenance. Please try again later.",
        icon_url: input.icon_url?.trim() || null,
        game_url: input.game_url?.trim() || null,
        sort_order: Math.floor(input.sort_order ?? 0),
        webview_height_percent: heightPct,
        config_data: nextCfg,
        category_id: input.category_id?.trim() || null,
      })
      .eq("id", input.id);
    if (error) return { success: false as const, error: error.message };
    revalidateBaishun();
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Save failed",
    };
  }
}
export async function uploadBaishunGameIcon(formData: FormData) {
  try {
    const file = formData.get("file") as File | null;
    const slugRaw = String(formData.get("slug") || "").trim();
    const gameId = String(formData.get("gameId") || "").trim();
    if (!file) throw new Error("No file provided");
    if (file.size > 10 * 1024 * 1024) {
      throw new Error("Image too large (max 10MB)");
    }
    const buf = Buffer.from(await file.arrayBuffer());
    const slug =
      slugRaw.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 80) ||
      `icon_${randomUUID().slice(0, 8)}`;
    const publicUrl = await uploadIconBuffer(slug, buf, file.type || "");

    // Persist immediately when editing an existing game (no separate Save needed).
    if (gameId) {
      const { error: upErr } = await supabaseAdmin
        .from("game_configs")
        .update({ icon_url: publicUrl })
        .eq("id", gameId);
      if (upErr) throw upErr;
      revalidateBaishun();
    }

    return { success: true as const, url: publicUrl };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Upload failed",
    };
  }
}
export async function rehostBaishunGameIcon(input: { id: string; sourceUrl?: string }) {
  try {
    const { data: row, error } = await supabaseAdmin
      .from("game_configs")
      .select("id, slug, icon_url, config_data")
      .eq("id", input.id)
      .maybeSingle();
    if (error) throw error;
    if (!row) return { success: false as const, error: "Game not found" };
    const cfg = asConfig(row.config_data);
    if (cfg.provider !== "baishun") {
      return { success: false as const, error: "Not a Baishun game" };
    }
    const source =
      (input.sourceUrl || "").trim() ||
      String(row.icon_url || "").trim() ||
      String(cfg.preview_url || "").trim();
    if (!source.startsWith("http")) {
      return {
        success: false as const,
        error: "No remote icon URL to rehost",
      };
    }
    const publicUrl = await rehostIconUrl(String(row.slug), source);
    const { error: upErr } = await supabaseAdmin
      .from("game_configs")
      .update({
        icon_url: publicUrl,
        config_data: { ...cfg, preview_url: source },
      })
      .eq("id", input.id);
    if (upErr) throw upErr;
    revalidateBaishun();
    return { success: true as const, url: publicUrl };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Rehost failed",
    };
  }
}
export async function addBaishunGame(input: {
  baishun_game_id: number;
  name: string;
  game_url: string;
  icon_url?: string | null;
  is_active?: boolean;
  is_landscape?: boolean;
  sort_order?: number;
  category_id?: string | null;
  webview_height_percent?: number;
}) {
  try {
    const gameId = Math.floor(Number(input.baishun_game_id));
    if (!Number.isFinite(gameId) || gameId <= 0) {
      return { success: false as const, error: "Invalid Baishun game ID" };
    }
    const name = input.name.trim();
    const gameUrl = input.game_url.trim();
    if (!name) return { success: false as const, error: "Name required" };
    if (!gameUrl.startsWith("http")) {
      return { success: false as const, error: "Game URL required" };
    }
    const existingList = await listBaishunGames();
    const existing = existingList.find((g) => g.baishun_game_id === gameId);
    if (existing) {
      return {
        success: false as const,
        error: `Game ID ${gameId} already exists (${existing.slug})`,
      };
    }
    const env = baishunEnv();
    const slug = slugify(name, gameId);
    const configData = {
      provider: "baishun",
      baishun_game_id: gameId,
      download_url: gameUrl,
      preview_url: "",
      game_version: "",
      game_mode: [] as number[],
      game_orientation: input.is_landscape ? 2 : 1,
      safe_height: 800,
      venue_level: [] as number[],
      app_channel: env.appChannel || "sklive",
      app_id: env.appId ? Number(env.appId) : null,
      isLandscape: Boolean(input.is_landscape),
    };
    const heightPct = Math.min(
      95,
      Math.max(40, Math.floor(Number(input.webview_height_percent) || 95)),
    );
    const { error } = await supabaseAdmin.from("game_configs").insert({
      slug,
      name,
      is_active: Boolean(input.is_active),
      game_url: gameUrl,
      icon_url: input.icon_url?.trim() || null,
      sort_order: Math.floor(input.sort_order ?? 600 + gameId),
      min_bet: 10,
      max_bet: 100000,
      config_data: configData,
      webview_height_percent: heightPct,
      category_id: input.category_id?.trim() || null,
      maintenance_mode: false,
      maintenance_message: "This game is under maintenance. Please try again later.",
    });
    if (error) return { success: false as const, error: error.message };
    revalidateBaishun();
    return { success: true as const, slug };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Add failed",
    };
  }
}
export async function syncBaishunGamelist(opts?: { forceRehostIcons?: boolean }) {
  try {
    const env = baishunEnv();
    if (!env.appId || !env.appKey) {
      return {
        success: false as const,
        error: "Set BAISHUN_APP_ID and BAISHUN_APP_KEY in sklive-admin .env.local",
      };
    }
    let inserted = 0;
    let updated = 0;
    let iconsHosted = 0;
    const errors: string[] = [];
    const knownByGameId = new Map(
      (await listBaishunGames())
        .filter((g) => g.baishun_game_id != null)
        .map((g) => [g.baishun_game_id as number, g]),
    );
    for (const gameListType of [2, 3]) {
      const sign = outboundSign(env.appKey);
      const resp = await fetch(`${env.apiBase}/v1/api/gamelist`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          game_list_type: gameListType,
          app_channel: env.appChannel,
          app_id: Number(env.appId),
          ...sign,
        }),
        signal: AbortSignal.timeout(30000),
      });
      const json = (await resp.json()) as {
        code?: number;
        msg?: string;
        message?: string;
        data?: Array<Record<string, unknown>>;
      };
      if (json.code !== 0 || !Array.isArray(json.data)) {
        return {
          success: false as const,
          error: `Baishun gamelist type ${gameListType} failed: ${json.msg || json.message || resp.status}`,
        };
      }
      for (const game of json.data) {
        const gameId = Number(game.game_id);
        if (!Number.isFinite(gameId)) continue;
        const name = String(game.name || `game${gameId}`);
        const slug = slugify(name, gameId);
        const downloadUrl = String(game.download_url || "").trim();
        const previewUrl = String(game.preview_url || "").trim();
        const orientation = Number(game.game_orientation ?? 1);
        const configData = {
          provider: "baishun",
          baishun_game_id: gameId,
          download_url: downloadUrl,
          preview_url: previewUrl,
          game_version: String(game.game_version || ""),
          game_mode: Array.isArray(game.game_mode) ? game.game_mode : [],
          game_orientation: orientation,
          safe_height: Number(game.safe_height ?? 800) || 800,
          venue_level: Array.isArray(game.venue_level) ? game.venue_level : [],
          app_channel: env.appChannel,
          app_id: Number(env.appId),
          isLandscape: orientation === 2,
        };
        const known = knownByGameId.get(gameId);
        let iconUrl = known?.icon_url ? String(known.icon_url) : "";
        const shouldRehost =
          previewUrl.startsWith("http") &&
          (opts?.forceRehostIcons || !iconUrl || !isCoolifyIcon(iconUrl) || iconUrl === previewUrl);
        if (shouldRehost) {
          try {
            iconUrl = await rehostIconUrl(known?.slug || slug, previewUrl);
            iconsHosted += 1;
          } catch (e: unknown) {
            errors.push(`${gameId} icon: ${e instanceof Error ? e.message : "rehost failed"}`);
            if (!iconUrl && previewUrl) iconUrl = previewUrl;
          }
        }
        if (known?.id) {
          const { error: upErr } = await supabaseAdmin
            .from("game_configs")
            .update({
              name,
              game_url: downloadUrl || known.game_url,
              icon_url: iconUrl || known.icon_url,
              config_data: configData,
            })
            .eq("id", known.id);
          if (upErr) errors.push(`${gameId}: ${upErr.message}`);
          else {
            updated += 1;
            knownByGameId.set(gameId, {
              ...known,
              name,
              game_url: downloadUrl || known.game_url,
              icon_url: iconUrl || known.icon_url,
              config_data: configData,
            });
          }
          continue;
        }
        const { data: insertedRow, error: inErr } = await supabaseAdmin
          .from("game_configs")
          .insert({
            slug,
            name,
            is_active: false,
            game_url: downloadUrl || null,
            icon_url: iconUrl || null,
            sort_order: 600 + gameId,
            min_bet: 10,
            max_bet: 100000,
            config_data: configData,
            webview_height_percent: 95,
            maintenance_mode: false,
            maintenance_message: "This game is under maintenance. Please try again later.",
          })
          .select("id")
          .maybeSingle();
        if (inErr) errors.push(`${gameId}: ${inErr.message}`);
        else {
          inserted += 1;
          if (insertedRow?.id) {
            knownByGameId.set(gameId, {
              id: String(insertedRow.id),
              slug,
              name,
              is_active: false,
              maintenance_mode: false,
              maintenance_message: "This game is under maintenance. Please try again later.",
              icon_url: iconUrl || null,
              game_url: downloadUrl || null,
              sort_order: 600 + gameId,
              webview_height_percent: 95,
              config_data: configData,
              baishun_game_id: gameId,
              is_landscape: orientation === 2,
              category_id: null,
              preview_url: previewUrl,
              test_game_url: null,
              test_user_ids: [],
            });
          }
        }
      }
    }
    revalidateBaishun();
    return {
      success: true as const,
      inserted,
      updated,
      iconsHosted,
      errors: errors.slice(0, 8),
    };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Sync failed",
    };
  }
}
