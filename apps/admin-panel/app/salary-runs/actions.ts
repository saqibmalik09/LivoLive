"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
import { getPeriodSalaryOverview, resolveBdPeriodId } from "@/lib/salary-hub/queries";
export async function fetchPeriodSalaryOverview(periodId: string) {
  try {
    const data = await getPeriodSalaryOverview(periodId);
    return { success: true as const, data };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function previewSalaryPeriod(periodId: string) {
  try {
    const { data, error } = await supabaseAdmin.rpc("preview_salary_period", {
      p_period_id: periodId,
    });
    if (error) throw error;
    return { success: true, data };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function calculateSalaryPeriod(periodId: string) {
  try {
    const { data, error } = await supabaseAdmin.rpc("calculate_salary_period", {
      p_period_id: periodId,
    });
    if (error) throw error;
    if (data?.success === false) return { success: false, error: data.message };
    revalidatePath("/salary-runs");
    return { success: true, data };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function executeSalaryPayout(periodId: string) {
  try {
    const { data, error } = await supabaseAdmin.rpc("execute_salary_payout_batch", {
      p_period_id: periodId,
    });
    if (error) throw error;
    if (data?.success === false) return { success: false, error: data.message };
    revalidatePath("/salary-runs");
    return { success: true, data };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function executeBdSalaryPayout(periodId: string) {
  try {
    const ym = await resolveBdPeriodId(periodId);
    if (!/^\d{4}-\d{2}-[ABM]$/i.test(ym) && !/^\d{4}-\d{2}$/.test(ym)) {
      return {
        success: false as const,
        error: `Invalid BD period from: ${periodId}`,
      };
    }
    const { data, error } = await supabaseAdmin.rpc("execute_bd_monthly_payout", {
      p_period_yyyy_mm: ym,
    });
    if (error) throw error;
    if (data?.success === false) {
      return {
        success: false as const,
        error: data.message ?? "BD payout failed",
      };
    }
    revalidatePath("/salary-runs");
    revalidatePath("/salary-hub");
    revalidatePath("/salary-audit");
    revalidatePath("/settings/bd-center");
    return { success: true as const, data, bdMonth: ym };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function executeAgencySalaryPayout(periodId: string) {
  try {
    const id = periodId.trim();
    if (!id) {
      return { success: false as const, error: "Period required" };
    }
    const { data, error } = await supabaseAdmin.rpc("execute_agency_period_payout", {
      p_period_id: id,
    });
    if (error) throw error;
    if (data?.success === false) {
      return {
        success: false as const,
        error: data.message ?? "Agency payout failed",
      };
    }
    revalidatePath("/salary-runs");
    revalidatePath("/salary-hub");
    revalidatePath("/salary-audit");
    revalidatePath("/settings/bd-center");
    return { success: true as const, data, periodId: id };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
