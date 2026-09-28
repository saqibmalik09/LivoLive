"use server";
import { supabaseAdmin } from "@/lib/supabase";
import {
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { revalidatePath } from "next/cache";
export type RoomRewardLevelRow = {
  level: number;
  required_points: number;
  is_active: boolean;
  sort_order: number;
};
export type RoomRewardItemRow = {
  id: string;
  level: number;
  title: string;
  image_url: string;
  reward_type: "coins" | "shop_item";
  coin_amount: number;
  shop_item_id?: string | null;
  weight: number;
  sort_order: number;
  is_active: boolean;
  is_featured: boolean;
};
export async function listRoomRewardLevelsAdmin() {
  const { data, error } = await supabaseAdmin
    .from("room_reward_levels")
    .select("*")
    .order("level", { ascending: true });
  if (error)
    return { success: false as const, error: error.message, levels: [] as RoomRewardLevelRow[] };
  return {
    success: true as const,
    levels: (data ?? []).map((r) => ({
      level: Number(r.level),
      required_points: Number(r.required_points),
      is_active: Boolean(r.is_active),
      sort_order: Number(r.sort_order ?? 0),
    })),
  };
}
export async function listRoomRewardItemsAdmin() {
  const { data, error } = await supabaseAdmin
    .from("room_reward_items")
    .select("*")
    .order("level", { ascending: true })
    .order("sort_order", { ascending: true });
  if (error)
    return { success: false as const, error: error.message, items: [] as RoomRewardItemRow[] };
  return {
    success: true as const,
    items: (data ?? []) as RoomRewardItemRow[],
  };
}
export async function getRoomRewardRulesAdmin() {
  const { data, error } = await supabaseAdmin
    .from("room_reward_rules")
    .select("rules")
    .eq("id", 1)
    .maybeSingle();
  if (error) return { success: false as const, error: error.message, rules: [] as string[] };
  const rules = Array.isArray(data?.rules) ? (data!.rules as unknown[]).map((r) => String(r)) : [];
  return { success: true as const, rules };
}
export async function listShopItemsForRoomReward() {
  const { data, error } = await supabaseAdmin
    .from("shop_items")
    .select("id, name, image_url, price_coins, is_active")
    .eq("is_active", true)
    .order("name", { ascending: true })
    .limit(300);
  if (error) return [];
  return (data ?? []).map((r) => ({
    id: String(r.id),
    name: String(r.name ?? "Item"),
    image_url: String(r.image_url ?? ""),
    price_coins: Number(r.price_coins ?? 0),
  }));
}
export async function upsertRoomRewardLevel(data: {
  level: number;
  required_points: number;
  is_active?: boolean;
}) {
  try {
    const { error } = await supabaseAdmin.from("room_reward_levels").upsert(
      {
        level: data.level,
        required_points: data.required_points,
        is_active: data.is_active ?? true,
        sort_order: data.level,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "level" },
    );
    if (error) throw error;
    revalidatePath("/settings/room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function upsertRoomRewardItem(data: {
  id?: string;
  level: number;
  title: string;
  image_url: string;
  reward_type: "coins" | "shop_item";
  coin_amount?: number;
  shop_item_id?: string | null;
  weight?: number;
  sort_order?: number;
  is_active?: boolean;
  is_featured?: boolean;
}) {
  try {
    if (!data.image_url?.trim()) throw new Error("Image is required");
    if (data.reward_type === "coins" && !(data.coin_amount && data.coin_amount > 0)) {
      throw new Error("Coin amount required for coin rewards");
    }
    if (data.reward_type === "shop_item" && !data.shop_item_id) {
      throw new Error("Shop item required");
    }
    const payload = {
      level: data.level,
      title: data.title?.trim() || "Reward",
      image_url: data.image_url.trim(),
      reward_type: data.reward_type,
      coin_amount: data.reward_type === "coins" ? (data.coin_amount ?? 0) : 0,
      shop_item_id: data.reward_type === "shop_item" ? data.shop_item_id : null,
      weight: data.weight ?? 1,
      sort_order: data.sort_order ?? 0,
      is_active: data.is_active ?? true,
      is_featured: data.is_featured ?? false,
      updated_at: new Date().toISOString(),
    };
    if (data.id) {
      const { error } = await supabaseAdmin
        .from("room_reward_items")
        .update(payload)
        .eq("id", data.id);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin.from("room_reward_items").insert(payload);
      if (error) throw error;
    }
    revalidatePath("/settings/room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function deleteRoomRewardItem(id: string) {
  try {
    const { error } = await supabaseAdmin.from("room_reward_items").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function updateRoomRewardRules(rules: string[]) {
  try {
    const cleaned = rules.map((r) => r.trim()).filter(Boolean);
    const { error } = await supabaseAdmin.from("room_reward_rules").upsert({
      id: 1,
      rules: cleaned,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
    revalidatePath("/settings/room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function uploadRoomRewardImage(formData: FormData) {
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
    const fileName = `room-rewards/${Date.now()}-${originalName
      .replace(/\s+/g, "_")
      .replace(/\.[^.]+$/, "")}.${ext}`;
    const bucket = supabaseAdmin.storage.from("app_assets");
    const { error: uploadError } = await bucket.upload(fileName, buffer, {
      contentType,
      upsert: true,
    });
    if (uploadError) throw uploadError;
    const {
      data: { publicUrl },
    } = bucket.getPublicUrl(fileName);
    return { success: true as const, url: publicUrl };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
