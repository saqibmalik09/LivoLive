import { supabaseAdmin } from "@/lib/supabase";
export type AdminAuditInput = {
  action: string;
  targetType?: string | null;
  targetId?: string | null;
  summary?: string | null;
  metadata?: Record<string, unknown>;
  success?: boolean;
  actorUserId?: string | null;
  actorStaffId?: string | null;
  actorLabel?: string | null;
  source?: "sklive-admin" | "sklive-super-admin" | "sklive-flutter" | "sklive-master-pannel";
};
export async function logAdminAction(input: AdminAuditInput): Promise<void> {
  try {
    const { error } = await supabaseAdmin.from("admin_audit_logs").insert({
      source: input.source ?? "sklive-admin",
      actor_user_id: input.actorUserId ?? null,
      actor_staff_id: input.actorStaffId ?? null,
      actor_label: input.actorLabel ?? "Platform Admin",
      action: input.action,
      target_type: input.targetType ?? null,
      target_id: input.targetId ?? null,
      summary: input.summary ?? null,
      metadata: input.metadata ?? {},
      success: input.success ?? true,
    });
    if (error) console.error("[admin_audit]", error.message);
  } catch (e) {
    console.error("[admin_audit]", e);
  }
}
export async function auditUserLabel(userId: string): Promise<string> {
  try {
    const { data } = await supabaseAdmin
      .from("users")
      .select("username, short_id")
      .eq("id", userId)
      .maybeSingle();
    if (!data) return userId.slice(0, 8);
    return `${data.username || "User"} (#${data.short_id ?? "—"})`;
  } catch {
    return userId.slice(0, 8);
  }
}
export const ADMIN_AUDIT_ACTION_LABELS: Record<string, string> = {
  "user.ban": "Blocked user",
  "user.unban": "Unblocked user",
  "user.reseller_enable": "Enabled reseller",
  "user.reseller_disable": "Disabled reseller",
  "user.promote_super_bd": "Made Super Admin",
  "user.promote_county_admin": "Made County Admin",
  "user.promote_assistant": "Made Assistant",
  "user.promote_customer_service": "Made Customer Service",
  "user.promote_bd": "Made BD",
  "user.inventory_grant": "Granted shop item",
  "staff.deactivate": "Deactivated staff role",
  "agency.application_approve": "Approved agency request",
  "agency.application_reject": "Rejected agency request",
  "agency.host_approve": "Approved host join",
  "agency.host_reject": "Rejected host join",
  "agency.create": "Created agency",
  "agency.assign_host": "Assigned host to agency",
  "agency.remove_host": "Removed host from agency",
  "agency.transfer_host": "Transferred host between agencies",
  "agency.change_sponsor": "Moved agency to another BD",
  "agency.deactivate": "Deactivated agency",
  "agency.permanent_delete": "Permanently deleted agency",
  "user.currency_update": "Updated user balance",
  "user.country_update": "Changed user country",
  "user.special_id": "Set special ID",
  "user.vip_set": "Set VIP plan",
  "user.vip_remove": "Removed VIP",
  "master_panel.operator_create": "Granted Master Panel login",
  "master_panel.operator_password_reset": "Reset Master Panel password",
  "master_panel.operator_enable": "Enabled Master Panel login",
  "master_panel.operator_disable": "Disabled Master Panel login",
  "withdrawal.process": "Processed withdrawal",
  "real_name.review": "Reviewed real-name KYC",
  "targets.reset_all": "Reset all period targets",
  "targets.reset_user": "Reset user period targets",
};
