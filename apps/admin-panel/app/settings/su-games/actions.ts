"use server";
import { supabaseAdmin } from "@/lib/supabase";
import {
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { revalidatePath } from "next/cache";
export type SuGameCategory = {
  id: string;
  name: string;
  sort_order: number;
  is_active: boolean;
};
export type SuGameItem = {
  id: string;
  category_id: string;
  kind: "h5" | "rupee";
  game_slug: string | null;
  title: string;
  image_url: string;
  sort_order: number;
  is_active: boolean;
};
export type SuGameOption = {
  slug: string;
  name: string;
  icon_url?: string | null;
  is_active?: boolean;
  sort_order?: number;
};
export async function listSuGameCategories(): Promise<SuGameCategory[]> {
  const { data, error } = await supabaseAdmin
    .from("su_game_categories")
    .select("id, name, sort_order, is_active")
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []) as SuGameCategory[];
}
export async function listSuGameItems(): Promise<SuGameItem[]> {
  const { data, error } = await supabaseAdmin
    .from("su_game_items")
    .select("id, category_id, kind, game_slug, title, image_url, sort_order, is_active")
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => ({
    id: String(row.id),
    category_id: String(row.category_id),
    kind: row.kind === "rupee" ? "rupee" : "h5",
    game_slug: row.game_slug ? String(row.game_slug) : null,
    title: String(row.title ?? ""),
    image_url: String(row.image_url ?? ""),
    sort_order: Number(row.sort_order ?? 0),
    is_active: Boolean(row.is_active),
  }));
}
export async function listGamesForSuHub(): Promise<SuGameOption[]> {
  const { data, error } = await supabaseAdmin
    .from("game_configs")
    .select("slug, name, icon_url, is_active, sort_order")
    .order("sort_order", { ascending: true });
  if (error) return [];
  return (data ?? []) as SuGameOption[];
}
export async function upsertSuGameCategory(input: {
  id?: string;
  name: string;
  sort_order?: number;
  is_active?: boolean;
}) {
  try {
    const name = input.name?.trim();
    if (!name) throw new Error("Category name is required");
    const payload = {
      name,
      sort_order: input.sort_order ?? 0,
      is_active: input.is_active ?? true,
      updated_at: new Date().toISOString(),
    };
    if (input.id) {
      const { error } = await supabaseAdmin
        .from("su_game_categories")
        .update(payload)
        .eq("id", input.id);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin.from("su_game_categories").insert(payload);
      if (error) throw error;
    }
    revalidatePath("/settings/su-games");
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Save failed",
    };
  }
}
export async function setSuGameCategoryOrder(orderedIds: string[]) {
  try {
    for (let i = 0; i < orderedIds.length; i++) {
      const { error } = await supabaseAdmin
        .from("su_game_categories")
        .update({ sort_order: i, updated_at: new Date().toISOString() })
        .eq("id", orderedIds[i]);
      if (error) throw error;
    }
    revalidatePath("/settings/su-games");
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Reorder failed",
    };
  }
}
export async function deleteSuGameCategory(id: string) {
  try {
    const { error } = await supabaseAdmin.from("su_game_categories").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/su-games");
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Delete failed",
    };
  }
}
export async function upsertSuGameItem(input: {
  id?: string;
  category_id: string;
  kind: "h5" | "rupee";
  game_slug?: string | null;
  title?: string;
  image_url?: string;
  sort_order?: number;
  is_active?: boolean;
}) {
  try {
    if (!input.category_id) throw new Error("category_id is required");
    const kind = input.kind === "rupee" ? "rupee" : "h5";
    let slug = kind === "h5" ? (input.game_slug ?? "").trim() : null;
    if (kind === "h5" && !slug) throw new Error("Select a game");
    let title = (input.title ?? "").trim();
    let imageUrl = (input.image_url ?? "").trim();
    if (kind === "h5" && slug) {
      const { data: game } = await supabaseAdmin
        .from("game_configs")
        .select("slug, name, icon_url")
        .eq("slug", slug)
        .maybeSingle();
      title = title || game?.name || slug;
      imageUrl = imageUrl || game?.icon_url || "";
    } else {
      title = title || "Lucky Offer";
    }
    const payload = {
      category_id: input.category_id,
      kind,
      game_slug: slug,
      title,
      image_url: imageUrl,
      sort_order: input.sort_order ?? 0,
      is_active: input.is_active ?? true,
      updated_at: new Date().toISOString(),
    };
    if (input.id) {
      const { error } = await supabaseAdmin
        .from("su_game_items")
        .update(payload)
        .eq("id", input.id);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin.from("su_game_items").insert(payload);
      if (error) throw error;
    }
    revalidatePath("/settings/su-games");
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Save failed",
    };
  }
}
export async function setSuGameItemOrder(orderedIds: string[]) {
  try {
    for (let i = 0; i < orderedIds.length; i++) {
      const { error } = await supabaseAdmin
        .from("su_game_items")
        .update({ sort_order: i, updated_at: new Date().toISOString() })
        .eq("id", orderedIds[i]);
      if (error) throw error;
    }
    revalidatePath("/settings/su-games");
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Reorder failed",
    };
  }
}
export async function deleteSuGameItem(id: string) {
  try {
    const { error } = await supabaseAdmin.from("su_game_items").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/su-games");
    return { success: true as const };
  } catch (e: unknown) {
    return {
      success: false as const,
      error: e instanceof Error ? e.message : "Delete failed",
    };
  }
}
export async function uploadSuGameImage(formData: FormData) {
  try {
    const file = formData.get("file");
    if (!(file instanceof File)) throw new Error("No file");
    const ext = resolveRankingAssetExtension(file.name, file.type);
    const contentType = resolveRankingAssetContentType(file, file.name);
    const fileName = `su-games/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
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
