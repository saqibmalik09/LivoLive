"use server";
import { revalidatePath } from "next/cache";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { supabaseAdmin } from "@/lib/supabase";
export type AdminRoomRow = {
  id: string;
  shortId: string | null;
  title: string;
  imageUrl: string | null;
  backgroundUrl: string | null;
  hostUsername: string | null;
  hostShortId: string | null;
  onlineUsersCount: number;
  isActive: boolean;
  isPinned: boolean;
  pinOrder: number;
};
function mapRoom(row: any): AdminRoomRow {
  const host = Array.isArray(row.users) ? row.users[0] : row.users;
  return {
    id: String(row.id),
    shortId: row.short_id != null ? String(row.short_id) : null,
    title: String(row.title ?? "Room"),
    imageUrl: row.image_url ? String(row.image_url) : null,
    backgroundUrl: row.background_url ? String(row.background_url) : null,
    hostUsername: host?.username ? String(host.username) : null,
    hostShortId: host?.short_id != null ? String(host.short_id) : null,
    onlineUsersCount: Number(row.online_users_count ?? 0),
    isActive: row.is_active !== false,
    isPinned: row.is_pinned === true,
    pinOrder: Number(row.pin_order ?? 0),
  };
}
const ROOM_SELECT =
  "id, short_id, title, image_url, background_url, online_users_count, is_active, is_pinned, pin_order, users:host_id(username, short_id)";
function sortAdminRooms(rows: AdminRoomRow[]): AdminRoomRow[] {
  return [...rows].sort((a, b) => {
    if (a.isPinned !== b.isPinned) return a.isPinned ? -1 : 1;
    if (a.isPinned && b.isPinned && a.pinOrder !== b.pinOrder) {
      return a.pinOrder - b.pinOrder;
    }
    return b.onlineUsersCount - a.onlineUsersCount;
  });
}
export async function listAdminRooms(limit = 50): Promise<AdminRoomRow[]> {
  const { data, error } = await supabaseAdmin
    .from("rooms")
    .select(ROOM_SELECT)
    .order("is_pinned", { ascending: false })
    .order("pin_order", { ascending: false })
    .order("online_users_count", { ascending: false })
    .limit(limit);
  if (error) throw error;
  return sortAdminRooms((data ?? []).map(mapRoom));
}
export async function searchAdminRooms(query: string): Promise<AdminRoomRow[]> {
  const q = query.trim();
  if (!q) return listAdminRooms(50);
  if (/^\d+$/.test(q)) {
    const { data, error } = await supabaseAdmin
      .from("rooms")
      .select(ROOM_SELECT)
      .eq("short_id", Number(q))
      .limit(50)
      .order("is_pinned", { ascending: false })
      .order("online_users_count", { ascending: false });
    if (error) throw error;
    return sortAdminRooms((data ?? []).map(mapRoom));
  }
  let builder = supabaseAdmin.from("rooms").select(ROOM_SELECT).limit(50);
  if (/^[0-9a-f-]{8,}$/i.test(q)) {
    builder = builder.or(`id.eq.${q},title.ilike.%${q}%`);
  } else {
    builder = builder.ilike("title", `%${q}%`);
  }
  const { data, error } = await builder
    .order("is_pinned", { ascending: false })
    .order("online_users_count", { ascending: false });
  if (error) throw error;
  return sortAdminRooms((data ?? []).map(mapRoom));
}
export async function uploadRoomBannerImage(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected");
    }
    const originalName = fileEntry instanceof File && fileEntry.name ? fileEntry.name : "room.png";
    const fileType = fileEntry instanceof File ? fileEntry.type : "";
    const ext = originalName.split(".").pop()?.toLowerCase() || "png";
    const contentType = fileType || `image/${ext === "jpg" ? "jpeg" : ext}`;
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const safeBase = originalName
      .replace(/\s+/g, "_")
      .replace(/\.[^.]+$/, "")
      .slice(0, 40);
    const fileName = `rooms/banners/${Date.now()}-${safeBase}.${ext}`;
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType: contentType,
    });
    return { success: true as const, url: publicUrl };
  } catch (error: any) {
    console.error("uploadRoomBannerImage:", error);
    return { success: false as const, error: error.message as string };
  }
}
export async function updateRoomBanner(roomId: string, imageUrl: string | null) {
  try {
    if (!roomId) throw new Error("Room ID required");
    const { error } = await supabaseAdmin
      .from("rooms")
      .update({
        image_url: imageUrl?.trim() || null,
      })
      .eq("id", roomId);
    if (error) throw error;
    revalidatePath("/settings/rooms");
    return { success: true as const };
  } catch (error: any) {
    console.error("updateRoomBanner:", error);
    return { success: false as const, error: error.message as string };
  }
}
export async function updateRoomLiveBackground(roomId: string, backgroundUrl: string | null) {
  try {
    if (!roomId) throw new Error("Room ID required");
    const { error } = await supabaseAdmin
      .from("rooms")
      .update({
        background_url: backgroundUrl?.trim() || null,
      })
      .eq("id", roomId);
    if (error) throw error;
    revalidatePath("/settings/rooms");
    return { success: true as const };
  } catch (error: any) {
    console.error("updateRoomLiveBackground:", error);
    return { success: false as const, error: error.message as string };
  }
}
export async function setRoomPinSlot(roomId: string, slot: number) {
  try {
    if (!roomId) throw new Error("Room ID required");
    const pinSlot = Math.floor(Number(slot));
    if (![0, 1, 2, 3].includes(pinSlot)) {
      throw new Error("Pin slot must be 1, 2, 3, or 0 to unpin");
    }

    if (pinSlot === 0) {
      const { error } = await supabaseAdmin
        .from("rooms")
        .update({ is_pinned: false, pin_order: 0 })
        .eq("id", roomId);
      if (error) throw error;
    } else {
      // Free the target slot if another room holds it.
      const { error: clearError } = await supabaseAdmin
        .from("rooms")
        .update({ is_pinned: false, pin_order: 0 })
        .eq("is_pinned", true)
        .eq("pin_order", pinSlot)
        .neq("id", roomId);
      if (clearError) throw clearError;

      const { error } = await supabaseAdmin
        .from("rooms")
        .update({ is_pinned: true, pin_order: pinSlot })
        .eq("id", roomId);
      if (error) throw error;
    }

    revalidatePath("/settings/rooms");
    // The caller needs the resulting position to update its own list without
    // refetching.
    return { success: true as const, pinOrder: pinSlot };
  } catch (error: any) {
    console.error("setRoomPinSlot:", error);
    return { success: false as const, error: error.message as string };
  }
}

/**
 * Feature a room on the home screen, or stop featuring it.
 *
 * Exactly one room is featured at a time, so pinning replaces whatever was
 * featured before. This also clears rooms still sitting on positions 2 and 3
 * from the previous three-slot layout, which the app no longer draws.
 */
export async function setRoomPinned(roomId: string, pinned: boolean) {
  if (!pinned) return setRoomPinSlot(roomId, 0);
  try {
    const { error } = await supabaseAdmin
      .from("rooms")
      .update({ is_pinned: false, pin_order: 0 })
      .eq("is_pinned", true)
      .neq("id", roomId);
    if (error) throw error;
  } catch (error: any) {
    console.error("setRoomPinned clear:", error);
    return { success: false as const, error: error.message as string };
  }
  return setRoomPinSlot(roomId, 1);
}
