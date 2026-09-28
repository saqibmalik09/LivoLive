"use server";
import { revalidatePath } from "next/cache";
import { supabaseAdmin } from "@/lib/supabase";
import { auditUserLabel, logAdminAction } from "@/lib/admin-audit";
import {
  hashPassword,
  isValidMasterPassword,
  isValidMasterUsername,
  normalizeMasterUsername,
} from "@/lib/master-password";
import {
  getOperatorTree,
  getOperatorTreeTotalsBatch,
  type OperatorTree,
  type OperatorTreeTotals,
} from "@/lib/master-operator-tree";
export type MasterOperatorRow = {
  id: string;
  user_id: string;
  username: string;
  is_active: boolean;
  last_login_at: string | null;
  created_at: string;
  users: {
    username: string | null;
    short_id: number | null;
    avatar_url: string | null;
  } | null;
  totals?: OperatorTreeTotals;
};
const emptyTotals = (): OperatorTreeTotals => ({
  superAdmins: 0,
  countyAdmins: 0,
  bds: 0,
  assistants: 0,
  customerService: 0,
  agencies: 0,
  hosts: 0,
  directStaff: 0,
});
export async function listMasterOperators() {
  try {
    const { data, error } = await supabaseAdmin
      .from("master_panel_operators")
      .select(
        "id, user_id, username, is_active, last_login_at, created_at, users:user_id(username, short_id, avatar_url)",
      )
      .order("created_at", { ascending: false });
    if (error) throw error;
    const base: MasterOperatorRow[] = (data || []).map((row: any) => {
      const joined = row.users;
      const user = Array.isArray(joined) ? (joined[0] ?? null) : (joined ?? null);
      return {
        id: row.id,
        user_id: row.user_id,
        username: row.username,
        is_active: row.is_active,
        last_login_at: row.last_login_at,
        created_at: row.created_at,
        users: user,
      };
    });
    const totalsMap = await getOperatorTreeTotalsBatch(base.map((o) => o.user_id));
    const operators = base.map((op) => ({
      ...op,
      totals: totalsMap.get(op.user_id) ?? emptyTotals(),
    }));
    return { success: true as const, operators };
  } catch (error: any) {
    return {
      success: false as const,
      error: error.message as string,
      operators: [] as MasterOperatorRow[],
    };
  }
}
export async function getMasterOperatorDetail(operatorId: string): Promise<
  | {
      success: true;
      operator: MasterOperatorRow;
      tree: OperatorTree;
      recentAudit: any[];
      unattributedAudit: any[];
    }
  | {
      success: false;
      error: string;
    }
> {
  try {
    const { data: row, error } = await supabaseAdmin
      .from("master_panel_operators")
      .select(
        "id, user_id, username, is_active, last_login_at, created_at, users:user_id(username, short_id, avatar_url)",
      )
      .eq("id", operatorId)
      .maybeSingle();
    if (error) throw error;
    if (!row) return { success: false, error: "Operator not found" };
    const joined = (row as any).users;
    const user = Array.isArray(joined) ? (joined[0] ?? null) : (joined ?? null);
    const operator: MasterOperatorRow = {
      id: row.id,
      user_id: row.user_id,
      username: row.username,
      is_active: row.is_active,
      last_login_at: row.last_login_at,
      created_at: row.created_at,
      users: user,
    };
    const tree = await getOperatorTree(operator.user_id);
    const { data: recentAudit } = await supabaseAdmin
      .from("admin_audit_logs")
      .select("*")
      .eq("source", "sklive-master-pannel")
      .eq("actor_user_id", operator.user_id)
      .order("created_at", { ascending: false })
      .limit(40);
    const { data: unattributedAudit } = await supabaseAdmin
      .from("admin_audit_logs")
      .select("*")
      .eq("source", "sklive-master-pannel")
      .is("actor_user_id", null)
      .order("created_at", { ascending: false })
      .limit(20);
    return {
      success: true,
      operator: { ...operator, totals: tree.totals },
      tree,
      recentAudit: recentAudit || [],
      unattributedAudit: unattributedAudit || [],
    };
  } catch (error: any) {
    return { success: false, error: error.message as string };
  }
}
export async function backfillMasterOperatorCreatedBy() {
  try {
    const PROMOTE_ACTIONS = [
      "user.promote_super_bd",
      "user.promote_county_admin",
      "user.promote_assistant",
      "user.promote_customer_service",
      "user.promote_bd",
    ];
    const { data: audits, error } = await supabaseAdmin
      .from("admin_audit_logs")
      .select("id, action, target_type, target_id, actor_user_id, metadata")
      .eq("source", "sklive-master-pannel")
      .in("action", PROMOTE_ACTIONS)
      .not("actor_user_id", "is", null)
      .limit(2000);
    if (error) throw error;
    let updated = 0;
    let skipped = 0;
    for (const row of audits || []) {
      const actorUserId = row.actor_user_id as string | null;
      if (!actorUserId) {
        skipped += 1;
        continue;
      }
      const meta = (row.metadata || {}) as Record<string, any>;
      const staffFromMeta = meta?.staff?.staff_id || meta?.staff?.id || meta?.staff_id || null;
      let staffId: string | null = typeof staffFromMeta === "string" ? staffFromMeta : null;
      if (!staffId && row.target_type === "staff" && row.target_id) {
        staffId = row.target_id;
      }
      if (!staffId && row.target_type === "user" && row.target_id) {
        const { data: staffRows } = await supabaseAdmin
          .from("business_staff")
          .select("id, created_by_user_id, role, created_at")
          .eq("user_id", row.target_id)
          .order("created_at", { ascending: false })
          .limit(5);
        const roleHint =
          row.action === "user.promote_super_bd"
            ? "super_bd"
            : row.action === "user.promote_county_admin"
              ? "county_admin"
              : row.action === "user.promote_assistant"
                ? "assistant"
                : row.action === "user.promote_customer_service"
                  ? "customer_service"
                  : row.action === "user.promote_bd"
                    ? "bd"
                    : null;
        const match =
          (staffRows || []).find(
            (s) => !s.created_by_user_id && (!roleHint || s.role === roleHint),
          ) || (staffRows || []).find((s) => !s.created_by_user_id);
        staffId = match?.id ?? null;
        if (match?.created_by_user_id) {
          skipped += 1;
          continue;
        }
      }
      if (!staffId) {
        skipped += 1;
        continue;
      }
      const { data: staff } = await supabaseAdmin
        .from("business_staff")
        .select("id, created_by_user_id")
        .eq("id", staffId)
        .maybeSingle();
      if (!staff) {
        skipped += 1;
        continue;
      }
      if (staff.created_by_user_id) {
        skipped += 1;
        continue;
      }
      const { error: upErr } = await supabaseAdmin
        .from("business_staff")
        .update({ created_by_user_id: actorUserId })
        .eq("id", staffId)
        .is("created_by_user_id", null);
      if (upErr) {
        skipped += 1;
        continue;
      }
      updated += 1;
    }
    revalidatePath("/settings/master-panel");
    return { success: true as const, updated, skipped, scanned: (audits || []).length };
  } catch (error: any) {
    return { success: false as const, error: error.message as string };
  }
}
export async function findUserForMasterPanel(query: string) {
  try {
    const trimmed = query.trim();
    if (!trimmed) return { success: false as const, error: "Enter username or short ID" };
    let dbQuery = supabaseAdmin.from("users").select("id, username, short_id, avatar_url").limit(8);
    if (/^\d+$/.test(trimmed)) {
      dbQuery = dbQuery.eq("short_id", parseInt(trimmed, 10));
    } else {
      dbQuery = dbQuery.ilike("username", `%${trimmed}%`);
    }
    const { data, error } = await dbQuery;
    if (error) throw error;
    return { success: true as const, users: data || [] };
  } catch (error: any) {
    return { success: false as const, error: error.message as string };
  }
}
export async function createMasterOperator(input: {
  userId: string;
  username: string;
  password: string;
}) {
  try {
    const username = normalizeMasterUsername(input.username);
    if (!isValidMasterUsername(username)) {
      return {
        success: false as const,
        error: "Username: 3–32 chars, letters/numbers/underscore only",
      };
    }
    if (!isValidMasterPassword(input.password)) {
      return { success: false as const, error: "Password must be 8–128 characters" };
    }
    if (username === "master") {
      return { success: false as const, error: 'Username "master" is reserved' };
    }
    const { data: user, error: userErr } = await supabaseAdmin
      .from("users")
      .select("id, username, short_id")
      .eq("id", input.userId)
      .maybeSingle();
    if (userErr) throw userErr;
    if (!user) return { success: false as const, error: "User not found" };
    const password_hash = hashPassword(input.password);
    const { data, error } = await supabaseAdmin
      .from("master_panel_operators")
      .insert({
        user_id: input.userId,
        username,
        password_hash,
        is_active: true,
      })
      .select("id")
      .single();
    if (error) {
      if (error.code === "23505") {
        return {
          success: false as const,
          error: "This user already has access, or username is taken",
        };
      }
      throw error;
    }
    const who = await auditUserLabel(input.userId);
    await logAdminAction({
      action: "master_panel.operator_create",
      targetType: "user",
      targetId: input.userId,
      summary: `Granted Master Panel login "${username}" to ${who}`,
      metadata: { operator_id: data.id, login_username: username },
    });
    revalidatePath("/settings/master-panel");
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message as string };
  }
}
export async function resetMasterOperatorPassword(operatorId: string, password: string) {
  try {
    if (!isValidMasterPassword(password)) {
      return { success: false as const, error: "Password must be 8–128 characters" };
    }
    const { data: op, error: findErr } = await supabaseAdmin
      .from("master_panel_operators")
      .select("id, user_id, username")
      .eq("id", operatorId)
      .maybeSingle();
    if (findErr) throw findErr;
    if (!op) return { success: false as const, error: "Operator not found" };
    const { error } = await supabaseAdmin
      .from("master_panel_operators")
      .update({
        password_hash: hashPassword(password),
        updated_at: new Date().toISOString(),
      })
      .eq("id", operatorId);
    if (error) throw error;
    const who = await auditUserLabel(op.user_id);
    await logAdminAction({
      action: "master_panel.operator_password_reset",
      targetType: "user",
      targetId: op.user_id,
      summary: `Reset Master Panel password for ${who} (@${op.username})`,
      metadata: { operator_id: op.id, login_username: op.username },
    });
    revalidatePath("/settings/master-panel");
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message as string };
  }
}
export async function setMasterOperatorActive(operatorId: string, isActive: boolean) {
  try {
    const { data: op, error: findErr } = await supabaseAdmin
      .from("master_panel_operators")
      .select("id, user_id, username")
      .eq("id", operatorId)
      .maybeSingle();
    if (findErr) throw findErr;
    if (!op) return { success: false as const, error: "Operator not found" };
    const { error } = await supabaseAdmin
      .from("master_panel_operators")
      .update({
        is_active: isActive,
        updated_at: new Date().toISOString(),
      })
      .eq("id", operatorId);
    if (error) throw error;
    const who = await auditUserLabel(op.user_id);
    await logAdminAction({
      action: isActive ? "master_panel.operator_enable" : "master_panel.operator_disable",
      targetType: "user",
      targetId: op.user_id,
      summary: `${isActive ? "Enabled" : "Disabled"} Master Panel for ${who} (@${op.username})`,
      metadata: { operator_id: op.id, login_username: op.username },
    });
    revalidatePath("/settings/master-panel");
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message as string };
  }
}
