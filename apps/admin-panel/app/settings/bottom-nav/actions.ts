"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
const VALID_KEYS = ["home", "party", "game", "message", "my"] as const;
export type BottomNavKey = (typeof VALID_KEYS)[number];
type IconVariant = "icon" | "active" | "focus";
function columnForVariant(variant: IconVariant): string {
  switch (variant) {
    case "active":
      return "active_icon_url";
    case "focus":
      return "focus_overlay_url";
    default:
      return "icon_url";
  }
}
function resolveContentType(file: Blob, fileName: string): string {
  if (file.type && file.type.startsWith("image/")) return file.type;
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
    default:
      return "application/octet-stream";
  }
}
export async function updateBottomNavItem(data: {
  nav_key: BottomNavKey;
  label: string;
  icon_url?: string;
  active_icon_url?: string | null;
  focus_overlay_url?: string | null;
  is_active: boolean;
}) {
  try {
    if (!VALID_KEYS.includes(data.nav_key)) {
      return { success: false, error: "Invalid nav key" };
    }
    const row = {
      label: data.label.trim(),
      icon_url: data.icon_url?.trim() ?? "",
      active_icon_url: data.active_icon_url?.trim() || null,
      focus_overlay_url: data.focus_overlay_url?.trim() || null,
      is_active: data.is_active,
      updated_at: new Date().toISOString(),
    };
    const { error } = await supabaseAdmin
      .from("bottom_nav_items")
      .update(row)
      .eq("nav_key", data.nav_key);
    if (error) throw error;
    revalidatePath("/settings/bottom-nav");
    return { success: true };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false, error: message };
  }
}
export async function uploadBottomNavIcon(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    const navKey = formData.get("nav_key") as string;
    const variant = ((formData.get("variant") as string) || "icon") as IconVariant;
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected or file is empty");
    }
    if (!VALID_KEYS.includes(navKey as BottomNavKey)) {
      throw new Error("Invalid nav key");
    }
    if (!["icon", "active", "focus"].includes(variant)) {
      throw new Error("Invalid variant");
    }
    const originalName = fileEntry instanceof File && fileEntry.name ? fileEntry.name : "icon.png";
    const ext = originalName.includes(".")
      ? originalName.split(".").pop()?.toLowerCase() || "png"
      : "png";
    const safeExt = ext.replace(/[^a-z0-9]/gi, "") || "png";
    const fileName = `bottom-nav/${navKey}-${variant}-${Date.now()}.${safeExt}`;
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const contentType = resolveContentType(fileEntry, originalName);
    let uploadError = (
      await supabaseAdmin.storage.from("app_assets").upload(fileName, buffer, {
        contentType,
        upsert: true,
      })
    ).error;
    if (uploadError && contentType !== "application/octet-stream") {
      uploadError = (
        await supabaseAdmin.storage.from("app_assets").upload(fileName, buffer, {
          contentType: "application/octet-stream",
          upsert: true,
        })
      ).error;
    }
    if (uploadError) throw uploadError;
    const {
      data: { publicUrl },
    } = supabaseAdmin.storage.from("app_assets").getPublicUrl(fileName);
    const column = columnForVariant(variant);
    const { error: dbError } = await supabaseAdmin
      .from("bottom_nav_items")
      .update({
        [column]: publicUrl,
        updated_at: new Date().toISOString(),
      })
      .eq("nav_key", navKey);
    if (dbError) {
      throw new Error(
        `Upload OK but database save failed: ${dbError.message}. Run migration 20250630120000_bottom_nav_items.sql in Supabase.`,
      );
    }
    revalidatePath("/settings/bottom-nav");
    return { success: true, url: publicUrl };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[uploadBottomNavIcon]", message);
    return { success: false, error: message };
  }
}
