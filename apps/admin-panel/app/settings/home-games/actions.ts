"use server";
import { supabaseAdmin } from "@/lib/supabase";
import {
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { revalidatePath } from "next/cache";
export type HomeGamesRowItem = {
  id: string;
  game_slug: string;
  title: string;
  image_url: string;
  sort_order: number;
  is_active: boolean;
};
export type HomeGamesRowGameOption = {
  slug: string;
  name: string;
  icon_url?: string | null;
  is_active?: boolean;
  sort_order?: number;
};
export async function listHomeGamesRowItems(): Promise<HomeGamesRowItem[]> {
  const { data, error } = await supabaseAdmin
    .from("home_games_row_items")
    .select("id, game_slug, title, image_url, sort_order, is_active")
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []) as HomeGamesRowItem[];
}
export async function listGamesForHomeRow(): Promise<HomeGamesRowGameOption[]> {
  const { data, error } = await supabaseAdmin
    .from("game_configs")
    .select("slug, name, icon_url, is_active, sort_order")
    .order("sort_order", { ascending: true });
  if (error) return [];
  return (data ?? []) as HomeGamesRowGameOption[];
}
export async function upsertHomeGamesRowItem(input: {
  id?: string;
  game_slug: string;
  title?: string;
  image_url?: string;
  sort_order?: number;
  is_active?: boolean;
}) {
  try {
    const slug = input.game_slug?.trim();
    if (!slug) throw new Error("game_slug is required");
    const { data: game } = await supabaseAdmin
      .from("game_configs")
      .select("slug, name, icon_url")
      .eq("slug", slug)
      .maybeSingle();
    const payload = {
      game_slug: slug,
      title: (input.title ?? "").trim() || game?.name || slug,
      image_url: (input.image_url ?? "").trim() || game?.icon_url || "",
      sort_order: input.sort_order ?? 0,
      is_active: input.is_active ?? true,
      updated_at: new Date().toISOString(),
    };
    if (input.id) {
      const { error } = await supabaseAdmin
        .from("home_games_row_items")
        .update(payload)
        .eq("id", input.id);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin
        .from("home_games_row_items")
        .upsert(payload, { onConflict: "game_slug" });
      if (error) throw error;
    }
    revalidatePath("/settings/home-games");
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Save failed",
    };
  }
}
export async function setHomeGamesRowOrder(orderedIds: string[]) {
  try {
    for (let i = 0; i < orderedIds.length; i++) {
      const { error } = await supabaseAdmin
        .from("home_games_row_items")
        .update({ sort_order: i, updated_at: new Date().toISOString() })
        .eq("id", orderedIds[i]);
      if (error) throw error;
    }
    revalidatePath("/settings/home-games");
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Reorder failed",
    };
  }
}
export async function deleteHomeGamesRowItem(id: string) {
  try {
    const { error } = await supabaseAdmin.from("home_games_row_items").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/home-games");
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Delete failed",
    };
  }
}
export async function uploadHomeGamesRowImage(formData: FormData) {
  try {
    const file = formData.get("file");
    if (!(file instanceof File)) throw new Error("No file");
    const ext = resolveRankingAssetExtension(file.name, file.type);
    const contentType = resolveRankingAssetContentType(file, file.name);
    const fileName = `home-games/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
    const buffer = Buffer.from(await file.arrayBuffer());
    const { error } = await supabaseAdmin.storage
      .from("app_assets")
      .upload(fileName, buffer, { contentType, upsert: true });
    if (error) throw error;
    const { data } = supabaseAdmin.storage.from("app_assets").getPublicUrl(fileName);
    return { success: true as const, url: data.publicUrl };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Upload failed",
    };
  }
}
