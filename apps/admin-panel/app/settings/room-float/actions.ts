"use server";
import { supabaseAdmin } from "@/lib/supabase";
import {
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { revalidatePath } from "next/cache";
export type RoomSideFloatRow = {
  id: string;
  kind: "event" | "game";
  title: string;
  image_url: string;
  party_event_id?: string | null;
  game_slug?: string | null;
  sort_order: number;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
};
export async function listRoomSideFloatItemsAdmin() {
  const { data, error } = await supabaseAdmin
    .from("room_side_float_items")
    .select("*")
    .order("kind", { ascending: true })
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });
  if (error) {
    return { success: false as const, error: error.message, items: [] as RoomSideFloatRow[] };
  }
  return { success: true as const, items: (data ?? []) as RoomSideFloatRow[] };
}
export async function listPartyEventsForFloatLink() {
  const { data, error } = await supabaseAdmin
    .from("party_events")
    .select("id, title, banner_url, is_active")
    .order("priority", { ascending: false });
  if (error) return [];
  return data ?? [];
}
export async function listGamesForFloatLink() {
  const { data, error } = await supabaseAdmin
    .from("game_configs")
    .select("slug, name, icon_url, is_active, sort_order")
    .order("sort_order", { ascending: true });
  if (error) return [];
  return data ?? [];
}
export async function upsertRoomSideFloatItem(data: {
  id?: string;
  kind: "event" | "game";
  title: string;
  image_url: string;
  party_event_id?: string | null;
  game_slug?: string | null;
  sort_order?: number;
  is_active?: boolean;
}) {
  try {
    if (!data.image_url?.trim()) {
      throw new Error("Square image is required");
    }
    const payload = {
      kind: data.kind,
      title: data.title?.trim() || (data.kind === "game" ? "Game" : "Event"),
      image_url: data.image_url.trim(),
      party_event_id: data.kind === "event" ? data.party_event_id || null : null,
      game_slug: data.kind === "game" ? data.game_slug || null : null,
      sort_order: data.sort_order ?? 0,
      is_active: data.is_active ?? true,
      updated_at: new Date().toISOString(),
    };
    if (data.id) {
      const { error } = await supabaseAdmin
        .from("room_side_float_items")
        .update(payload)
        .eq("id", data.id);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin.from("room_side_float_items").insert(payload);
      if (error) throw error;
    }
    revalidatePath("/settings/room-float");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function deleteRoomSideFloatItem(id: string) {
  try {
    const { error } = await supabaseAdmin.from("room_side_float_items").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/room-float");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function uploadRoomSideFloatImage(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected");
    }
    const originalName = fileEntry instanceof File && fileEntry.name ? fileEntry.name : "float.png";
    const fileType = fileEntry instanceof File ? fileEntry.type : "";
    const ext = resolveRankingAssetExtension(originalName, fileType);
    const contentType = resolveRankingAssetContentType(fileEntry, originalName);
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const fileName = `room-float/${Date.now()}-${originalName
      .replace(/\s+/g, "_")
      .replace(/\.[^.]+$/, "")}.${ext}`;
    const bucket = supabaseAdmin.storage.from("app_assets");
    const { error: uploadError } = await bucket.upload(fileName, buffer, {
      contentType,
      upsert: true,
    });
    if (uploadError) throw uploadError;
    const {
      data: { publicUrl },
    } = bucket.getPublicUrl(fileName);
    return { success: true as const, url: publicUrl };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
