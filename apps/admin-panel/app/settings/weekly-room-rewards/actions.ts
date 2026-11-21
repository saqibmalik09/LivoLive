"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { uploadPublicBucketToR2 } from "@/lib/r2";
import {
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { revalidatePath } from "next/cache";
export type WeeklyRoomRewardLevelRow = {
  level: number;
  required_points: number;
  coin_reward: number;
  reward_type: "coins" | "shop_item";
  shop_item_id?: string | null;
  duration_days?: number | null;
  title: string;
  image_url: string;
  is_active: boolean;
  sort_order: number;
};
export type WeeklyShopOption = {
  id: string;
  name: string;
  image_url: string;
  duration_days: number | null;
  category: string;
};
function isCosmetic(categoryName: string, itemName: string): boolean {
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
export async function listShopItemsForWeeklyRoomReward(): Promise<WeeklyShopOption[]> {
  const { data, error } = await supabaseAdmin
    .from("shop_items")
    .select("id, name, image_url, duration_days, is_active, shop_categories(name)")
    .eq("is_active", true)
    .order("name", { ascending: true })
    .limit(400);
  if (error) return [];
  const mapped = (data ?? []).map((r) => {
    const cat =
      (
        r.shop_categories as {
          name?: string;
        } | null
      )?.name ?? "";
    return {
      id: String(r.id),
      name: String(r.name ?? "Item"),
      image_url: String(r.image_url ?? ""),
      duration_days: r.duration_days == null ? null : Number(r.duration_days),
      category: cat,
      cosmetic: isCosmetic(cat, String(r.name ?? "")),
    };
  });
  const cosmetics = mapped.filter((m) => m.cosmetic);
  const list = cosmetics.length > 0 ? cosmetics : mapped;
  return list.map(({ cosmetic: _c, ...rest }) => rest);
}
export async function upsertWeeklyRoomRewardLevel(data: {
  level: number;
  required_points: number;
  coin_reward?: number;
  reward_type?: "coins" | "shop_item";
  shop_item_id?: string | null;
  duration_days?: number | null;
  title?: string;
  image_url?: string;
  is_active?: boolean;
}) {
  try {
    if (data.level < 1) {
      return { success: false as const, error: "Level must be >= 1" };
    }
    const rewardType = data.reward_type ?? "coins";
    if (rewardType === "coins" && !(data.coin_reward && data.coin_reward > 0)) {
      return { success: false as const, error: "Coin amount required" };
    }
    if (rewardType === "shop_item" && !data.shop_item_id) {
      return { success: false as const, error: "Shop item required" };
    }
    const { error } = await supabaseAdmin.from("weekly_room_reward_levels").upsert(
      {
        level: data.level,
        required_points: data.required_points,
        coin_reward: rewardType === "coins" ? (data.coin_reward ?? 0) : 0,
        reward_type: rewardType,
        shop_item_id: rewardType === "shop_item" ? data.shop_item_id : null,
        duration_days:
          rewardType === "shop_item"
            ? data.duration_days == null || Number.isNaN(Number(data.duration_days))
              ? null
              : Number(data.duration_days)
            : null,
        title: (data.title ?? "").trim(),
        image_url: (data.image_url ?? "").trim(),
        is_active: data.is_active ?? true,
        sort_order: data.level,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "level" },
    );
    if (error) throw error;
    revalidatePath("/settings/weekly-room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function deleteWeeklyRoomRewardLevel(level: number) {
  try {
    if (level < 1) {
      return { success: false as const, error: "Invalid level" };
    }
    const { count } = await supabaseAdmin
      .from("weekly_room_reward_claims")
      .select("id", { count: "exact", head: true })
      .eq("level", level);
    if ((count ?? 0) > 0) {
      return {
        success: false as const,
        error: "Level has claim history — deactivate it instead of deleting",
      };
    }
    const { error } = await supabaseAdmin
      .from("weekly_room_reward_levels")
      .delete()
      .eq("level", level);
    if (error) throw error;
    revalidatePath("/settings/weekly-room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function updateWeeklyRoomRewardRules(rules: string[]) {
  try {
    const cleaned = rules.map((r) => r.trim()).filter(Boolean);
    const { error } = await supabaseAdmin.from("weekly_room_reward_rules").upsert(
      {
        id: 1,
        rules: cleaned,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "id" },
    );
    if (error) throw error;
    revalidatePath("/settings/weekly-room-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function uploadWeeklyRoomRewardImage(formData: FormData) {
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
    const fileName = `weekly-room-rewards/${Date.now()}-${originalName
      .replace(/\s+/g, "_")
      .replace(/\.[^.]+$/, "")}.${ext}`;
    const { publicUrl } = await uploadPublicBucketToR2({
      bucket: "app_assets",
      objectPath: fileName,
      body: buffer,
      contentType: contentType,
    });
    return { success: true as const, url: publicUrl };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
