import { supabaseAdmin } from '@/lib/supabase';
import { getMasterActor } from '@/lib/master-session';

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
  source?:
    | 'sklive-admin'
    | 'sklive-super-admin'
    | 'sklive-flutter'
    | 'sklive-master-pannel';
};

/** Fire-and-forget audit write — never throws to callers. */
export async function logAdminAction(input: AdminAuditInput): Promise<void> {
  try {
    let actorUserId = input.actorUserId ?? null;
    let actorLabel = input.actorLabel ?? null;

    if (actorUserId == null || !actorLabel) {
      try {
        const actor = await getMasterActor();
        actorUserId = actorUserId ?? actor.userId;
        actorLabel = actorLabel ?? actor.label;
      } catch {
        actorLabel = actorLabel ?? 'Master Panel';
      }
    }

    const { error } = await supabaseAdmin.from('admin_audit_logs').insert({
      source: input.source ?? 'sklive-master-pannel',
      actor_user_id: actorUserId,
      actor_staff_id: input.actorStaffId ?? null,
      actor_label: actorLabel ?? 'Master Panel',
      action: input.action,
      target_type: input.targetType ?? null,
      target_id: input.targetId ?? null,
      summary: input.summary ?? null,
      metadata: {
        ...(input.metadata ?? {}),
      },
      success: input.success ?? true,
    });
    if (error) console.error('[admin_audit]', error.message);
  } catch (e) {
    console.error('[admin_audit]', e);
  }
}

/** Best-effort display name for audit summaries. */
export async function auditUserLabel(userId: string): Promise<string> {
  try {
    const { data } = await supabaseAdmin
      .from('users')
      .select('username, short_id')
      .eq('id', userId)
      .maybeSingle();
    if (!data) return userId.slice(0, 8);
    return `${data.username || 'User'} (#${data.short_id ?? '—'})`;
  } catch {
    return userId.slice(0, 8);
  }
}

export const ADMIN_AUDIT_ACTION_LABELS: Record<string, string> = {
  'user.ban': 'Blocked user',
  'user.unban': 'Unblocked user',
  'user.device_ban': 'Banned device',
  'user.device_unban': 'Unbanned device',
  'user.promote_super_bd': 'Made Super Admin',
  'user.promote_county_admin': 'Made Admin',
  'user.promote_assistant': 'Made Assistant',
  'user.promote_customer_service': 'Made Customer Service',
  'staff.deactivate': 'Deactivated staff role',
  'agency.transfer_host': 'Transferred host between agencies',
  'agency.change_sponsor': 'Moved agency to another BD',
  'user.vip_set': 'Set VIP plan',
  'user.vip_remove': 'Removed VIP',
  'user.inventory_grant': 'Granted shop item',
};
