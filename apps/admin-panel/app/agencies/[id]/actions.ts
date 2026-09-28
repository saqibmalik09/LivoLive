"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { logAdminAction } from "@/lib/admin-audit";
import { revalidatePath } from "next/cache";
export async function activateAgency(agencyId: string, confirmCode: string) {
  try {
    if (!agencyId) throw new Error("Agency required");
    const typed = String(confirmCode ?? "").trim();
    if (!typed) throw new Error("Type the agency code to confirm");
    const { data: agency, error: agencyErr } = await supabaseAdmin
      .from("agencies")
      .select("id, name, agency_code, is_active, owner_id")
      .eq("id", agencyId)
      .maybeSingle();
    if (agencyErr) throw agencyErr;
    if (!agency) throw new Error("Agency not found");
    if (agency.is_active !== false) throw new Error("Agency is already active");
    const expected = String(agency.agency_code ?? "").trim();
    if (!expected || typed.toLowerCase() !== expected.toLowerCase()) {
      throw new Error("Agency code does not match — activation cancelled");
    }
    const { error: updErr } = await supabaseAdmin
      .from("agencies")
      .update({ is_active: true })
      .eq("id", agencyId)
      .eq("is_active", false);
    if (updErr) throw updErr;
    if (agency.owner_id) {
      const { error: memErr } = await supabaseAdmin
        .from("agency_members")
        .upsert(
          { agency_id: agencyId, user_id: agency.owner_id },
          { onConflict: "agency_id,user_id", ignoreDuplicates: true },
        );
      if (
        memErr &&
        !String(memErr.message || "")
          .toLowerCase()
          .includes("unique")
      ) {
        console.warn("[activateAgency] owner member upsert", memErr.message);
      }
    }
    try {
      await supabaseAdmin.rpc("refresh_agency_rankings");
    } catch (e: any) {
      console.warn("[activateAgency] ranking refresh", e?.message || e);
    }
    await logAdminAction({
      action: "agency.activate",
      targetType: "agency",
      targetId: agencyId,
      summary: `Activated agency ${agency.name}`,
      metadata: {
        agency_name: agency.name,
        agency_code: agency.agency_code,
        owner_id: agency.owner_id,
      },
    });
    revalidatePath(`/agencies/${agencyId}`);
    revalidatePath("/agencies");
    revalidatePath("/salary-hub");
    return { success: true as const };
  } catch (error: any) {
    console.error("Error activating agency:", error);
    return { success: false as const, error: error.message as string };
  }
}
export async function deactivateAgency(agencyId: string, confirmCode: string) {
  try {
    if (!agencyId) throw new Error("Agency required");
    const typed = String(confirmCode ?? "").trim();
    if (!typed) throw new Error("Type the agency code to confirm");
    const { data: agency, error: agencyErr } = await supabaseAdmin
      .from("agencies")
      .select("id, name, agency_code, is_active, owner_id")
      .eq("id", agencyId)
      .maybeSingle();
    if (agencyErr) throw agencyErr;
    if (!agency) throw new Error("Agency not found");
    if (agency.is_active === false) throw new Error("Agency is already inactive");
    const expected = String(agency.agency_code ?? "").trim();
    if (!expected || typed.toLowerCase() !== expected.toLowerCase()) {
      throw new Error("Agency code does not match — deactivation cancelled");
    }
    const { data: members, error: memErr } = await supabaseAdmin
      .from("agency_members")
      .select("user_id")
      .eq("agency_id", agencyId);
    if (memErr) throw memErr;
    const hostIds = (members ?? []).map((m) => m.user_id as string).filter(Boolean);
    if (hostIds.length > 0) {
      const events = hostIds.map((userId) => ({
        agency_id: agencyId,
        user_id: userId,
        event_type: "removed" as const,
        actor_id: null,
      }));
      const { error: eventErr } = await supabaseAdmin.from("agency_member_events").insert(events);
      if (eventErr) throw eventErr;
      const { error: delErr } = await supabaseAdmin
        .from("agency_members")
        .delete()
        .eq("agency_id", agencyId);
      if (delErr) throw delErr;
    }
    const { error: appsErr } = await supabaseAdmin
      .from("agency_applications")
      .update({ status: "rejected" })
      .eq("agency_id", agencyId)
      .eq("status", "pending");
    if (appsErr) throw appsErr;
    const { error: updErr } = await supabaseAdmin
      .from("agencies")
      .update({ is_active: false })
      .eq("id", agencyId)
      .eq("is_active", true);
    if (updErr) throw updErr;
    await logAdminAction({
      action: "agency.deactivate",
      targetType: "agency",
      targetId: agencyId,
      summary: `Deactivated agency ${agency.name} and removed ${hostIds.length} host(s)`,
      metadata: {
        agency_name: agency.name,
        agency_code: agency.agency_code,
        owner_id: agency.owner_id,
        removed_host_ids: hostIds,
        removed_host_count: hostIds.length,
      },
    });
    revalidatePath(`/agencies/${agencyId}`);
    revalidatePath("/agencies");
    revalidatePath("/salary-hub");
    return {
      success: true as const,
      removedHostCount: hostIds.length,
    };
  } catch (error: any) {
    console.error("Error deactivating agency:", error);
    return { success: false as const, error: error.message as string };
  }
}
export async function permanentlyDeleteAgency(
  agencyId: string,
  confirmCode: string,
  confirmPhrase: string,
) {
  try {
    if (!agencyId) throw new Error("Agency required");
    const typed = String(confirmCode ?? "").trim();
    const phrase = String(confirmPhrase ?? "").trim();
    if (!typed) throw new Error("Type the agency code to confirm");
    if (phrase !== "DELETE") {
      throw new Error("Type DELETE in capitals to confirm permanent delete");
    }
    const { data: agency, error: agencyErr } = await supabaseAdmin
      .from("agencies")
      .select("id, name, agency_code, is_active, owner_id, created_at")
      .eq("id", agencyId)
      .maybeSingle();
    if (agencyErr) throw agencyErr;
    if (!agency) throw new Error("Agency not found");
    const expected = String(agency.agency_code ?? "").trim();
    if (!expected || typed.toLowerCase() !== expected.toLowerCase()) {
      throw new Error("Agency code does not match — permanent delete cancelled");
    }
    const { data: members, error: memErr } = await supabaseAdmin
      .from("agency_members")
      .select("user_id")
      .eq("agency_id", agencyId);
    if (memErr) throw memErr;
    const hostIds = (members ?? []).map((m) => m.user_id as string).filter(Boolean);
    if (hostIds.length > 0) {
      const events = hostIds.map((userId) => ({
        agency_id: agencyId,
        user_id: userId,
        event_type: "removed" as const,
        actor_id: null,
      }));
      const { error: eventErr } = await supabaseAdmin.from("agency_member_events").insert(events);
      if (eventErr) console.warn("[permanentDeleteAgency] events", eventErr.message);
      const { error: delMemErr } = await supabaseAdmin
        .from("agency_members")
        .delete()
        .eq("agency_id", agencyId);
      if (delMemErr) throw delMemErr;
    }
    await supabaseAdmin
      .from("agency_applications")
      .update({ status: "rejected" })
      .eq("agency_id", agencyId)
      .eq("status", "pending");
    await logAdminAction({
      action: "agency.permanent_delete",
      targetType: "agency",
      targetId: agencyId,
      summary: `Permanently deleted agency ${agency.name} (${agency.agency_code})`,
      metadata: {
        agency_name: agency.name,
        agency_code: agency.agency_code,
        owner_id: agency.owner_id,
        was_active: agency.is_active !== false,
        removed_host_ids: hostIds,
        removed_host_count: hostIds.length,
        agency_created_at: agency.created_at,
      },
    });
    const { error: delErr } = await supabaseAdmin.from("agencies").delete().eq("id", agencyId);
    if (delErr) throw delErr;
    revalidatePath("/agencies");
    revalidatePath("/salary-hub");
    revalidatePath(`/agencies/${agencyId}`);
    return { success: true as const, removedHostCount: hostIds.length };
  } catch (error: any) {
    console.error("Error permanently deleting agency:", error);
    return { success: false as const, error: error.message as string };
  }
}
export async function approveHost(applicationId: string) {
  try {
    const { data: app, error: fetchError } = await supabaseAdmin
      .from("agency_applications")
      .select("*")
      .eq("id", applicationId)
      .single();
    if (fetchError) throw fetchError;
    const { error: memberError } = await supabaseAdmin.from("agency_members").insert({
      agency_id: app.agency_id,
      user_id: app.user_id,
    });
    if (memberError && !memberError.message.includes("unique")) throw memberError;
    const { error } = await supabaseAdmin
      .from("agency_applications")
      .update({ status: "approved" })
      .eq("id", applicationId);
    if (error) throw error;
    await logAdminAction({
      action: "agency.host_approve",
      targetType: "agency_application",
      targetId: applicationId,
      summary: `Approved host join`,
      metadata: { user_id: app.user_id, agency_id: app.agency_id },
    });
    revalidatePath("/agencies");
    return { success: true };
  } catch (error: any) {
    console.error("Error approving host:", error);
    return { success: false, error: error.message };
  }
}
export async function rejectHost(applicationId: string) {
  try {
    const { data: app } = await supabaseAdmin
      .from("agency_applications")
      .select("user_id, agency_id")
      .eq("id", applicationId)
      .maybeSingle();
    const { error } = await supabaseAdmin
      .from("agency_applications")
      .update({ status: "rejected" })
      .eq("id", applicationId);
    if (error) throw error;
    await logAdminAction({
      action: "agency.host_reject",
      targetType: "agency_application",
      targetId: applicationId,
      summary: `Rejected host join`,
      metadata: { user_id: app?.user_id, agency_id: app?.agency_id },
    });
    revalidatePath("/agencies");
    return { success: true };
  } catch (error: any) {
    console.error("Error rejecting host:", error);
    return { success: false, error: error.message };
  }
}
