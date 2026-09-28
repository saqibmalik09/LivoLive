'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { requireStaff } from '@/lib/auth/require-super-bd';
import { getPortalPermissions } from '@/lib/permissions';
import { logPortalAudit } from '@/lib/admin-audit';
import type { SearchUser } from '@/lib/types';

export async function searchUsers(query: string) {
  const { staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);
  if (!permissions.canCreateStaff) {
    return { success: false as const, error: 'Not authorized to create staff', users: [] as SearchUser[] };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc('search_users_for_staff_creation', {
    p_query: query,
  });
  if (error) return { success: false as const, error: error.message, users: [] as SearchUser[] };
  return { success: true as const, users: (data || []) as SearchUser[] };
}

export async function createStaffMember(targetUserId: string, role?: string) {
  const { supabase, staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);
  if (!permissions.canCreateStaff || permissions.creatableRoles.length === 0) {
    return { success: false, error: 'Not authorized to create staff' };
  }

  const pRole = (role || permissions.childRole) as string | null;
  if (!pRole || !permissions.creatableRoles.includes(pRole as (typeof permissions.creatableRoles)[number])) {
    return { success: false, error: 'Invalid role for your staff level' };
  }

  const { data, error } = await supabase.rpc('create_business_staff', {
    p_target_user_id: targetUserId,
    p_role: pRole,
    p_parent_staff_id: staff.id,
    p_created_by_user_id: staff.user_id,
  });
  if (error) return { success: false, error: error.message };
  const result = data as { success?: boolean; message?: string; staff_code?: string };
  if (result?.success === false) return { success: false, error: result.message || 'Failed' };

  await logPortalAudit(supabase, {
    action: 'staff.create',
    targetType: 'user',
    targetId: targetUserId,
    summary: `Created ${pRole} staff`,
    metadata: { role: pRole, staff_code: result.staff_code },
  });

  revalidatePath('/');
  revalidatePath('/team');
  return { success: true, staff_code: result.staff_code };
}

/** @deprecated use createStaffMember */
export async function createBdAdmin(targetUserId: string) {
  return createStaffMember(targetUserId);
}

export async function deactivateStaffMember(staffId: string) {
  const { supabase, staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);
  if (!permissions.canDeactivateStaff) {
    return { success: false, error: 'Only Super Admin can remove staff' };
  }
  const { data, error } = await supabase.rpc('super_bd_deactivate_staff', {
    p_staff_id: staffId,
  });
  if (error) return { success: false, error: error.message };
  const result = data as { success?: boolean; message?: string };
  if (result?.success === false) return { success: false, error: result.message || 'Failed' };

  await logPortalAudit(supabase, {
    action: 'staff.deactivate',
    targetType: 'staff',
    targetId: staffId,
    summary: `Deactivated staff member`,
  });

  revalidatePath('/team');
  revalidatePath('/');
  return { success: true };
}

export async function deactivateAgencyMember(agencyId: string) {
  const { supabase, staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);
  if (!permissions.canDeactivateAgency) {
    return { success: false, error: 'Only Super Admin can deactivate agencies' };
  }
  const { data, error } = await supabase.rpc('super_bd_deactivate_agency', {
    p_agency_id: agencyId,
  });
  if (error) return { success: false, error: error.message };
  const result = data as { success?: boolean; message?: string };
  if (result?.success === false) return { success: false, error: result.message || 'Failed' };

  await logPortalAudit(supabase, {
    action: 'agency.deactivate',
    targetType: 'agency',
    targetId: agencyId,
    summary: `Deactivated agency`,
  });

  revalidatePath('/agencies');
  revalidatePath('/');
  return { success: true };
}

export async function createAgencyForOwnerUnderBd(ownerUserId: string, bdRef: string) {
  const { supabase } = await requireStaff();
  const { data, error } = await supabase.rpc('create_agency_for_owner_under_bd', {
    p_owner_user_ref: ownerUserId.trim(),
    p_bd_ref: bdRef.trim(),
  });
  if (error) return { success: false as const, error: error.message };
  const result = data as {
    success?: boolean;
    message?: string;
    agency_code?: string;
    agency_id?: string;
    created?: boolean;
  };
  if (result?.success === false) {
    return { success: false as const, error: result.message || 'Failed' };
  }

  await logPortalAudit(supabase, {
    action: 'agency.create',
    targetType: 'agency',
    targetId: result.agency_id ?? null,
    summary: `Created agency for user ${ownerUserId} under BD ${bdRef}`,
    metadata: { agency_code: result.agency_code, created: result.created },
  });

  revalidatePath('/');
  revalidatePath('/my-agency');
  revalidatePath('/agencies');
  revalidatePath('/team');
  return {
    success: true as const,
    agency_code: result.agency_code,
    created: result.created === true,
    message: result.message,
  };
}

export async function createOwnAgency(agencyName: string) {
  const { supabase, user } = await requireStaff();
  const { data, error } = await supabase.rpc('create_staff_agency', {
    p_staff_user_id: user.id,
    p_agency_name: agencyName,
  });
  if (error) return { success: false, error: error.message };
  const result = data as { success?: boolean; message?: string; agency_code?: string };
  if (result?.success === false) return { success: false, error: result.message || 'Failed' };

  await logPortalAudit(supabase, {
    action: 'agency.create',
    targetType: 'user',
    targetId: user.id,
    summary: `Created agency "${agencyName}"`,
    metadata: { agency_code: result.agency_code },
  });

  revalidatePath('/');
  revalidatePath('/my-agency');
  revalidatePath('/agencies');
  return { success: true, agency_code: result.agency_code };
}

export async function approveApplication(applicationId: string) {
  const { supabase, user } = await requireStaff();
  const { data, error } = await supabase.rpc('approve_agency_application', {
    p_application_id: applicationId,
    p_approver_user_id: user.id,
    p_is_official: false,
  });
  if (error) return { success: false, error: error.message };
  const result = data as { success?: boolean; message?: string };
  if (result?.success === false) return { success: false, error: result.message || 'Failed' };

  await logPortalAudit(supabase, {
    action: 'agency.application_approve',
    targetType: 'agency_application',
    targetId: applicationId,
    summary: `Approved agency application`,
  });

  revalidatePath('/applications');
  revalidatePath('/');
  return { success: true };
}

export async function rejectApplication(applicationId: string) {
  const { supabase, user } = await requireStaff();
  const { data, error } = await supabase.rpc('reject_agency_application', {
    p_application_id: applicationId,
    p_approver_user_id: user.id,
    p_is_official: false,
  });
  if (error) return { success: false, error: error.message };
  const result = data as { success?: boolean; message?: string };
  if (result?.success === false) return { success: false, error: result.message || 'Failed' };

  await logPortalAudit(supabase, {
    action: 'agency.application_reject',
    targetType: 'agency_application',
    targetId: applicationId,
    summary: `Rejected agency application`,
  });

  revalidatePath('/applications');
  revalidatePath('/');
  return { success: true };
}

/** Super Admin only — ban/unban users in subtree. No PII returned. */
export async function setSubtreeUserBanned(
  targetUserId: string,
  banned: boolean,
  banReason?: string | null,
) {
  const { supabase, staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);
  if (!permissions.canBanUnban) {
    return { success: false, error: 'Only Super Admin can ban/unban' };
  }
  const note = banned ? (banReason?.trim() || null) : null;
  const { data, error } = await supabase.rpc('super_bd_set_user_banned', {
    p_target_user_id: targetUserId,
    p_banned: banned,
    p_ban_reason: note,
  });
  if (error) return { success: false, error: error.message };
  const result = data as { success?: boolean; message?: string };
  if (result?.success === false) return { success: false, error: result.message || 'Failed' };

  await logPortalAudit(supabase, {
    action: banned ? 'user.ban' : 'user.unban',
    targetType: 'user',
    targetId: targetUserId,
    summary: banned ? 'Blocked user' : 'Unblocked user',
    metadata: { is_banned: banned, ban_reason: note },
  });

  revalidatePath('/moderation');
  return { success: true };
}

export async function setUserVipLevelForUser(targetUserId: string, vipLevel: number) {
  const { supabase, staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);
  if (!permissions.canGrantVip) {
    return { success: false as const, error: 'Not authorized to grant VIP' };
  }

  const vLevel = Math.trunc(vipLevel);
  if (vLevel < 0 || vLevel > 4) {
    return { success: false as const, error: 'vipLevel must be 0..4' };
  }

  const { data, error } = await supabase.rpc('super_bd_set_user_vip', {
    p_target_user_id: targetUserId,
    p_vip_level: vLevel,
    p_days: 30,
    p_replace_expiry: false, // extend-if-active
  });

  if (error) return { success: false as const, error: error.message };
  const result = data as { success?: boolean; message?: string; vip_until?: string | null; vip_level?: number };
  if (result?.success === false) return { success: false as const, error: result.message || 'Failed' };

  await logPortalAudit(supabase, {
    action: vLevel === 0 ? 'user.vip_remove' : 'user.vip_set',
    targetType: 'user',
    targetId: targetUserId,
    summary: vLevel === 0 ? 'Removed VIP' : `Set VIP level ${vLevel} (30 days)`,
    metadata: {
      vip_level: vLevel,
      vip_days: 30,
      vip_until: result.vip_until ?? null,
    },
  });

  revalidatePath('/moderation');
  return {
    success: true as const,
    vip_level: vLevel,
    vip_until: result.vip_until ?? null,
  };
}

export async function removeUserVip(targetUserId: string) {
  // Keep explicit remove action for clearer audit / UI intent.
  return setUserVipLevelForUser(targetUserId, 0);
}

export async function searchUsersForBan(query: string) {
  const { staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);
  if (!permissions.canBanUnban) {
    return { success: false as const, error: 'Not authorized', users: [] as SearchUser[] };
  }
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('search_users_for_staff_creation', {
    p_query: query,
  });
  if (error) return { success: false as const, error: error.message, users: [] as SearchUser[] };
  // Keep username / short_id / ban status for moderation UI.
  const users = ((data || []) as SearchUser[]).map((u) => ({
    id: u.id,
    username: u.username,
    short_id: u.short_id,
    avatar_url: u.avatar_url,
    is_banned: u.is_banned === true,
    ban_reason: u.ban_reason ?? null,
  }));
  return { success: true as const, users };
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect('/login');
}
