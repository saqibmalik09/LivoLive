"use server";
import { randomUUID } from "crypto";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { revalidatePath } from "next/cache";
import { supabaseAdmin } from "@/lib/supabase";
function intervalToSeconds(value: unknown): number {
  if (value == null) return 0;
  if (typeof value === "number" && Number.isFinite(value)) return Math.max(0, Math.floor(value));
  const raw = String(value).trim();
  if (!raw) return 0;
  const hms = raw.match(/^(\d+):(\d+):(\d+(?:\.\d+)?)$/);
  if (hms) {
    const h = parseInt(hms[1], 10);
    const m = parseInt(hms[2], 10);
    const s = Math.floor(parseFloat(hms[3]));
    return h * 3600 + m * 60 + s;
  }
  const secOnly = raw.match(/^(\d+(?:\.\d+)?)\s*seconds?$/i);
  if (secOnly) return Math.floor(parseFloat(secOnly[1]));
  const n = parseInt(raw, 10);
  return Number.isFinite(n) ? n : 0;
}
function secondsToInterval(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds || 0));
  return `${s} seconds`;
}
export type GameConfigRow = {
  id: string;
  slug: string;
  name: string;
  is_active: boolean;
  maintenance_mode: boolean;
  maintenance_message: string;
  min_bet: number;
  max_bet: number;
  betting_duration_sec: number;
  spinning_duration_sec: number;
  result_duration_sec: number;
  icon_url: string | null;
  game_url: string | null;
  sort_order: number;
  webview_height_percent: number;
  config_data: Record<string, unknown> | null;
  category_id: string | null;
};
export type RoomGameCategoryRow = {
  id: string;
  name: string;
  sort_order: number;
  is_active: boolean;
};
export async function listGameConfigsForAdmin(): Promise<GameConfigRow[]> {
  const { data, error } = await supabaseAdmin
    .from("game_configs")
    .select("*")
    .order("sort_order", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => ({
    id: String(row.id),
    slug: String(row.slug ?? ""),
    name: String(row.name ?? ""),
    is_active: Boolean(row.is_active),
    maintenance_mode: Boolean(row.maintenance_mode),
    maintenance_message:
      row.maintenance_message?.toString() ||
      "This game is under maintenance. Please try again later.",
    min_bet: Number(row.min_bet ?? 0),
    max_bet: Number(row.max_bet ?? 0),
    betting_duration_sec: intervalToSeconds(row.betting_duration),
    spinning_duration_sec: intervalToSeconds(row.spinning_duration),
    result_duration_sec: intervalToSeconds(row.result_duration),
    icon_url: row.icon_url ? String(row.icon_url) : null,
    game_url: row.game_url ? String(row.game_url) : null,
    sort_order: Number(row.sort_order ?? 0),
    webview_height_percent: Math.min(
      95,
      Math.max(40, Number(row.webview_height_percent ?? 70) || 70),
    ),
    config_data:
      row.config_data && typeof row.config_data === "object"
        ? (row.config_data as Record<string, unknown>)
        : {},
    category_id: row.category_id ? String(row.category_id) : null,
  }));
}
export async function listRoomGameCategories(): Promise<RoomGameCategoryRow[]> {
  const { data, error } = await supabaseAdmin
    .from("room_game_categories")
    .select("id, name, sort_order, is_active")
    .order("sort_order", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => ({
    id: String(row.id),
    name: String(row.name ?? ""),
    sort_order: Number(row.sort_order ?? 0),
    is_active: row.is_active !== false,
  }));
}
export async function getGameControlMode(): Promise<string> {
  const { data } = await supabaseAdmin
    .from("system_settings")
    .select("value")
    .eq("key", "game_control_mode")
    .maybeSingle();
  return data?.value?.toString() || "random";
}
export type RtpEngineSettings = {
  enabled: boolean;
  target_rtp: string;
  bank_alpha: string;
  bank_clamp_min: string;
  bank_clamp_max: string;
  max_round_exposure: string;
  mercy_streak: string;
  mercy_max_mult: string;
};
const RTP_DEFAULTS: RtpEngineSettings = {
  enabled: true,
  target_rtp: "0.90",
  bank_alpha: "0.30",
  bank_clamp_min: "0.7",
  bank_clamp_max: "1.4",
  max_round_exposure: "12.0",
  mercy_streak: "8",
  mercy_max_mult: "5",
};
const RTP_KEYS: {
  settingKey: string;
  field: keyof Omit<RtpEngineSettings, "enabled">;
  description: string;
}[] = [
  {
    settingKey: "game_target_rtp",
    field: "target_rtp",
    description: "Player RTP target (0.90 = 10% platform edge).",
  },
  {
    settingKey: "game_bank_alpha",
    field: "bank_alpha",
    description: "How strongly the rolling bank adjusts blank weight.",
  },
  {
    settingKey: "game_bank_clamp_min",
    field: "bank_clamp_min",
    description: "Min blank adjustment factor k.",
  },
  {
    settingKey: "game_bank_clamp_max",
    field: "bank_clamp_max",
    description: "Max blank adjustment factor k.",
  },
  {
    settingKey: "game_max_round_exposure",
    field: "max_round_exposure",
    description:
      "Solvency resample if payout > pool×this + 20% positive bank. Per-game override: config_data.max_round_exposure.",
  },
  {
    settingKey: "game_mercy_streak",
    field: "mercy_streak",
    description: "Consecutive losses before mercy bias toward low multipliers.",
  },
  {
    settingKey: "game_mercy_max_mult",
    field: "mercy_max_mult",
    description: "Mercy only applies to options with multiplier ≤ this.",
  },
];
async function upsertSetting(key: string, value: string, description: string) {
  const { data: existing } = await supabaseAdmin
    .from("system_settings")
    .select("key")
    .eq("key", key)
    .maybeSingle();
  if (existing) {
    const { error } = await supabaseAdmin
      .from("system_settings")
      .update({ value, description })
      .eq("key", key);
    if (error) throw new Error(error.message);
  } else {
    const { error } = await supabaseAdmin.from("system_settings").insert({
      key,
      value,
      description,
    });
    if (error) throw new Error(error.message);
  }
}
export async function getRtpEngineSettings(): Promise<RtpEngineSettings> {
  const keys = ["game_engine_v2", ...RTP_KEYS.map((k) => k.settingKey)];
  const { data } = await supabaseAdmin.from("system_settings").select("key, value").in("key", keys);
  const map = new Map((data ?? []).map((r) => [String(r.key), String(r.value ?? "")]));
  const out = { ...RTP_DEFAULTS };
  const en = map.get("game_engine_v2");
  if (en != null && en !== "") {
    out.enabled = ["1", "true", "yes", "on"].includes(en.trim().toLowerCase());
  }
  for (const row of RTP_KEYS) {
    const v = map.get(row.settingKey);
    if (v != null && v !== "") out[row.field] = v;
  }
  return out;
}
export async function saveRtpEngineSettings(input: RtpEngineSettings) {
  try {
    await upsertSetting(
      "game_engine_v2",
      input.enabled ? "true" : "false",
      "Use inverse-multiplier RTP wheel (v2). false = legacy resolve_game_winner_v1.",
    );
    await upsertSetting(
      "game_control_auto_switch",
      "false",
      "Disabled under v2 (single RTP engine).",
    );
    for (const row of RTP_KEYS) {
      await upsertSetting(row.settingKey, String(input[row.field] ?? ""), row.description);
    }
    revalidatePath("/settings/game-control");
    revalidatePath("/settings/game-logs");
    return { success: true as const };
  } catch (e: any) {
    return { success: false as const, error: e?.message || "Failed to save RTP settings" };
  }
}
export type HouseEdgeSettings = {
  target_edge: string;
  max_round_rtp: string;
  pay_to_bets_rate: string;
  natural_win_rate: string;
  soft_edge_rate: string;
  big_hit_enabled: string;
  big_hit_every_min: string;
  big_hit_every_max: string;
  big_hit_min_mult: string;
  big_hit_rate: string;
  daily_loss_breaker: string;
  outcome_weights: string;
};
const HOUSE_DEFAULTS: HouseEdgeSettings = {
  target_edge: "0.10",
  max_round_rtp: "0.95",
  pay_to_bets_rate: "0.40",
  natural_win_rate: "0.90",
  soft_edge_rate: "0.08",
  big_hit_enabled: "false",
  big_hit_every_min: "80",
  big_hit_every_max: "120",
  big_hit_min_mult: "15",
  big_hit_rate: "0.05",
  daily_loss_breaker: "0",
  outcome_weights: '{"5":30,"10":12,"15":6,"25":2,"45":1}',
};
const HOUSE_KEYS: {
  settingKey: string;
  field: keyof HouseEdgeSettings;
  description: string;
}[] = [
  {
    settingKey: "game_house_target_edge",
    field: "target_edge",
    description: "Soft target house edge (0.10 = 10%). Used for ranking among safe options.",
  },
  {
    settingKey: "game_house_max_round_rtp",
    field: "max_round_rtp",
    description:
      "Hard cap: never pay more than this fraction of the round pool when a safer option exists.",
  },
  {
    settingKey: "game_house_pay_to_bets_rate",
    field: "pay_to_bets_rate",
    description:
      "Probability of landing on a safe option that has bets (prefer lowest payout). ~0.40 = ~40% rounds pay someone.",
  },
  {
    settingKey: "game_house_natural_win_rate",
    field: "natural_win_rate",
    description: "Legacy fallback if pay_to_bets_rate unset. Prefer Pay-to-bets rate instead.",
  },
  {
    settingKey: "game_house_soft_edge_rate",
    field: "soft_edge_rate",
    description: "Probability of landing on safest high-profit option among bet options.",
  },
  {
    settingKey: "game_house_big_hit_enabled",
    field: "big_hit_enabled",
    description:
      "If true, occasionally prefer high-mult options ONLY when still under max_round_rtp.",
  },
  {
    settingKey: "game_house_big_hit_every_min",
    field: "big_hit_every_min",
    description: "Min settled rounds without a big hit before considering one (only if enabled).",
  },
  {
    settingKey: "game_house_big_hit_every_max",
    field: "big_hit_every_max",
    description: "Max settled rounds without a big hit before considering one (only if enabled).",
  },
  {
    settingKey: "game_house_big_hit_min_mult",
    field: "big_hit_min_mult",
    description: 'Multiplier >= this counts as a "big number" hit.',
  },
  {
    settingKey: "game_house_big_hit_rate",
    field: "big_hit_rate",
    description: "When big-hit window is open: probability of attempting a safe big hit.",
  },
  {
    settingKey: "game_house_daily_loss_breaker",
    field: "daily_loss_breaker",
    description:
      "If today house_net for this game < -this (coins), force safest only. 0 = disabled.",
  },
  {
    settingKey: "game_house_outcome_weights",
    field: "outcome_weights",
    description:
      'Multiplier → weight JSON. Example {"5":30,"10":12,"15":6,"25":2,"45":1} — 5x common, 45x rare.',
  },
];
export async function getHouseEdgeSettings(): Promise<HouseEdgeSettings> {
  const keys = HOUSE_KEYS.map((k) => k.settingKey);
  const { data } = await supabaseAdmin.from("system_settings").select("key, value").in("key", keys);
  const map = new Map((data ?? []).map((r) => [String(r.key), String(r.value ?? "")]));
  const out = { ...HOUSE_DEFAULTS };
  for (const row of HOUSE_KEYS) {
    const v = map.get(row.settingKey);
    if (v != null && v !== "") out[row.field] = v;
  }
  return out;
}
export async function saveGameControlMode(mode: string) {
  const value = mode === "house_optimized" ? "house_optimized" : "random";
  try {
    const { data: existing } = await supabaseAdmin
      .from("system_settings")
      .select("key")
      .eq("key", "game_control_mode")
      .maybeSingle();
    if (existing) {
      const { error } = await supabaseAdmin
        .from("system_settings")
        .update({ value })
        .eq("key", "game_control_mode");
      if (error) return { success: false, error: error.message };
    } else {
      const { error } = await supabaseAdmin.from("system_settings").insert({
        key: "game_control_mode",
        value,
        description: "H5 game engine mode: random | house_optimized",
      });
      if (error) return { success: false, error: error.message };
    }
    revalidatePath("/settings/game-control");
    revalidatePath("/settings/game-logs");
    return { success: true };
  } catch (e: any) {
    return { success: false, error: e?.message || "Failed to save mode" };
  }
}
export type AutoSwitchSettings = {
  enabled: boolean;
  loss_coins: string;
  recover_coins: string;
  max_loss_coins: string;
  last: string;
};
const AUTO_DEFAULTS: AutoSwitchSettings = {
  enabled: false,
  loss_coins: "50000000",
  recover_coins: "100000000",
  max_loss_coins: "100000000",
  last: "",
};
export async function getAutoSwitchSettings(): Promise<AutoSwitchSettings> {
  const { data } = await supabaseAdmin
    .from("system_settings")
    .select("key, value")
    .in("key", [
      "game_control_auto_switch",
      "game_auto_loss_coins",
      "game_auto_recover_coins",
      "game_platform_max_loss_coins",
      "game_control_auto_last",
    ]);
  const map = new Map((data ?? []).map((r) => [String(r.key), String(r.value ?? "")]));
  const raw = (map.get("game_control_auto_switch") || "false").toLowerCase();
  return {
    enabled: ["1", "true", "yes", "on"].includes(raw),
    loss_coins: map.get("game_auto_loss_coins") || AUTO_DEFAULTS.loss_coins,
    recover_coins: map.get("game_auto_recover_coins") || AUTO_DEFAULTS.recover_coins,
    max_loss_coins: map.get("game_platform_max_loss_coins") || AUTO_DEFAULTS.max_loss_coins,
    last: map.get("game_control_auto_last") || "",
  };
}
export async function saveAutoSwitchSettings(input: {
  enabled: boolean;
  loss_coins: string;
  recover_coins: string;
  max_loss_coins?: string;
}) {
  try {
    const loss = String(input.loss_coins ?? "").trim();
    const recover = String(input.recover_coins ?? "").trim();
    const maxLoss = String(input.max_loss_coins ?? AUTO_DEFAULTS.max_loss_coins).trim();
    if (!/^\d+$/.test(loss))
      return { success: false, error: "Loss threshold must be a non-negative integer" };
    if (!/^-?\d+$/.test(recover)) {
      return { success: false, error: "Recover threshold must be an integer" };
    }
    if (!/^\d+$/.test(maxLoss)) {
      return { success: false, error: "Max loss cap must be a non-negative integer" };
    }
    await upsertSetting(
      "game_control_auto_switch",
      input.enabled ? "true" : "false",
      "If true, automatically switch Random↔House from today platform P&L. If false, admin manual only.",
    );
    await upsertSetting(
      "game_auto_loss_coins",
      loss,
      "When today net (stake-payout) < -this, auto-set mode to house_optimized (50M).",
    );
    await upsertSetting(
      "game_auto_recover_coins",
      recover,
      "When today net (stake-payout) >= this, auto-set mode to random (100M profit).",
    );
    await upsertSetting(
      "game_platform_max_loss_coins",
      maxLoss,
      "Hard cap: never resolve a winner that would push today platform net below -this (100M).",
    );
    revalidatePath("/settings/game-control");
    revalidatePath("/settings/game-logs");
    return { success: true };
  } catch (e: any) {
    return { success: false, error: e?.message || "Failed to save auto switch" };
  }
}
function normalizeHouseValue(field: keyof HouseEdgeSettings, raw: string): string | null {
  const v = String(raw ?? "").trim();
  if (field === "big_hit_enabled") {
    return ["1", "true", "yes", "on"].includes(v.toLowerCase()) ? "true" : "false";
  }
  if (field === "outcome_weights") {
    try {
      const parsed = JSON.parse(v);
      if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) return null;
      for (const [k, val] of Object.entries(parsed)) {
        if (!/^\d+$/.test(k)) return null;
        const n = Number(val);
        if (!Number.isFinite(n) || n < 1) return null;
      }
      return JSON.stringify(parsed);
    } catch {
      return null;
    }
  }
  if (
    field === "big_hit_every_min" ||
    field === "big_hit_every_max" ||
    field === "big_hit_min_mult" ||
    field === "daily_loss_breaker"
  ) {
    if (!/^\d+$/.test(v)) return null;
    return String(Math.max(0, parseInt(v, 10)));
  }
  if (!/^[0-9]*\.?[0-9]+$/.test(v)) return null;
  const n = parseFloat(v);
  if (!Number.isFinite(n)) return null;
  if (field === "target_edge") return String(Math.min(0.5, Math.max(0, n)));
  if (field === "max_round_rtp") return String(Math.min(1, Math.max(0.5, n)));
  if (field === "natural_win_rate" || field === "soft_edge_rate" || field === "big_hit_rate") {
    return String(Math.min(1, Math.max(0, n)));
  }
  return v;
}
export async function saveHouseEdgeSettings(input: HouseEdgeSettings) {
  try {
    for (const row of HOUSE_KEYS) {
      const normalized = normalizeHouseValue(row.field, input[row.field]);
      if (normalized == null) {
        return { success: false, error: `Invalid value for ${row.field}` };
      }
      const { data: existing } = await supabaseAdmin
        .from("system_settings")
        .select("key")
        .eq("key", row.settingKey)
        .maybeSingle();
      if (existing) {
        const { error } = await supabaseAdmin
          .from("system_settings")
          .update({ value: normalized, description: row.description })
          .eq("key", row.settingKey);
        if (error) return { success: false, error: error.message };
      } else {
        const { error } = await supabaseAdmin.from("system_settings").insert({
          key: row.settingKey,
          value: normalized,
          description: row.description,
        });
        if (error) return { success: false, error: error.message };
      }
    }
    revalidatePath("/settings/game-control");
    return { success: true };
  } catch (e: any) {
    return { success: false, error: e?.message || "Failed to save house edge settings" };
  }
}
export async function upsertGameConfig(input: {
  id: string;
  name: string;
  is_active: boolean;
  maintenance_mode: boolean;
  maintenance_message: string;
  min_bet: number;
  max_bet: number;
  betting_duration_sec: number;
  spinning_duration_sec: number;
  result_duration_sec: number;
  icon_url: string | null;
  game_url: string | null;
  sort_order: number;
  webview_height_percent: number;
  config_data_json: string;
  category_id?: string | null;
}) {
  try {
    let configData: Record<string, unknown> = {};
    try {
      const parsed = JSON.parse(input.config_data_json || "{}");
      if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
        return { success: false, error: "config_data must be a JSON object" };
      }
      configData = parsed;
    } catch {
      return { success: false, error: "Invalid config_data JSON" };
    }
    const heightPct = Math.min(
      95,
      Math.max(40, Math.floor(Number(input.webview_height_percent) || 70)),
    );
    const { error } = await supabaseAdmin
      .from("game_configs")
      .update({
        name: input.name.trim(),
        is_active: input.is_active,
        maintenance_mode: input.maintenance_mode,
        maintenance_message:
          input.maintenance_message.trim() ||
          "This game is under maintenance. Please try again later.",
        min_bet: Math.max(0, Math.floor(input.min_bet || 0)),
        max_bet: Math.max(0, Math.floor(input.max_bet || 0)),
        betting_duration: secondsToInterval(input.betting_duration_sec),
        spinning_duration: secondsToInterval(input.spinning_duration_sec),
        result_duration: secondsToInterval(input.result_duration_sec),
        icon_url: input.icon_url?.trim() || null,
        game_url: input.game_url?.trim() || null,
        sort_order: Math.floor(input.sort_order || 0),
        webview_height_percent: heightPct,
        config_data: configData,
        category_id: input.category_id?.trim() || null,
      })
      .eq("id", input.id);
    if (error) return { success: false, error: error.message };
    revalidatePath("/settings/game-control");
    return { success: true };
  } catch (e: any) {
    return { success: false, error: e?.message || "Save failed" };
  }
}
export async function toggleGameActive(id: string, isActive: boolean) {
  const { error } = await supabaseAdmin
    .from("game_configs")
    .update({ is_active: isActive })
    .eq("id", id);
  if (error) return { success: false, error: error.message };
  revalidatePath("/settings/game-control");
  return { success: true };
}
export async function toggleGameMaintenance(id: string, maintenanceMode: boolean) {
  const { error } = await supabaseAdmin
    .from("game_configs")
    .update({ maintenance_mode: maintenanceMode })
    .eq("id", id);
  if (error) return { success: false, error: error.message };
  revalidatePath("/settings/game-control");
  return { success: true };
}
export async function uploadGameIcon(formData: FormData) {
  try {
    const file = formData.get("file") as File;
    if (!file) throw new Error("No file provided");
    const ext = file.name.includes(".")
      ? file.name
          .split(".")
          .pop()
          ?.toLowerCase()
          ?.replace(/[^a-z0-9]/g, "") || "png"
      : "png";
    const fileName = `admin/${Date.now()}-${randomUUID().slice(0, 8)}.${ext}`;
    const buffer = Buffer.from(await file.arrayBuffer());
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "game-icons",
      objectPath: fileName,
      body: buffer,
      contentType: file.type || "image/png",
    });
    return { success: true, url: publicUrl };
  } catch (e: any) {
    return { success: false, error: e?.message || "Upload failed" };
  }
}
export type VisibilityScope = "category" | "game_config" | "tulasi_game";
export type VisibilityMode = "hide_from" | "show_only";
function assertScope(scope: string): asserts scope is VisibilityScope {
  if (scope !== "category" && scope !== "game_config" && scope !== "tulasi_game") {
    throw new Error("Invalid scope");
  }
}
function revalidateAudience() {
  revalidatePath("/settings/game-control");
  revalidatePath("/settings/tulasi-games");
  revalidatePath("/settings/baishun-games");
}
export async function searchUsersForGameAudience(query: string) {
  try {
    const trimmed = query.trim();
    if (!trimmed) {
      return { success: false as const, error: "Enter username or short ID" };
    }
    let dbQuery = supabaseAdmin.from("users").select("id, username, short_id, avatar_url").limit(8);
    if (/^\d+$/.test(trimmed)) {
      dbQuery = dbQuery.eq("short_id", parseInt(trimmed, 10));
    } else {
      dbQuery = dbQuery.ilike("username", `%${trimmed}%`);
    }
    const { data, error } = await dbQuery;
    if (error) throw error;
    return { success: true as const, users: data || [] };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function getGameVisibility(scope: VisibilityScope, targetId: string) {
  try {
    assertScope(scope);
    const tid = String(targetId || "").trim();
    if (!tid) return { success: false as const, error: "Missing target" };
    const { data, error } = await supabaseAdmin
      .from("room_game_visibility")
      .select("mode, user_id, users:user_id ( id, username, short_id, avatar_url )")
      .eq("scope", scope)
      .eq("target_id", tid);
    if (error) throw error;
    const rows = data ?? [];
    const mode = (rows[0]?.mode as VisibilityMode | undefined) ?? null;
    const users = rows
      .map((r: any) => {
        const u = r.users;
        if (!u) return null;
        return {
          id: String(u.id),
          username: u.username as string | null,
          short_id: u.short_id as number | null,
          avatar_url: u.avatar_url as string | null,
        };
      })
      .filter(Boolean) as {
      id: string;
      username: string | null;
      short_id: number | null;
      avatar_url: string | null;
    }[];
    return { success: true as const, mode, users };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function setGameVisibilityMode(
  scope: VisibilityScope,
  targetId: string,
  mode: VisibilityMode,
) {
  try {
    assertScope(scope);
    if (mode !== "hide_from" && mode !== "show_only") {
      throw new Error("Invalid mode");
    }
    const tid = String(targetId || "").trim();
    if (!tid) throw new Error("Missing target");
    const { error } = await supabaseAdmin
      .from("room_game_visibility")
      .update({ mode })
      .eq("scope", scope)
      .eq("target_id", tid);
    if (error) throw error;
    revalidateAudience();
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function addGameVisibilityUser(data: {
  scope: VisibilityScope;
  targetId: string;
  userId: string;
  mode: VisibilityMode;
}) {
  try {
    assertScope(data.scope);
    const tid = String(data.targetId || "").trim();
    const uid = String(data.userId || "").trim();
    if (!tid || !uid) throw new Error("Missing target or user");
    if (data.mode !== "hide_from" && data.mode !== "show_only") {
      throw new Error("Invalid mode");
    }
    const { error: syncError } = await supabaseAdmin
      .from("room_game_visibility")
      .update({ mode: data.mode })
      .eq("scope", data.scope)
      .eq("target_id", tid);
    if (syncError) throw syncError;
    const { error } = await supabaseAdmin.from("room_game_visibility").upsert(
      {
        scope: data.scope,
        target_id: tid,
        user_id: uid,
        mode: data.mode,
      },
      { onConflict: "scope,target_id,user_id" },
    );
    if (error) throw error;
    revalidateAudience();
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function removeGameVisibilityUser(data: {
  scope: VisibilityScope;
  targetId: string;
  userId: string;
}) {
  try {
    assertScope(data.scope);
    const tid = String(data.targetId || "").trim();
    const uid = String(data.userId || "").trim();
    if (!tid || !uid) throw new Error("Missing target or user");
    const { error } = await supabaseAdmin
      .from("room_game_visibility")
      .delete()
      .eq("scope", data.scope)
      .eq("target_id", tid)
      .eq("user_id", uid);
    if (error) throw error;
    revalidateAudience();
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function clearGameVisibility(scope: VisibilityScope, targetId: string) {
  try {
    assertScope(scope);
    const tid = String(targetId || "").trim();
    if (!tid) throw new Error("Missing target");
    const { error } = await supabaseAdmin
      .from("room_game_visibility")
      .delete()
      .eq("scope", scope)
      .eq("target_id", tid);
    if (error) throw error;
    revalidateAudience();
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
