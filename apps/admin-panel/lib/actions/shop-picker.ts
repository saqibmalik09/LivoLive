"use server";
import { supabaseAdmin } from "@/lib/supabase";
const REWARD_KEYS = ["frame", "bubble", "card_background", "entrance"] as const;
function matchesRewardType(featureKey: string, categoryName: string, itemName: string): boolean {
  const cat = categoryName.toLowerCase();
  const name = itemName.toLowerCase();
  switch (featureKey) {
    case "frame":
      return (
        cat.includes("photo frame") ||
        cat === "frame" ||
        (cat.includes("frame") && !cat.includes("card") && !name.includes("card"))
      );
    case "bubble":
      return cat.includes("bubble") || name.includes("bubble");
    case "card_background":
      return (
        cat.includes("card background") ||
        cat.includes("profile card background") ||
        (cat.includes("card") && cat.includes("background") && !cat.includes("frame"))
      );
    case "entrance":
      return cat.includes("entrance") || name.includes("entrance");
    case "vip":
    case "svip":
      return (
        cat.includes("vip") ||
        name.includes("vip") ||
        name.includes("svip") ||
        cat.includes("membership")
      );
    case "badge":
    case "tag":
      return (
        cat.includes("badge") ||
        cat.includes("tag") ||
        name.includes("badge") ||
        name.includes("tag")
      );
    default:
      return true;
  }
}
export async function searchShopItemsForReward(featureKey: string, query?: string) {
  const { data: allItems, error } = await supabaseAdmin
    .from("shop_items")
    .select("id, name, image_url, shop_categories(name)")
    .eq("is_active", true)
    .order("name", { ascending: true })
    .limit(200);
  if (error) throw error;
  const q = query?.trim().toLowerCase() ?? "";
  let filtered = (allItems ?? []).filter((item) => {
    const catName =
      (
        item.shop_categories as {
          name?: string;
        } | null
      )?.name ?? "";
    if (!matchesRewardType(featureKey, catName, item.name ?? "")) {
      return false;
    }
    if (!q) return true;
    return (item.name ?? "").toLowerCase().includes(q) || catName.toLowerCase().includes(q);
  });
  if (filtered.length === 0) {
    filtered = (allItems ?? []).filter((item) => {
      if (!q) return true;
      const catName =
        (
          item.shop_categories as {
            name?: string;
          } | null
        )?.name?.toLowerCase() ?? "";
      return (item.name ?? "").toLowerCase().includes(q) || catName.includes(q);
    });
  }
  return filtered.slice(0, 80);
}
export async function listRewardFeatureKeys() {
  return [...REWARD_KEYS];
}
