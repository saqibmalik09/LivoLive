"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { revalidatePath } from "next/cache";
import { periodToBdMonth } from "@/lib/salary-hub/constants";
export async function payOneAgency(periodId: string, agencyId: string) {
  try {
    const { data, error } = await supabaseAdmin.rpc("execute_one_agency_period_payout", {
      p_period_id: periodId.trim(),
      p_agency_id: agencyId.trim(),
    });
    if (error) throw error;
    if (data?.success === false) {
      return { success: false as const, error: data.message ?? "Agency pay failed" };
    }
    revalidatePath("/salary-hub");
    revalidatePath("/salary-runs");
    revalidatePath("/salary-audit");
    revalidatePath("/settings/bd-center");
    return { success: true as const, data };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
export async function payOneBd(periodIdOrMonth: string, staffId: string) {
  try {
    const ym = periodToBdMonth(periodIdOrMonth.trim());
    if (!/^\d{4}-\d{2}-[AB]$/i.test(ym) && !/^\d{4}-\d{2}$/.test(ym)) {
      return { success: false as const, error: `Invalid BD period from: ${periodIdOrMonth}` };
    }
    const { data, error } = await supabaseAdmin.rpc("execute_one_bd_monthly_payout", {
      p_period_yyyy_mm: ym,
      p_staff_id: staffId.trim(),
    });
    if (error) throw error;
    if (data?.success === false) {
      return { success: false as const, error: data.message ?? "BD pay failed" };
    }
    revalidatePath("/salary-hub");
    revalidatePath("/salary-runs");
    revalidatePath("/salary-audit");
    revalidatePath("/settings/bd-center");
    return { success: true as const, data, bdMonth: ym };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
