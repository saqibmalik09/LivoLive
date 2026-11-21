"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { revalidatePath } from "next/cache";
export type PodiumBgSlot = "room" | "agency" | "charm" | "wealth";
function bgColumn(slot: PodiumBgSlot): string {
  return `${slot}_bg_url`;
}
export async function updateRankingPodiumConfig(data: Record<string, unknown>) {
  try {
    const { error } = await supabaseAdmin
      .from("home_ranking_podium_config")
      .upsert({ id: 1, ...data, updated_at: new Date().toISOString() }, { onConflict: "id" });
    if (error) throw error;
    revalidatePath("/settings/ranking-podium");
    return { success: true };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
export async function uploadRankingPodiumBg(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    const slot = (formData.get("slot") as PodiumBgSlot) || "room";
    const valid: PodiumBgSlot[] = ["room", "agency", "charm", "wealth"];
    if (!valid.includes(slot)) throw new Error("Invalid slot");
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected");
    }
    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : `${slot}.png`;
    const ext = originalName.split(".").pop()?.toLowerCase() || "png";
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const fileName = `ranking-podium/${slot}-${Date.now()}.${ext}`;
    const contentType =
      ext === "jpg" || ext === "jpeg" ? "image/jpeg" : "image/png";
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType,
    });
    const { error: dbError } = await supabaseAdmin.from("home_ranking_podium_config").upsert(
      {
        id: 1,
        [bgColumn(slot)]: publicUrl,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "id" },
    );
    if (dbError) throw dbError;
    revalidatePath("/settings/ranking-podium");
    return { success: true, url: publicUrl };
  } catch (error: unknown) {
    return {
      success: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
