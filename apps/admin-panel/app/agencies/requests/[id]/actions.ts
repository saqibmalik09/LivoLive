"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { auditUserLabel, logAdminAction } from "@/lib/admin-audit";
import { revalidatePath } from "next/cache";
export async function approveAgencyRequest(
  applicationId: string,
  userId: string,
  realName: string,
) {
  try {
    const { data, error: rpcError } = await supabaseAdmin.rpc("approve_agency_application", {
      p_application_id: applicationId,
      p_approver_user_id: null,
      p_is_official: true,
    });
    if (rpcError) throw rpcError;
    if (data?.success === false) throw new Error(data.message || "Approval failed");
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "agency.application_approve",
      targetType: "agency_application",
      targetId: applicationId,
      summary: `Approved agency request for ${who}${realName ? ` (${realName})` : ""}`,
      metadata: { user_id: userId, real_name: realName || null },
    });
    revalidatePath("/agencies");
    return { success: true };
  } catch (error: any) {
    console.error("Error approving agency request:", error);
    return { success: false, error: error.message };
  }
}
export async function rejectAgencyRequest(applicationId: string) {
  try {
    const { data, error: rpcError } = await supabaseAdmin.rpc("reject_agency_application", {
      p_application_id: applicationId,
      p_approver_user_id: null,
      p_is_official: true,
    });
    if (rpcError) throw rpcError;
    if (data?.success === false) throw new Error(data.message || "Rejection failed");
    await logAdminAction({
      action: "agency.application_reject",
      targetType: "agency_application",
      targetId: applicationId,
      summary: `Rejected agency request`,
      metadata: { application_id: applicationId },
    });
    revalidatePath("/agencies");
    return { success: true };
  } catch (error: any) {
    console.error("Error rejecting agency request:", error);
    return { success: false, error: error.message };
  }
}
