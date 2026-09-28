"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
const PATH = "/settings/coin-seller-policy";
function revalidate() {
  revalidatePath(PATH);
}
export async function getCoinSellerSettings() {
  const { data, error } = await supabaseAdmin
    .from("coin_seller_policy_settings")
    .select("*")
    .eq("id", 1)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}
export async function updateCoinSellerSettings(formData: FormData) {
  const coins_per_usd = Number(formData.get("coins_per_usd"));
  const min_recharge_usd = Number(formData.get("min_recharge_usd"));
  const is_active = formData.get("is_active") === "on" || formData.get("is_active") === "true";
  if (!Number.isFinite(coins_per_usd) || coins_per_usd <= 0) {
    throw new Error("Invalid coins per USD");
  }
  if (!Number.isFinite(min_recharge_usd) || min_recharge_usd < 0) {
    throw new Error("Invalid min recharge");
  }
  const { error } = await supabaseAdmin.from("coin_seller_policy_settings").upsert({
    id: 1,
    coins_per_usd,
    min_recharge_usd,
    is_active,
    updated_at: new Date().toISOString(),
  });
  if (error) throw new Error(error.message);
  revalidate();
}
export async function listCoinSellerTiers() {
  const { data, error } = await supabaseAdmin
    .from("coin_seller_policy_tiers")
    .select("*")
    .order("sort_order", { ascending: true })
    .order("usd_amount", { ascending: true });
  if (error) throw new Error(error.message);
  return data ?? [];
}
export async function upsertCoinSellerTier(input: {
  id?: string | null;
  usd_amount: number;
  basic_coins: number;
  bonus_ratio_percent: number;
  total_coins?: number | null;
  label?: string | null;
  is_active?: boolean;
  sort_order?: number;
}) {
  const usd = Number(input.usd_amount);
  const basic = Number(input.basic_coins);
  const ratio = Number(input.bonus_ratio_percent);
  if (!Number.isFinite(usd) || usd <= 0) throw new Error("USD amount required");
  if (!Number.isFinite(basic) || basic <= 0) throw new Error("Basic coins required");
  if (!Number.isFinite(ratio) || ratio <= 0) throw new Error("Ratio required");
  const total =
    input.total_coins != null && Number.isFinite(Number(input.total_coins))
      ? Math.round(Number(input.total_coins))
      : Math.round(basic * (ratio / 100));
  const payload = {
    usd_amount: usd,
    basic_coins: Math.round(basic),
    bonus_ratio_percent: ratio,
    total_coins: total,
    label: input.label?.trim() || `$${usd}`,
    is_active: input.is_active ?? true,
    sort_order: input.sort_order ?? 0,
    updated_at: new Date().toISOString(),
  };
  if (input.id) {
    const { error } = await supabaseAdmin
      .from("coin_seller_policy_tiers")
      .update(payload)
      .eq("id", input.id);
    if (error) throw new Error(error.message);
  } else {
    const { error } = await supabaseAdmin.from("coin_seller_policy_tiers").insert(payload);
    if (error) throw new Error(error.message);
  }
  revalidate();
}
export async function deleteCoinSellerTier(id: string) {
  const { error } = await supabaseAdmin.from("coin_seller_policy_tiers").delete().eq("id", id);
  if (error) throw new Error(error.message);
  revalidate();
}
export async function toggleCoinSellerTier(id: string, is_active: boolean) {
  const { error } = await supabaseAdmin
    .from("coin_seller_policy_tiers")
    .update({ is_active, updated_at: new Date().toISOString() })
    .eq("id", id);
  if (error) throw new Error(error.message);
  revalidate();
}
export async function listCoinSellerRewards() {
  const { data, error } = await supabaseAdmin
    .from("coin_seller_policy_rewards")
    .select(
      `id, tier_id, feature_key, vip_plan_id, shop_item_id, duration_days, label, sort_order,
       shop_item:shop_item_id(id, name, image_url)`,
    )
    .order("sort_order", { ascending: true });
  if (error) throw new Error(error.message);
  return (data ?? []).map((row: any) => {
    const shop = Array.isArray(row.shop_item) ? row.shop_item[0] : row.shop_item;
    return {
      id: row.id as string,
      tier_id: row.tier_id as string,
      feature_key: row.feature_key as string,
      vip_plan_id: (row.vip_plan_id as string | null) ?? null,
      shop_item_id: (row.shop_item_id as string | null) ?? null,
      duration_days: (row.duration_days as number | null) ?? null,
      label: (row.label as string | null) ?? null,
      sort_order: row.sort_order as number,
      shop_item_name: (shop?.name as string | null) ?? null,
      shop_item_image: (shop?.image_url as string | null) ?? null,
    };
  });
}
export async function listVipPlansForSeller() {
  const { data, error } = await supabaseAdmin
    .from("vip_plans")
    .select("id, level, name, duration_days")
    .order("level", { ascending: true });
  if (error) throw new Error(error.message);
  return data ?? [];
}
export async function saveCoinSellerReward(input: {
  tier_id: string;
  feature_key: string;
  vip_plan_id?: string | null;
  shop_item_id?: string | null;
  duration_days?: number | null;
  label?: string | null;
}) {
  const tier_id = String(input.tier_id || "").trim();
  const feature_key = String(input.feature_key || "").trim();
  if (!tier_id || !feature_key) throw new Error("tier_id and feature_key required");
  const sort_order =
    feature_key === "vip" ? 0 : feature_key === "frame" ? 1 : feature_key === "entrance" ? 2 : 3;
  const { error } = await supabaseAdmin.from("coin_seller_policy_rewards").upsert(
    {
      tier_id,
      feature_key,
      vip_plan_id: input.vip_plan_id || null,
      shop_item_id: input.shop_item_id || null,
      duration_days: input.duration_days ?? null,
      label: input.label || null,
      sort_order,
    },
    { onConflict: "tier_id,feature_key" },
  );
  if (error) throw new Error(error.message);
  revalidate();
}
export async function clearCoinSellerReward(tier_id: string, feature_key: string) {
  const { error } = await supabaseAdmin
    .from("coin_seller_policy_rewards")
    .delete()
    .eq("tier_id", tier_id)
    .eq("feature_key", feature_key);
  if (error) throw new Error(error.message);
  revalidate();
}
export async function searchUsersForSellerFulfill(query: string) {
  const term = query.trim();
  if (!term) return [];
  if (/^\d+$/.test(term)) {
    const { data, error } = await supabaseAdmin
      .from("users")
      .select("id, username, short_id, avatar_url, is_reseller, reseller_coins")
      .eq("short_id", Number(term))
      .limit(5);
    if (error) throw new Error(error.message);
    return data ?? [];
  }
  if (term.length < 2) return [];
  const { data, error } = await supabaseAdmin
    .from("users")
    .select("id, username, short_id, avatar_url, is_reseller, reseller_coins")
    .ilike("username", `%${term}%`)
    .limit(20);
  if (error) throw new Error(error.message);
  return data ?? [];
}
export async function fulfillCoinSellerPurchase(input: {
  user_id: string;
  tier_id?: string | null;
  notes?: string | null;
  coins_override?: number | string | null;
  usd_override?: number | null;
}) {
  const coinsRaw =
    input.coins_override != null ? String(input.coins_override).trim().replace(/,/g, "") : "";
  const coins =
    coinsRaw && /^-?\d+$/.test(coinsRaw) && coinsRaw !== "-" && BigInt(coinsRaw) !== BigInt(0)
      ? coinsRaw
      : null;
  const usd =
    input.usd_override != null && Number.isFinite(Number(input.usd_override))
      ? Number(input.usd_override)
      : null;
  if (!coins) {
    throw new Error("Enter any non-zero coins amount (tier not required)");
  }
  const { data, error } = await supabaseAdmin.rpc("admin_fulfill_coin_seller_purchase", {
    p_user_id: input.user_id,
    p_tier_id: input.tier_id || null,
    p_notes: input.notes || null,
    p_coins_override: coins,
    p_usd_override: usd,
  });
  if (error) throw new Error(error.message);
  revalidate();
  return data;
}
export async function listRecentCoinSellerPurchases() {
  const { data, error } = await supabaseAdmin
    .from("coin_seller_purchases")
    .select(
      `id, user_id, tier_id, usd_amount, coins_credited, rewards_json, notes, created_at,
       user:user_id(username, short_id, avatar_url)`,
    )
    .order("created_at", { ascending: false })
    .limit(30);
  if (error) throw new Error(error.message);
  return (data ?? []).map((row: any) => {
    const user = Array.isArray(row.user) ? row.user[0] : row.user;
    return {
      ...row,
      username: user?.username ?? null,
      short_id: user?.short_id ?? null,
      avatar_url: user?.avatar_url ?? null,
    };
  });
}
