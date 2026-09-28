"use server";
import { supabaseAdmin } from "@/lib/supabase";
import {
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { revalidatePath } from "next/cache";
export type OwnerRoomRewardLevelRow = {
  level: number;
  required_points: number;
  is_active: boolean;
  sort_order: number;
};
export type OwnerRoomRewardItemRow = {
  id: string;
  level: number;
  title: string;
  image_url: string;
  reward_type: "coins" | "shop_item";
  coin_amount: number;
  shop_item_id?: string | null;
  duration_days?: number | null;
  weight: number;
  sort_order: number;
  is_active: boolean;
  is_featured: boolean;
};
function isCosmeticCategory(categoryName: string, itemName: string): boolean {
  const cat = categoryName.toLowerCase();
  const name = itemName.toLowerCase();
  return (
    cat.includes("photo frame") ||
    cat === "frame" ||
    (cat.includes("frame") && !cat.includes("card")) ||
    cat.includes("bubble") ||
    name.includes("bubble") ||
    cat.includes("card background") ||
    (cat.includes("card") && cat.includes("background")) ||
    cat.includes("entrance") ||
    name.includes("entrance") ||
    cat.includes("car") ||
    name.includes("car") ||
    cat.includes("vehicle")
  );
}
export async function listShopItemsForOwnerRoomReward() {
  const { data, error } = await supabaseAdmin
    .from("shop_items")
    .select("id, name, image_url, price_coins, is_active, duration_days, shop_categories(name)")
    .eq("is_active", true)
    .order("name", { ascending: true })
    .limit(400);
  if (error) return [];
  const mapped = (data ?? []).map((r) => {
    const catName =
      (
        r.shop_categories as {
          name?: string;
        } | null
      )?.name ?? "";
    return {
      id: String(r.id),
      name: String(r.name ?? "Item"),
      image_url: String(r.image_url ?? ""),
      price_coins: Number(r.price_coins ?? 0),
      duration_days: r.duration_days == null ? null : Number(r.duration_days),
      category: catName,
      is_cosmetic: isCosmeticCategory(catName, String(r.name ?? "")),
    };
  });
  const cosmetics = mapped.filter((m) => m.is_cosmetic);
  return cosmetics.length > 0 ? cosmetics : mapped;
}
export async function upsertOwnerRoomRewardLevel(data: {
  level: number;
  required_points: number;
  is_active?: boolean;
}) {
  try {
    const { error } = await supabaseAdmin.from("owner_room_reward_levels").upsert(
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
    revalidatePath("/settings/owner-room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function upsertOwnerRoomRewardItem(data: {
  id?: string;
  level: number;
  title: string;
  image_url: string;
  reward_type: "coins" | "shop_item";
  coin_amount?: number;
  shop_item_id?: string | null;
  duration_days?: number | null;
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
      duration_days:
        data.reward_type === "shop_item"
          ? data.duration_days == null || Number.isNaN(data.duration_days)
            ? null
            : data.duration_days
          : null,
      weight: data.weight ?? 1,
      sort_order: data.sort_order ?? 0,
      is_active: data.is_active ?? true,
      is_featured: data.is_featured ?? false,
      updated_at: new Date().toISOString(),
    };
    if (data.id) {
      const { error } = await supabaseAdmin
        .from("owner_room_reward_items")
        .update(payload)
        .eq("id", data.id);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin.from("owner_room_reward_items").insert(payload);
      if (error) throw error;
    }
    revalidatePath("/settings/owner-room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function deleteOwnerRoomRewardItem(id: string) {
  try {
    const { error } = await supabaseAdmin.from("owner_room_reward_items").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/owner-room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function updateOwnerRoomRewardRules(rules: string[]) {
  try {
    const cleaned = rules.map((r) => r.trim()).filter(Boolean);
    const { error } = await supabaseAdmin.from("owner_room_reward_rules").upsert({
      id: 1,
      rules: cleaned,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
    revalidatePath("/settings/owner-room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function uploadOwnerRoomRewardImage(formData: FormData) {
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
    const fileName = `owner-room-rewards/${Date.now()}-${originalName
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
