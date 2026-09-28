"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
export type LuckyBagTierInput = {
  id?: string;
  label: string;
  total_coins: number;
  recipient_options: number[];
  is_active: boolean;
  sort_order: number;
};
export async function listLuckyBagTiers() {
  const { data, error } = await supabaseAdmin
    .from("lucky_bag_tiers")
    .select("*")
    .order("sort_order", { ascending: true });
  if (error) throw error;
  return data ?? [];
}
export async function upsertLuckyBagTier(tier: LuckyBagTierInput) {
  const payload = {
    label: tier.label,
    total_coins: tier.total_coins,
    recipient_options: tier.recipient_options,
    is_active: tier.is_active,
    sort_order: tier.sort_order,
    updated_at: new Date().toISOString(),
  };
  if (tier.id) {
    const { error } = await supabaseAdmin.from("lucky_bag_tiers").update(payload).eq("id", tier.id);
    if (error) throw error;
  } else {
    const { error } = await supabaseAdmin.from("lucky_bag_tiers").insert(payload);
    if (error) throw error;
  }
  revalidatePath("/settings/lucky-bags");
  return { success: true };
}
export async function deleteLuckyBagTier(id: string) {
  const { error } = await supabaseAdmin.from("lucky_bag_tiers").delete().eq("id", id);
  if (error) throw error;
  revalidatePath("/settings/lucky-bags");
  return { success: true };
}
export async function getLuckyBagRules() {
  const { data, error } = await supabaseAdmin
    .from("lucky_bag_rules")
    .select("rules")
    .eq("id", 1)
    .maybeSingle();
  if (error) throw error;
  return (data?.rules as string[]) ?? [];
}
export async function updateLuckyBagRules(rules: string[]) {
  const { error } = await supabaseAdmin.from("lucky_bag_rules").upsert({
    id: 1,
    rules,
    updated_at: new Date().toISOString(),
  });
  if (error) throw error;
  revalidatePath("/settings/lucky-bags");
  return { success: true };
}
