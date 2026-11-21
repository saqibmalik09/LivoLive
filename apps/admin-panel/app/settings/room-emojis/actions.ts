"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import {
  isSvgaRankingAsset,
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { revalidatePath } from "next/cache";
export type RoomMicEmojiRow = {
  id: string;
  name: string;
  image_url: string;
  svga_url?: string | null;
  is_premium: boolean;
  is_active: boolean;
  sort_order: number;
  created_at?: string;
  updated_at?: string;
};
export async function listRoomMicEmojisAdmin() {
  const { data, error } = await supabaseAdmin
    .from("room_mic_emojis")
    .select("*")
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });
  if (error) return { success: false as const, error: error.message, emojis: [] };
  return { success: true as const, emojis: (data ?? []) as RoomMicEmojiRow[] };
}
export async function getRoomMicEmoji(id: string) {
  const { data, error } = await supabaseAdmin
    .from("room_mic_emojis")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (error) return { success: false as const, error: error.message, emoji: null };
  return { success: true as const, emoji: data as RoomMicEmojiRow | null };
}
export async function upsertRoomMicEmoji(data: {
  id?: string;
  name: string;
  image_url: string;
  svga_url?: string | null;
  is_premium?: boolean;
  is_active?: boolean;
  sort_order?: number;
}) {
  try {
    const row = {
      name: data.name.trim(),
      image_url: data.image_url.trim(),
      svga_url: data.svga_url?.trim() || null,
      is_premium: data.is_premium ?? false,
      is_active: data.is_active ?? true,
      sort_order: data.sort_order ?? 0,
    };
    if (!row.name) throw new Error("Name is required");
    if (!row.image_url) throw new Error("Image is required");
    let res;
    if (data.id) {
      res = await supabaseAdmin.from("room_mic_emojis").update(row).eq("id", data.id);
    } else {
      res = await supabaseAdmin.from("room_mic_emojis").insert(row);
    }
    if (res.error) throw res.error;
    revalidatePath("/settings/room-emojis");
    if (data.id) revalidatePath(`/settings/room-emojis/${data.id}`);
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function deleteRoomMicEmoji(id: string) {
  try {
    const { error } = await supabaseAdmin.from("room_mic_emojis").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/room-emojis");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function uploadRoomMicEmojiAsset(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    const kind = (formData.get("kind") as string) || "image";
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected");
    }
    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : `${kind}.png`;
    const fileType = fileEntry instanceof File ? fileEntry.type : "";
    const isSvga = kind === "svga" || isSvgaRankingAsset(originalName, fileType);
    const ext = isSvga ? "svga" : resolveRankingAssetExtension(originalName, fileType);
    const contentType = resolveRankingAssetContentType(fileEntry, originalName);
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const fileName = `room-emojis/${Date.now()}-${originalName.replace(/\s+/g, "_").replace(/\.[^.]+$/, "")}.${ext}`;
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType,
    });
    return { success: true as const, url: publicUrl };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
