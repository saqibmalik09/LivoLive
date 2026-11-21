"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { revalidatePath } from "next/cache";
export type HotCardSlot = "carousel_1" | "carousel_2" | "carousel_3" | "party_card" | "music_card";
export type HotCardMediaType = "image" | "svga" | "video";
function resolveContentType(file: Blob, fileName: string): string {
  if (file.type) return file.type;
  const ext = fileName.split(".").pop()?.toLowerCase();
  switch (ext) {
    case "png":
      return "image/png";
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "webp":
      return "image/webp";
    case "gif":
      return "image/gif";
    case "svga":
      return "application/octet-stream";
    case "mp4":
      return "video/mp4";
    case "webm":
      return "video/webm";
    default:
      return "application/octet-stream";
  }
}
function urlColumn(slot: HotCardSlot): string {
  return `${slot}_url`;
}
function mediaColumn(slot: HotCardSlot): string {
  return `${slot}_media_type`;
}
export async function resolveRoomRef(raw: string): Promise<{
  id: string | null;
  shortId: string | null;
  error?: string;
}> {
  const q = raw.trim();
  if (!q) return { id: null, shortId: null };
  const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (uuidRe.test(q)) {
    const { data, error } = await supabaseAdmin
      .from("rooms")
      .select("id, short_id")
      .eq("id", q)
      .maybeSingle();
    if (error) return { id: null, shortId: null, error: error.message };
    if (!data) return { id: null, shortId: null, error: "Room not found" };
    return {
      id: data.id as string,
      shortId: data.short_id != null ? String(data.short_id) : null,
    };
  }
  const { data, error } = await supabaseAdmin
    .from("rooms")
    .select("id, short_id")
    .eq("short_id", q)
    .maybeSingle();
  if (error) return { id: null, shortId: null, error: error.message };
  if (!data) return { id: null, shortId: null, error: `No room with ID ${q}` };
  return {
    id: data.id as string,
    shortId: data.short_id != null ? String(data.short_id) : null,
  };
}
export async function updateHotCardsConfig(data: Record<string, unknown>) {
  try {
    const row = {
      ...data,
      updated_at: new Date().toISOString(),
    };
    const { error } = await supabaseAdmin
      .from("home_hot_cards_config")
      .upsert({ id: 1, ...row }, { onConflict: "id" });
    if (error) throw error;
    revalidatePath("/settings/hot-cards");
    return { success: true };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false, error: message };
  }
}
export async function saveHotCardRoomTargets(formData: FormData) {
  try {
    const partyRaw = String(formData.get("party_room_ref") ?? "");
    const musicRaw = String(formData.get("music_room_ref") ?? "");
    const party = await resolveRoomRef(partyRaw);
    if (party.error) return { success: false, error: `Party Star: ${party.error}` };
    const music = await resolveRoomRef(musicRaw);
    if (music.error) return { success: false, error: `Music: ${music.error}` };
    const { error } = await supabaseAdmin.from("home_hot_cards_config").upsert(
      {
        id: 1,
        party_card_room_id: party.id,
        music_card_room_id: music.id,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "id" },
    );
    if (error) {
      if (error.message.includes("party_card_room_id")) {
        return {
          success: false,
          error:
            "Database missing room columns. Run migration 20260722190000_hot_cards_room_targets.sql",
        };
      }
      throw error;
    }
    revalidatePath("/settings/hot-cards");
    return {
      success: true,
      partyShortId: party.shortId,
      musicShortId: music.shortId,
    };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false, error: message };
  }
}
export async function uploadHotCardMedia(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    const slot = (formData.get("slot") as string) || "carousel_1";
    const mediaType = (formData.get("mediaType") as HotCardMediaType) || "image";
    const validSlots: HotCardSlot[] = [
      "carousel_1",
      "carousel_2",
      "carousel_3",
      "party_card",
      "music_card",
    ];
    if (!validSlots.includes(slot as HotCardSlot)) {
      throw new Error("Invalid slot");
    }
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected or file is empty");
    }
    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : `${slot}.png`;
    const ext = originalName.includes(".")
      ? originalName.split(".").pop()?.toLowerCase() || "png"
      : "png";
    const safeExt = ext.replace(/[^a-z0-9]/gi, "") || "png";
    const fileName = `hot-cards/${slot}-${Date.now()}.${safeExt}`;
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const contentType = resolveContentType(fileEntry, originalName);
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType,
    });
    const { error: dbError } = await supabaseAdmin.from("home_hot_cards_config").upsert(
      {
        id: 1,
        [urlColumn(slot as HotCardSlot)]: publicUrl,
        [mediaColumn(slot as HotCardSlot)]: mediaType,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "id" },
    );
    if (dbError) {
      throw new Error(
        `Upload OK but database save failed: ${dbError.message}. Run migration 20250630160000_home_hot_cards_config.sql.`,
      );
    }
    revalidatePath("/settings/hot-cards");
    return { success: true, url: publicUrl };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[uploadHotCardMedia]", message);
    return { success: false, error: message };
  }
}
