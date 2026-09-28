"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
function revalidateWallet() {
  revalidatePath("/settings/wallet");
  revalidatePath("/settings/wallet/merchants");
  revalidatePath("/settings/wallet/records");
  revalidatePath("/withdrawals");
}
export async function updateCashExchangeConfig(
  id: string | null,
  data: {
    coins_per_dollar: number;
    bonus_percent: number;
    is_active: boolean;
  },
) {
  try {
    if (id) {
      const { error } = await supabaseAdmin
        .from("cash_exchange_configs")
        .update({
          coins_per_dollar: data.coins_per_dollar,
          bonus_percent: data.bonus_percent,
          is_active: data.is_active,
          updated_at: new Date().toISOString(),
        })
        .eq("id", id);
      if (error) return { success: false, error: error.message };
    } else {
      const { error } = await supabaseAdmin.from("cash_exchange_configs").insert({
        coins_per_dollar: data.coins_per_dollar,
        bonus_percent: data.bonus_percent,
        is_active: data.is_active,
      });
      if (error) return { success: false, error: error.message };
    }
    revalidateWallet();
    return { success: true };
  } catch (e: unknown) {
    return { success: false, error: e instanceof Error ? e.message : "Unknown error" };
  }
}
export async function updateDiamondSalaryConfig(
  id: string | null,
  data: {
    diamonds_unit: number;
    usd_per_unit: number;
    is_active: boolean;
  },
) {
  try {
    if (id) {
      const { error } = await supabaseAdmin
        .from("diamond_salary_configs")
        .update({
          diamonds_unit: data.diamonds_unit,
          usd_per_unit: data.usd_per_unit,
          is_active: data.is_active,
          updated_at: new Date().toISOString(),
        })
        .eq("id", id);
      if (error) return { success: false, error: error.message };
    } else {
      const { error } = await supabaseAdmin.from("diamond_salary_configs").insert({
        diamonds_unit: data.diamonds_unit,
        usd_per_unit: data.usd_per_unit,
        is_active: data.is_active,
      });
      if (error) return { success: false, error: error.message };
    }
    revalidateWallet();
    return { success: true };
  } catch (e: unknown) {
    return { success: false, error: e instanceof Error ? e.message : "Unknown error" };
  }
}
export async function updateWithdrawalConfig(
  id: string | null,
  data: {
    fee_percent: number;
    min_amount: number;
    allowed_days: number[];
    timezone_offset_hours: number;
    is_active: boolean;
  },
) {
  try {
    if (id) {
      const { error } = await supabaseAdmin
        .from("withdrawal_configs")
        .update({
          fee_percent: data.fee_percent,
          min_amount: data.min_amount,
          allowed_days: data.allowed_days,
          timezone_offset_hours: data.timezone_offset_hours,
          is_active: data.is_active,
          updated_at: new Date().toISOString(),
        })
        .eq("id", id);
      if (error) return { success: false, error: error.message };
    } else {
      const { error } = await supabaseAdmin.from("withdrawal_configs").insert({
        fee_percent: data.fee_percent,
        min_amount: data.min_amount,
        allowed_days: data.allowed_days,
        timezone_offset_hours: data.timezone_offset_hours,
        is_active: data.is_active,
      });
      if (error) return { success: false, error: error.message };
    }
    revalidateWallet();
    return { success: true };
  } catch (e: unknown) {
    return { success: false, error: e instanceof Error ? e.message : "Unknown error" };
  }
}
export async function updatePaymentMethods(methods: string[]) {
  try {
    const { data: existing } = await supabaseAdmin
      .from("system_settings")
      .select("key")
      .eq("key", "payment_methods")
      .maybeSingle();
    const value = JSON.stringify(methods);
    if (existing) {
      const { error } = await supabaseAdmin
        .from("system_settings")
        .update({ value })
        .eq("key", "payment_methods");
      if (error) return { success: false, error: error.message };
    } else {
      const { error } = await supabaseAdmin.from("system_settings").insert({
        key: "payment_methods",
        value,
      });
      if (error) return { success: false, error: error.message };
    }
    revalidateWallet();
    return { success: true };
  } catch (e: unknown) {
    return { success: false, error: e instanceof Error ? e.message : "Unknown error" };
  }
}
export async function setResellerFlag(userId: string, isReseller: boolean) {
  try {
    const { error } = await supabaseAdmin
      .from("users")
      .update({ is_reseller: isReseller })
      .eq("id", userId);
    if (error) return { success: false, error: error.message };
    revalidateWallet();
    return { success: true };
  } catch (e: unknown) {
    return { success: false, error: e instanceof Error ? e.message : "Unknown error" };
  }
}
