"use server";
import { supabaseAdmin } from "@/lib/supabase";
import { auditUserLabel, logAdminAction } from "@/lib/admin-audit";
import { revalidatePath } from "next/cache";
export async function createSuperBd(userId: string) {
  try {
    const { data, error } = await supabaseAdmin.rpc("create_business_staff", {
      p_target_user_id: userId,
      p_role: "super_bd",
      p_parent_staff_id: null,
      p_created_by_user_id: null,
    });
    if (error) throw error;
    if (data?.success === false) throw new Error(data.message || "Failed to create Super BD");
    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: "user.promote_super_bd",
      targetType: "user",
      targetId: userId,
      summary: `Made ${who} Super Admin`,
      metadata: { role: "super_bd", staff: data },
    });
    revalidatePath("/staff");
    return { success: true, data };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function deactivateStaff(staffId: string) {
  try {
    const { data: staffRow } = await supabaseAdmin
      .from("business_staff")
      .select("id, role, user_id")
      .eq("id", staffId)
      .maybeSingle();
    const { error } = await supabaseAdmin
      .from("business_staff")
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq("id", staffId);
    if (error) throw error;
    const who = staffRow?.user_id ? await auditUserLabel(staffRow.user_id) : staffId;
    await logAdminAction({
      action: "staff.deactivate",
      targetType: "staff",
      targetId: staffId,
      summary: `Deactivated ${staffRow?.role || "staff"} role for ${who}`,
      metadata: { user_id: staffRow?.user_id, role: staffRow?.role },
    });
    revalidatePath("/staff");
    revalidatePath(`/staff/${staffId}`);
    return { success: true };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
export async function findUserByQuery(query: string) {
  try {
    const trimmed = query.trim();
    if (!trimmed) return { success: false, error: "Enter username or short ID" };
    let dbQuery = supabaseAdmin.from("users").select("id, username, short_id, avatar_url").limit(5);
    if (/^\d+$/.test(trimmed)) {
      dbQuery = dbQuery.eq("short_id", parseInt(trimmed, 10));
    } else {
      dbQuery = dbQuery.ilike("username", `%${trimmed}%`);
    }
    const { data, error } = await dbQuery;
    if (error) throw error;
    return { success: true, users: data || [] };
  } catch (error: any) {
    return { success: false, error: error.message };
  }
}
