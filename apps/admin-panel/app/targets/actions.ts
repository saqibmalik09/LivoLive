"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { auditUserLabel, logAdminAction } from "@/lib/admin-audit";
import { revalidatePath } from "next/cache";
export async function updateCommission(data: any) {
  try {
    const host = Number(data.host_pc) || 0;
    const agency = Number(data.agency_pc) || 0;
    const bd = Number(data.bd_pc) || 0;
    const bdAdmin = Number(data.bd_admin_pc) || 0;
    const superBd = Number(data.super_bd_pc) || 0;
    const official = Number(data.official_pc ?? data.admin_pc) || 0;
    const sum = host + agency + bd + bdAdmin + superBd + official;
    if (sum !== 100) {
      return { success: false, error: `Percentages must sum to 100 (current: ${sum})` };
    }
    const { error } = await supabaseAdmin.from("commission_configs").upsert({
      id: 1,
      host_pc: host,
      agency_pc: agency,
      bd_pc: bd,
      bd_admin_pc: bdAdmin,
      super_bd_pc: superBd,
      official_pc: official,
      admin_pc: official,
    });
    if (error) throw error;
    revalidatePath("/targets");
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function addSalaryTier(data: any) {
  try {
    const { error } = await supabaseAdmin.from("salary_tiers").insert(data);
    if (error) throw error;
    revalidatePath("/targets");
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function deleteSalaryTier(id: string) {
  try {
    const { error } = await supabaseAdmin.from("salary_tiers").delete().eq("id", id);
    if (error) throw error;
    revalidatePath("/targets");
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function updateSalaryTier(id: string, data: any) {
  try {
    const { error } = await supabaseAdmin.from("salary_tiers").update(data).eq("id", id);
    if (error) throw error;
    revalidatePath("/targets");
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function updateSalaryChainConfig(data: any) {
  try {
    const { error } = await supabaseAdmin.from("salary_chain_configs").upsert({
      id: 1,
      agency_salary_pc: Number(data.agency_salary_pc) || 0,
      bd_salary_pc: Number(data.bd_salary_pc) || 0,
      bd_admin_salary_pc: Number(data.bd_admin_salary_pc) || 0,
      super_bd_salary_pc: Number(data.super_bd_salary_pc) || 0,
      min_valid_day_seconds: Number(data.min_valid_day_seconds) || 7200,
      on_mic_only: data.on_mic_only !== false,
      diamonds_per_dollar: Number(data.diamonds_per_dollar) || 1000,
      updated_at: new Date().toISOString(),
    });
    if (error) throw error;
    revalidatePath("/targets");
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function resetAllPeriodTargets() {
  try {
    const { data, error } = await supabaseAdmin.rpc("admin_reset_period_targets", {
      p_scope: "all",
      p_user_id: null,
      p_short_id: null,
      p_period_id: null,
    });
    if (error) throw error;
    if (data?.success === false) throw new Error(data.message || "Reset failed");
    await logAdminAction({
      action: "targets.reset_all",
      targetType: "period",
      targetId: data?.period_id ?? null,
      summary: data?.message || "Reset all period targets",
      metadata: data ?? {},
    });
    revalidatePath("/targets");
    return { success: true as const, data };
  } catch (error: any) {
    return { success: false as const, error: error.message as string };
  }
}
export async function resetUserPeriodTargets(opts: { userId?: string; shortId?: string | number }) {
  try {
    const userId = opts.userId?.trim() || null;
    const shortRaw = opts.shortId != null ? String(opts.shortId).trim() : "";
    const shortId = shortRaw && /^\d+$/.test(shortRaw) ? Number(shortRaw) : null;
    if (!userId && shortId == null) {
      return { success: false as const, error: "Enter user ID or short ID" };
    }
    const { data, error } = await supabaseAdmin.rpc("admin_reset_period_targets", {
      p_scope: "user",
      p_user_id: userId,
      p_short_id: shortId,
      p_period_id: null,
    });
    if (error) throw error;
    if (data?.success === false) throw new Error(data.message || "Reset failed");
    const who = data?.user_id ? await auditUserLabel(String(data.user_id)) : shortRaw || "user";
    await logAdminAction({
      action: "targets.reset_user",
      targetType: "user",
      targetId: data?.user_id ?? userId,
      summary: `Reset period targets for ${who}`,
      metadata: data ?? {},
    });
    revalidatePath("/targets");
    if (data?.user_id) revalidatePath(`/users/${data.user_id}`);
    return { success: true as const, data };
  } catch (error: any) {
    return { success: false as const, error: error.message as string };
  }
}
