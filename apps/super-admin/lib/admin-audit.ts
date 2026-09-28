import type { SupabaseClient } from '@supabase/supabase-js';

export async function logPortalAudit(
  supabase: SupabaseClient,
  input: {
    action: string;
    targetType?: string | null;
    targetId?: string | null;
    summary?: string | null;
    metadata?: Record<string, unknown>;
    success?: boolean;
  },
): Promise<void> {
  try {
    const { error } = await supabase.rpc('log_admin_audit', {
      p_action: input.action,
      p_target_type: input.targetType ?? null,
      p_target_id: input.targetId ?? null,
      p_summary: input.summary ?? null,
      p_metadata: input.metadata ?? {},
      p_success: input.success ?? true,
      p_source: 'sklive-super-admin',
    });
    if (error) console.error('[portal_audit]', error.message);
  } catch (e) {
    console.error('[portal_audit]', e);
  }
}

export const PORTAL_AUDIT_LABELS: Record<string, string> = {
  'user.ban': 'Blocked user',
  'user.unban': 'Unblocked user',
  'staff.create': 'Created staff member',
  'staff.deactivate': 'Deactivated staff',
  'agency.deactivate': 'Deactivated agency',
  'agency.create': 'Created agency',
  'agency.application_approve': 'Approved agency request',
  'agency.application_reject': 'Rejected agency request',
};
