"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { logAdminAction } from "@/lib/admin-audit";
import { revalidatePath } from "next/cache";
export async function processWithdrawal(
  withdrawalId: string,
  action: "approve" | "reject" | "complete",
  note?: string,
) {
  try {
    const { data, error } = await supabaseAdmin.rpc("admin_process_withdrawal", {
      p_withdrawal_id: withdrawalId,
      p_action: action,
      p_note: note || null,
    });
    if (error) {
      return { success: false, error: error.message };
    }
    const result = data as {
      success?: boolean;
      message?: string;
    };
    if (result && result.success === false) {
      return { success: false, error: result.message || "Failed" };
    }
    await logAdminAction({
      action: "withdrawal.process",
      targetType: "withdrawal",
      targetId: withdrawalId,
      summary: `Withdrawal ${action}`,
      metadata: { withdrawal_action: action, note: note || null },
    });
    revalidatePath("/withdrawals");
    return { success: true, data: result };
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return { success: false, error: message };
  }
}
