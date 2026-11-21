"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { revalidatePath } from "next/cache";
type BandVariant = "top" | "bottom";
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
function columnForVariant(variant: BandVariant): string {
  return variant === "top" ? "top_image_url" : "bottom_image_url";
}
export async function updatePartyScreenConfig(data: {
  top_image_url?: string;
  bottom_image_url?: string;
}) {
  try {
    const row = {
      top_image_url: data.top_image_url?.trim() ?? "",
      bottom_image_url: data.bottom_image_url?.trim() ?? "",
      updated_at: new Date().toISOString(),
    };
    const { error } = await supabaseAdmin
      .from("party_screen_config")
      .upsert({ id: 1, ...row }, { onConflict: "id" });
    if (error) throw error;
    revalidatePath("/settings/party-screen");
    return { success: true };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false, error: message };
  }
}
export async function uploadPartyScreenImage(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    const variant = (formData.get("variant") as string) || "top";
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected or file is empty");
    }
    if (variant !== "top" && variant !== "bottom") {
      throw new Error("Invalid variant");
    }
    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : `${variant}.png`;
    const ext = originalName.includes(".")
      ? originalName.split(".").pop()?.toLowerCase() || "png"
      : "png";
    const safeExt = ext.replace(/[^a-z0-9]/gi, "") || "png";
    const fileName = `party-screen/${variant}-${Date.now()}.${safeExt}`;
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const contentType = resolveContentType(fileEntry, originalName);
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType,
    });
    const column = columnForVariant(variant as BandVariant);
    const { error: dbError } = await supabaseAdmin.from("party_screen_config").upsert(
      {
        id: 1,
        [column]: publicUrl,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "id" },
    );
    if (dbError) {
      throw new Error(
        `Upload OK but database save failed: ${dbError.message}. Run migration 20250630140000_party_screen_config.sql.`,
      );
    }
    revalidatePath("/settings/party-screen");
    return { success: true, url: publicUrl };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[uploadPartyScreenImage]", message);
    return { success: false, error: message };
  }
}
