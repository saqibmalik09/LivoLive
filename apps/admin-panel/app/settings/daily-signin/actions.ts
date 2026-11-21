"use server";
import { supabaseAdmin } from "@/lib/supabase";
import {
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { uploadShopAssetToR2 } from "@/lib/r2";
import { revalidatePath } from "next/cache";
export type DailySignInRewardRow = {
  day_number: number;
  reward_type: "coins" | "shop_item";
  coin_amount: number;
  shop_item_id: string | null;
  image_url: string | null;
  label: string | null;
  is_active: boolean;
};
export async function listDailySignInRewardsAdmin() {
  const { data, error } = await supabaseAdmin
    .from("daily_signin_rewards")
    .select("*")
    .order("day_number", { ascending: true });
  if (error) {
    return {
      success: false as const,
      error: error.message,
      rows: [] as DailySignInRewardRow[],
    };
  }
  return {
    success: true as const,
    rows: (data ?? []).map((r) => ({
      day_number: Number(r.day_number),
      reward_type: (r.reward_type === "shop_item" ? "shop_item" : "coins") as "coins" | "shop_item",
      coin_amount: Number(r.coin_amount ?? 0),
      shop_item_id: r.shop_item_id ? String(r.shop_item_id) : null,
      image_url: r.image_url ? String(r.image_url) : null,
      label: r.label ? String(r.label) : null,
      is_active: Boolean(r.is_active),
    })),
  };
}
export async function listShopItemsForDailySignIn() {
  const { data, error } = await supabaseAdmin
    .from("shop_items")
    .select("id, name, image_url, price_coins, is_active")
    .eq("is_active", true)
    .order("name", { ascending: true })
    .limit(400);
  if (error) return [];
  return (data ?? []).map((r) => ({
    id: String(r.id),
    name: String(r.name ?? "Item"),
    image_url: String(r.image_url ?? ""),
    price_coins: Number(r.price_coins ?? 0),
  }));
}
export async function upsertDailySignInReward(data: {
  day_number: number;
  reward_type: "coins" | "shop_item";
  coin_amount?: number;
  shop_item_id?: string | null;
  image_url?: string | null;
  label?: string | null;
  is_active?: boolean;
}) {
  try {
    const day = data.day_number;
    if (day < 1 || day > 7) throw new Error("Day must be 1–7");
    if (data.reward_type === "coins" && !(data.coin_amount && data.coin_amount > 0)) {
      throw new Error("Coin amount required");
    }
    if (data.reward_type === "shop_item" && !data.shop_item_id) {
      throw new Error("Shop item required for asset rewards");
    }
    const { error } = await supabaseAdmin.from("daily_signin_rewards").upsert(
      {
        day_number: day,
        reward_type: data.reward_type,
        coin_amount: data.reward_type === "coins" ? (data.coin_amount ?? 0) : 0,
        shop_item_id: data.reward_type === "shop_item" ? data.shop_item_id : null,
        image_url: data.image_url?.trim() || null,
        label: data.label?.trim() || `Day ${day}`,
        is_active: data.is_active ?? true,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "day_number" },
    );
    if (error) throw error;
    revalidatePath("/settings/daily-signin");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function uploadDailySignInImage(formData: FormData) {
  try {
    const fileEntry = formData.get("file");
    if (!(fileEntry instanceof Blob) || fileEntry.size === 0) {
      throw new Error("No file selected");
    }
    const originalName =
      fileEntry instanceof File && fileEntry.name ? fileEntry.name : "reward.png";
    const fileType = fileEntry instanceof File ? fileEntry.type : "";
    const ext = resolveRankingAssetExtension(originalName, fileType);
    const contentType = resolveRankingAssetContentType(fileEntry, originalName);
    const buffer = Buffer.from(await fileEntry.arrayBuffer());
    const fileName = `daily-signin/${Date.now()}-${originalName
      .replace(/\s+/g, "_")
      .replace(/\.[^.]+$/, "")}.${ext}`;
    const { publicUrl } = await uploadShopAssetToR2({
      key: fileName,
      body: buffer,
      contentType,
    });
    return { success: true as const, url: publicUrl };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
