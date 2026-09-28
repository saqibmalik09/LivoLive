"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { toDirectDownloadUrl } from "@/lib/download-url";
import { revalidatePath } from "next/cache";
export async function saveAppVersion(
  platform: "android" | "ios",
  minVersion: string,
  landingSiteUrl: string,
  isForceUpdate: boolean,
  apkDownloadUrl?: string | null,
) {
  try {
    const siteUrl = landingSiteUrl.trim();
    if (!siteUrl) throw new Error("Landing site URL is required");
    const apkRaw = (apkDownloadUrl ?? "").trim();
    const apkUrl = apkRaw ? toDirectDownloadUrl(apkRaw) : null;
    const payload = {
      min_version: minVersion,
      download_url: siteUrl,
      is_force_update: isForceUpdate,
      apk_download_url: apkUrl,
    };
    const { data: existing } = await supabaseAdmin
      .from("app_versions")
      .select("id")
      .eq("platform", platform)
      .maybeSingle();
    let error;
    if (existing) {
      const res = await supabaseAdmin.from("app_versions").update(payload).eq("platform", platform);
      error = res.error;
    } else {
      const res = await supabaseAdmin.from("app_versions").insert({
        platform,
        ...payload,
      });
      error = res.error;
    }
    if (error) throw error;
    revalidatePath("/settings/versions");
    revalidatePath("/settings");
    return {
      success: true,
      downloadUrl: siteUrl,
      apkDownloadUrl: apkUrl,
    };
  } catch (error: any) {
    console.error("Error saving app version:", error);
    return { success: false, error: error.message };
  }
}
