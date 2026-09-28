"use server";
import { revalidatePath } from "next/cache";
import { supabaseAdmin } from "@/lib/supabase";
export type TulasiGameRow = {
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
  tulasi_game_id: string | null;
  is_landscape: boolean;
  category_id: string | null;
};
export type TulasiTxnRow = {
  transaction_id: string;
  user_id: string;
  short_id: number | null;
  type: number;
  coin: number;
  game_coin: number;
  status: string;
  created_at: string;
};
function asConfig(raw: unknown): Record<string, unknown> {
  if (raw && typeof raw === "object" && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  return {};
}
function mapGame(row: Record<string, unknown>): TulasiGameRow {
  const cfg = asConfig(row.config_data);
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
      Math.max(40, Number(row.webview_height_percent ?? 70) || 70),
    ),
    config_data: cfg,
    tulasi_game_id: cfg.tulasi_game_id != null ? String(cfg.tulasi_game_id) : null,
    is_landscape:
      cfg.isLandscape === true ||
      cfg.isLandscape === "true" ||
      cfg.isLandscape === 1 ||
      cfg.isLandscape === "1" ||
      cfg.is_landscape === true ||
      cfg.is_landscape === "true" ||
      cfg.is_landscape === 1 ||
      cfg.is_landscape === "1",
    category_id: row.category_id ? String(row.category_id) : null,
  };
}
export async function listTulasiGames(): Promise<TulasiGameRow[]> {
  const { data, error } = await supabaseAdmin
    .from("game_configs")
    .select("*")
    .order("sort_order", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? [])
    .map((row) => mapGame(row as Record<string, unknown>))
    .filter((g) => g.config_data.provider === "tulasi");
}
export async function updateTulasiGame(input: {
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
    if (cfg.provider !== "tulasi") {
      return { success: false as const, error: "Not a Tulasi game" };
    }
    const nextCfg = {
      ...cfg,
      isLandscape: Boolean(input.is_landscape),
    };
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
    revalidatePath("/settings/tulasi-games");
    revalidatePath("/settings/game-control");
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Save failed",
    };
  }
}
export async function listTulasiTransactions(limit = 50): Promise<TulasiTxnRow[]> {
  const { data, error } = await supabaseAdmin
    .from("tulasi_game_transactions")
    .select("transaction_id, user_id, type, coin, game_coin, status, created_at")
    .order("created_at", { ascending: false })
    .limit(Math.min(100, Math.max(1, limit)));
  if (error) throw new Error(error.message);
  const rows = (data ?? []) as Array<Record<string, unknown>>;
  const userIds = [...new Set(rows.map((r) => String(r.user_id ?? "")).filter(Boolean))];
  const shortByUser = new Map<string, number>();
  if (userIds.length) {
    const { data: users } = await supabaseAdmin
      .from("users")
      .select("id, short_id")
      .in("id", userIds);
    for (const u of users ?? []) {
      if (u.id != null && u.short_id != null) {
        shortByUser.set(String(u.id), Number(u.short_id));
      }
    }
  }
  return rows.map((r) => {
    const uid = String(r.user_id ?? "");
    return {
      transaction_id: String(r.transaction_id ?? ""),
      user_id: uid,
      short_id: shortByUser.get(uid) ?? null,
      type: Number(r.type ?? 0),
      coin: Number(r.coin ?? 0),
      game_coin: Number(r.game_coin ?? 0),
      status: String(r.status ?? ""),
      created_at: String(r.created_at ?? ""),
    };
  });
}
