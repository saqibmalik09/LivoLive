"use server";
import { randomUUID } from "crypto";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
function safeStorageObjectKey(folder: string, originalName: string, fallbackExt: string) {
  const rawExt = originalName.includes(".")
    ? originalName.split(".").pop()?.toLowerCase()
    : fallbackExt;
  const ext = (rawExt || fallbackExt).replace(/[^a-z0-9]/gi, "") || fallbackExt;
  return `${folder}${Date.now()}-${randomUUID().slice(0, 8)}.${ext}`;
}
export async function upsertRoomDecoration(data: {
  id?: string;
  name: string;
  image_url?: string;
  svga_url?: string;
  is_premium: boolean;
  price: number;
  is_active: boolean;
  sort_order: number;
}) {
  try {
    const imageUrl = data.image_url?.trim() || null;
    const svgaUrl = data.svga_url?.trim() || null;
    if (!imageUrl && !svgaUrl) {
      return {
        success: false,
        error: "Upload an image or an SVGA file",
      };
    }
    const row = {
      name: data.name,
      image_url: imageUrl,
      svga_url: svgaUrl,
      is_premium: data.is_premium,
      price: data.is_premium ? Math.max(0, data.price) : 0,
      is_active: data.is_active,
      sort_order: data.sort_order,
    };
    let res;
    if (data.id) {
      res = await supabaseAdmin.from("room_decorations").update(row).eq("id", data.id);
    } else {
      res = await supabaseAdmin.from("room_decorations").insert(row);
    }
    if (res.error) {
      const pgError = res.error as {
        message?: string;
        details?: string;
        hint?: string;
      };
      return {
        success: false,
        error: pgError.message || pgError.details || "Database save failed",
      };
    }
    revalidatePath("/settings/room-decorations");
    if (data.id) revalidatePath(`/settings/room-decorations/${data.id}`);
    return { success: true };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false, error: message };
  }
}
export async function deleteRoomDecoration(id: string) {
  try {
    const { error } = await supabaseAdmin.from("room_decorations").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/room-decorations");
    return { success: true };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false, error: message };
  }
}
export async function uploadRoomDecorationImage(formData: FormData) {
  return uploadRoomDecorationAsset(formData, "image");
}
export async function uploadRoomDecorationSvga(formData: FormData) {
  return uploadRoomDecorationAsset(formData, "svga");
}
async function uploadRoomDecorationAsset(formData: FormData, kind: "image" | "svga") {
  try {
    const file = formData.get("file") as File;
    if (!file) throw new Error("No file provided");
    const isSvga = kind === "svga" || file.name.toLowerCase().endsWith(".svga");
    const folder = isSvga ? "catalog/svga/" : "catalog/";
    const fileName = safeStorageObjectKey(folder, file.name, isSvga ? "svga" : "jpg");
    const buffer = Buffer.from(await file.arrayBuffer());
    const contentType = isSvga
      ? "application/octet-stream"
      : file.type || "application/octet-stream";
    const { error } = await supabaseAdmin.storage
      .from("room_backgrounds")
      .upload(fileName, buffer, {
        contentType,
        upsert: true,
      });
    if (error) throw error;
    const {
      data: { publicUrl },
    } = supabaseAdmin.storage.from("room_backgrounds").getPublicUrl(fileName);
    return { success: true, url: publicUrl };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false, error: message };
  }
}
export async function updateCustomBackgroundPrice(coins: number) {
  try {
    const value = String(Math.max(0, Math.floor(coins)));
    const { error } = await supabaseAdmin.from("system_settings").upsert(
      {
        key: "room_custom_background_price",
        value,
        description:
          "Coins charged when a host uploads and applies their own room background (photo or SVGA) in the app",
        updated_at: new Date().toISOString(),
      },
      { onConflict: "key" },
    );
    if (error) throw error;
    revalidatePath("/settings/room-decorations");
    return { success: true };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false, error: message };
  }
}
