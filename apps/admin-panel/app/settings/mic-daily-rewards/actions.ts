"use server";
import { supabaseAdmin } from "@/lib/supabase";
import {
  resolveRankingAssetContentType,
  resolveRankingAssetExtension,
} from "@/lib/ranking-asset-media";
import { revalidatePath } from "next/cache";
export type MicDailyRewardLevelRow = {
  id: string;
  required_seconds: number;
  sort_order: number;
  reward_type: "coins" | "shop_item";
  coin_amount: number;
  shop_item_id?: string | null;
  duration_days?: number | null;
  title: string;
  image_url: string;
  is_active: boolean;
};
export type MicShopOption = {
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
export async function listShopItemsForMicDailyReward(): Promise<MicShopOption[]> {
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
export async function upsertMicDailyRewardLevel(data: {
  id?: string;
  required_seconds: number;
  sort_order?: number;
  reward_type: "coins" | "shop_item";
  coin_amount?: number;
  shop_item_id?: string | null;
  duration_days?: number | null;
  title?: string;
  image_url?: string;
  is_active?: boolean;
}) {
  try {
    if (!(data.required_seconds > 0)) {
      return { success: false as const, error: "Required seconds must be > 0" };
    }
    if (data.reward_type === "coins" && !(data.coin_amount && data.coin_amount > 0)) {
      return { success: false as const, error: "Coin amount required" };
    }
    if (data.reward_type === "shop_item" && !data.shop_item_id) {
      return { success: false as const, error: "Shop item required" };
    }
    const payload = {
      required_seconds: data.required_seconds,
      sort_order: data.sort_order ?? data.required_seconds,
      reward_type: data.reward_type,
      coin_amount: data.reward_type === "coins" ? (data.coin_amount ?? 0) : 0,
      shop_item_id: data.reward_type === "shop_item" ? data.shop_item_id : null,
      duration_days:
        data.reward_type === "shop_item"
          ? data.duration_days == null || Number.isNaN(Number(data.duration_days))
            ? null
            : Number(data.duration_days)
          : null,
      title: (data.title ?? "").trim(),
      image_url: (data.image_url ?? "").trim(),
      is_active: data.is_active ?? true,
      updated_at: new Date().toISOString(),
    };
    if (data.id) {
      const { error } = await supabaseAdmin
        .from("mic_daily_reward_levels")
        .update(payload)
        .eq("id", data.id);
      if (error) throw error;
    } else {
      const { error } = await supabaseAdmin.from("mic_daily_reward_levels").insert(payload);
      if (error) throw error;
    }
    revalidatePath("/settings/mic-daily-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function deleteMicDailyRewardLevel(id: string) {
  try {
    const { count } = await supabaseAdmin
      .from("mic_daily_reward_claims")
      .select("id", { count: "exact", head: true })
      .eq("level_id", id);
    if ((count ?? 0) > 0) {
      return {
        success: false as const,
        error: "Level has claim history — deactivate it instead of deleting",
      };
    }
    const { error } = await supabaseAdmin.from("mic_daily_reward_levels").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/settings/mic-daily-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function updateMicDailyRewardRules(rules: string[]) {
  try {
    const cleaned = rules.map((r) => r.trim()).filter(Boolean);
    const { error } = await supabaseAdmin.from("mic_daily_reward_rules").upsert({
      id: 1,
      rules: cleaned,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
    revalidatePath("/settings/mic-daily-rewards");
    return { success: true as const };
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error);
    return { success: false as const, error: message };
  }
}
export async function uploadMicDailyRewardImage(formData: FormData) {
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
    const fileName = `mic-daily-rewards/${Date.now()}-${originalName
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
