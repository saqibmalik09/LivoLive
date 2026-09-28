"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { logAdminAction } from "@/lib/admin-audit";
import { revalidatePath } from "next/cache";
export async function updateUserApplicationStatus(id: string, status: "approved" | "rejected") {
  try {
    const { data: application, error: fetchError } = await supabaseAdmin
      .from("user_applications")
      .select("*")
      .eq("id", id)
      .single();
    if (fetchError) throw fetchError;
    if (status === "approved" && application.type === "agency") {
      const { data, error: rpcError } = await supabaseAdmin.rpc("approve_agency_application", {
        p_application_id: id,
        p_approver_user_id: null,
        p_is_official: true,
      });
      if (rpcError) throw rpcError;
      if (data?.success === false) throw new Error(data.message || "Approval failed");
      await logAdminAction({
        action: "agency.application_approve",
        targetType: "agency_application",
        targetId: id,
        summary: `Approved agency application${application.agency_name ? ` "${application.agency_name}"` : ""}`,
        metadata: { user_id: application.user_id, type: application.type },
      });
      revalidatePath("/applications");
      return { success: true };
    }
    if (status === "rejected" && application.type === "agency") {
      const { data, error: rpcError } = await supabaseAdmin.rpc("reject_agency_application", {
        p_application_id: id,
        p_approver_user_id: null,
        p_is_official: true,
      });
      if (rpcError) throw rpcError;
      if (data?.success === false) throw new Error(data.message || "Rejection failed");
      await logAdminAction({
        action: "agency.application_reject",
        targetType: "agency_application",
        targetId: id,
        summary: `Rejected agency application${application.agency_name ? ` "${application.agency_name}"` : ""}`,
        metadata: { user_id: application.user_id, type: application.type },
      });
      revalidatePath("/applications");
      return { success: true };
    }
    const { error } = await supabaseAdmin.from("user_applications").update({ status }).eq("id", id);
    if (error) throw error;
    await logAdminAction({
      action: status === "approved" ? "agency.application_approve" : "agency.application_reject",
      targetType: "user_application",
      targetId: id,
      summary: `${status === "approved" ? "Approved" : "Rejected"} user application (${application.type || "unknown"})`,
      metadata: { user_id: application.user_id, type: application.type, status },
    });
    revalidatePath("/applications");
    return { success: true };
  } catch (error: any) {
    console.error("Error updating application:", error);
    return { success: false, error: error.message };
  }
}
export async function updateAgencyApplicationStatus(id: string, status: "approved" | "rejected") {
  try {
    const { data: application, error: fetchError } = await supabaseAdmin
      .from("agency_applications")
      .select("*")
      .eq("id", id)
      .single();
    if (fetchError) throw fetchError;
    if (status === "approved") {
      const { error: memberError } = await supabaseAdmin.from("agency_members").insert({
        agency_id: application.agency_id,
        user_id: application.user_id,
      });
      if (memberError && !memberError.message.includes("unique")) throw memberError;
    }
    const { error } = await supabaseAdmin
      .from("agency_applications")
      .update({ status })
      .eq("id", id);
    if (error) throw error;
    await logAdminAction({
      action: status === "approved" ? "agency.host_approve" : "agency.host_reject",
      targetType: "agency_application",
      targetId: id,
      summary: `${status === "approved" ? "Approved" : "Rejected"} host join request`,
      metadata: {
        user_id: application.user_id,
        agency_id: application.agency_id,
        status,
      },
    });
    revalidatePath("/applications");
    return { success: true };
  } catch (error: any) {
    console.error("Error updating agency application:", error);
    return { success: false, error: error.message };
  }
}
