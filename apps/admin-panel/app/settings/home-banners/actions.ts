"use server";
import { supabaseAdmin } from "@/lib/supabase";
import {
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import { revalidatePath } from "next/cache";
import {
  HOME_TOP_BANNER_HEIGHT_DEFAULT,
  HOME_TOP_BANNER_HEIGHT_KEY,
  HOME_TOP_BANNER_HEIGHT_MAX,
  HOME_TOP_BANNER_HEIGHT_MIN,
} from "@/app/settings/home-banners/constants";
export type HomeBannerRow = {
  id: string;
  image_url: string;
  link_url?: string | null;
  room_number?: number | null;
  party_event_id?: string | null;
  priority: number;
  is_active: boolean;
  placement?: "top" | "after_rooms" | "profile";
  title?: string | null;
  created_at?: string;
};
export type HomeBannerPlacement = "top" | "after_rooms" | "profile";
function clampHomeTopBannerHeight(raw: unknown): number {
  const n = Math.round(Number(raw));
  if (!Number.isFinite(n)) return HOME_TOP_BANNER_HEIGHT_DEFAULT;
  return Math.min(HOME_TOP_BANNER_HEIGHT_MAX, Math.max(HOME_TOP_BANNER_HEIGHT_MIN, n));
}
export async function getHomeTopBannerHeight(): Promise<number> {
  const { data } = await supabaseAdmin
    .from("system_settings")
    .select("value")
    .eq("key", HOME_TOP_BANNER_HEIGHT_KEY)
    .maybeSingle();
  if (data?.value == null || String(data.value).trim() === "") {
    return HOME_TOP_BANNER_HEIGHT_DEFAULT;
  }
  return clampHomeTopBannerHeight(data.value);
}
export async function saveHomeTopBannerHeight(height: number) {
  try {
    const value = String(clampHomeTopBannerHeight(height));
    const description = "Home Hot top banner display height in app dp. Admin adjustable.";
    const { data, error } = await supabaseAdmin
      .from("system_settings")
      .update({
        value,
        description,
        updated_at: new Date().toISOString(),
      })
      .eq("key", HOME_TOP_BANNER_HEIGHT_KEY)
      .select("key");
    if (error) throw error;
    if (!data?.length) {
      const { error: insertError } = await supabaseAdmin.from("system_settings").insert({
        key: HOME_TOP_BANNER_HEIGHT_KEY,
        value,
        description,
        updated_at: new Date().toISOString(),
      });
      if (insertError) throw insertError;
    }
    revalidatePath("/settings/home-banners");
    return { success: true as const, height: Number(value) };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export type BannerPartyEventOption = {
  id: string;
  title: string;
  is_active?: boolean;
};
export async function listPartyEventsForBannerLink(): Promise<BannerPartyEventOption[]> {
  const { data, error } = await supabaseAdmin
    .from("party_events")
    .select("id, title, is_active")
    .order("priority", { ascending: false });
  if (error) return [];
  return (data ?? []) as BannerPartyEventOption[];
}
export async function listHomeBanners(placement?: HomeBannerPlacement) {
  let query = supabaseAdmin
    .from("banners")
    .select("*")
    .order("priority", { ascending: false })
    .order("created_at", { ascending: false });
  if (placement) {
    query = query.eq("placement", placement);
  }
  const { data, error } = await query;
  if (error) {
    return {
      success: false as const,
      error: error.message,
      items: [] as HomeBannerRow[],
    };
  }
  return { success: true as const, items: (data ?? []) as HomeBannerRow[] };
}
export async function upsertHomeBanner(data: {
  id?: string;
  image_url: string;
  link_url?: string | null;
  room_number?: number | null;
  party_event_id?: string | null;
  priority?: number;
  is_active?: boolean;
  placement?: HomeBannerPlacement;
}) {
  try {
    if (!data.image_url?.trim()) {
      throw new Error("Banner image is required");
    }
    const placement = data.placement ?? "top";
    let roomNumber: number | null = null;
    if (
      data.room_number != null &&
      Number.isFinite(Number(data.room_number)) &&
      Number(data.room_number) > 0
    ) {
      roomNumber = Math.trunc(Number(data.room_number));
    }
    const partyEventId =
      placement === "top" && data.party_event_id?.trim() ? data.party_event_id.trim() : null;
    const payload = {
      image_url: data.image_url.trim(),
      link_url: data.link_url?.trim() || null,
      room_number: placement === "after_rooms" || placement === "top" ? roomNumber : null,
      party_event_id: partyEventId,
      priority: Number.isFinite(data.priority) ? Number(data.priority) : 0,
      is_active: data.is_active ?? true,
      placement,
    };
    if (data.id) {
      const { error } = await supabaseAdmin.from("banners").update(payload).eq("id", data.id);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin.from("banners").insert(payload);
      if (error) throw error;
    }
    revalidatePath("/settings/home-banners");
    revalidatePath("/settings/home-feed-banners");
    revalidatePath("/settings/profile-banners");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function deleteHomeBanner(id: string) {
  try {
    const { error } = await supabaseAdmin.from("banners").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/home-banners");
    revalidatePath("/settings/home-feed-banners");
    revalidatePath("/settings/profile-banners");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function uploadHomeBannerImage(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected");
    }
    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : "banner.png";
    const fileType = fileEntry instanceof File ? fileEntry.type : "";
    const ext = resolveRankingAssetExtension(originalName, fileType);
    const contentType = resolveRankingAssetContentType(fileEntry, originalName);
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const safeBase = originalName
      .replace(/\s+/g, "_")
      .replace(/\.[^.]+$/, "")
      .slice(0, 40);
    const fileName = `banners/home-${Date.now()}-${safeBase}.${ext}`;
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
