"use server";
import { supabaseAdmin } from "@/lib/supabase";
import {
  isSvgaRankingAsset,
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { revalidatePath } from "next/cache";
export type RankingAssetCategory =
  | "Room"
  | "Agency"
  | "Gift"
  | "Charm"
  | "Podium"
  | "PodiumRoom"
  | "PodiumAgency"
  | "PodiumCharm"
  | "PodiumWealth";
export type RankingAssetPeriod = "daily" | "weekly" | "monthly";
export type RankingAssetField = "frame" | "badge";
export async function listRankingAssets(
  category: RankingAssetCategory,
  rankingType: RankingAssetPeriod,
) {
  const { data, error } = await supabaseAdmin
    .from("ranking_assets")
    .select("*")
    .eq("category", category)
    .eq("ranking_type", rankingType)
    .order("rank_position", { ascending: true });
  if (error) return { success: false as const, error: error.message, assets: [] };
  return { success: true as const, assets: data ?? [] };
}
export async function uploadRankingAsset(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    const category = (formData.get("category") as RankingAssetCategory) || "Room";
    const rankingType = (formData.get("rankingType") as RankingAssetPeriod) || "weekly";
    const rankPosition = parseInt(String(formData.get("rankPosition") ?? "1"), 10);
    const field = (formData.get("field") as RankingAssetField) || "frame";
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected");
    }
    if (rankPosition < 1 || rankPosition > 3) throw new Error("Rank must be 1–3");
    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : `${field}.png`;
    const fileType = fileEntry instanceof File ? fileEntry.type : "";
    const ext = resolveRankingAssetExtension(originalName, fileType);
    const isSvga = isSvgaRankingAsset(originalName, fileType);
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const contentType = resolveRankingAssetContentType(fileEntry, originalName);
    const fileName = `ranking-assets/${category.toLowerCase()}-${rankingType}-r${rankPosition}-${field}-${Date.now()}.${ext}`;
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType,
    });
    const frameMediaType = field === "frame" ? (isSvga ? "svga" : "image") : "image";
    const urlColumn = field === "badge" ? "badge_url" : "frame_url";
    const { data: existing, error: findError } = await supabaseAdmin
      .from("ranking_assets")
      .select("id, frame_url, badge_url")
      .eq("category", category)
      .eq("ranking_type", rankingType)
      .eq("rank_position", rankPosition)
      .maybeSingle();
    if (findError) throw findError;
    if (existing?.id) {
      const updatePayload: Record<string, unknown> = {
        [urlColumn]: publicUrl,
      };
      if (field === "frame") {
        updatePayload.frame_media_type = frameMediaType;
      }
      const { error } = await supabaseAdmin
        .from("ranking_assets")
        .update(updatePayload)
        .eq("id", existing.id);
      if (error) throw error;
    } else {
      const insertPayload = {
        category,
        ranking_type: rankingType,
        rank_position: rankPosition,
        frame_url: field === "frame" ? publicUrl : "",
        badge_url: field === "badge" ? publicUrl : "",
        frame_media_type: frameMediaType,
      };
      const { error } = await supabaseAdmin.from("ranking_assets").insert(insertPayload);
      if (error) throw error;
    }
    const { data: savedRow, error: readError } = await supabaseAdmin
      .from("ranking_assets")
      .select("frame_url, frame_media_type, badge_url")
      .eq("category", category)
      .eq("ranking_type", rankingType)
      .eq("rank_position", rankPosition)
      .single();
    if (readError) throw readError;
    revalidatePath("/settings/ranking-assets");
    revalidatePath("/settings/ranking-assets/agency");
    revalidatePath("/settings/room-card-frames");
    return {
      success: true,
      url: field === "frame" ? savedRow.frame_url : savedRow.badge_url,
      mediaType: savedRow.frame_media_type ?? (isSvga ? "svga" : "image"),
    };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("[uploadRankingAsset] failed", message);
    return {
      success: false,
      error: message,
    };
  }
}
export async function clearRankingAssetFrame(data: {
  category: RankingAssetCategory;
  rankingType: RankingAssetPeriod;
  rankPosition: number;
}) {
  try {
    const rankPosition = data.rankPosition;
    if (rankPosition < 1 || rankPosition > 3) {
      throw new Error("Rank must be 1–3");
    }
    const { error } = await supabaseAdmin
      .from("ranking_assets")
      .update({
        frame_url: "",
        frame_media_type: "image",
      })
      .eq("category", data.category)
      .eq("ranking_type", data.rankingType)
      .eq("rank_position", rankPosition);
    if (error) throw error;
    revalidatePath("/settings/ranking-assets");
    revalidatePath("/settings/ranking-assets/agency");
    revalidatePath("/settings/room-card-frames");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
