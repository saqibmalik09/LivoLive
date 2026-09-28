'use server';

import { supabaseAdmin } from '@/lib/supabase';
import { auditUserLabel, logAdminAction } from '@/lib/admin-audit';
import { getMasterActor } from '@/lib/master-session';
import { revalidatePath } from 'next/cache';

export type StaffCreateRole = 'super_bd' | 'county_admin' | 'assistant' | 'customer_service';

export async function findUserByQuery(query: string) {
  try {
    const trimmed = query.trim();
    if (!trimmed) return { success: false as const, error: 'Enter username or short ID' };

    let dbQuery = supabaseAdmin
      .from('users')
      .select('id, username, short_id, avatar_url')
      .limit(5);

    if (/^\d+$/.test(trimmed)) {
      dbQuery = dbQuery.eq('short_id', parseInt(trimmed, 10));
    } else {
      dbQuery = dbQuery.ilike('username', `%${trimmed}%`);
    }

    const { data, error } = await dbQuery;
    if (error) throw error;
    return { success: true as const, users: data || [] };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}

export async function createSuperBd(userId: string) {
  try {
    const actor = await getMasterActor();
    const { data, error } = await supabaseAdmin.rpc('create_business_staff', {
      p_target_user_id: userId,
      p_role: 'super_bd',
      p_parent_staff_id: null,
      p_created_by_user_id: actor.userId,
    });

    if (error) throw error;
    if (data?.success === false) throw new Error(data.message || 'Failed to create Super Admin');

    const who = await auditUserLabel(userId);
    await logAdminAction({
      action: 'user.promote_super_bd',
      targetType: 'user',
      targetId: userId,
      summary: `Made ${who} Super Admin`,
      metadata: {
        role: 'super_bd',
        staff: data,
        staff_id: data?.staff_id ?? null,
        operator_id: actor.operatorId,
      },
      actorUserId: actor.userId,
      actorLabel: actor.label,
    });

    revalidatePath('/staff');
    revalidatePath('/');
    return { success: true as const, data };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}

export async function createBusinessStaff(
  userId: string,
  role: Exclude<StaffCreateRole, 'super_bd'>,
  parentStaffId: string,
) {
  try {
    if (!userId) throw new Error('User required');
    if (!parentStaffId) throw new Error('Parent Super Admin is required');
    if (!['county_admin', 'assistant', 'customer_service'].includes(role)) {
      throw new Error('Invalid role');
    }

    const { data: parent, error: parentErr } = await supabaseAdmin
      .from('business_staff')
      .select('id, role, is_active')
      .eq('id', parentStaffId)
      .maybeSingle();
    if (parentErr) throw parentErr;
    if (!parent?.is_active || parent.role !== 'super_bd') {
      throw new Error('Parent must be an active Super Admin');
    }

    const actor = await getMasterActor();
    const { data, error } = await supabaseAdmin.rpc('create_business_staff', {
      p_target_user_id: userId,
      p_role: role,
      p_parent_staff_id: parentStaffId,
      p_created_by_user_id: actor.userId,
    });
    if (error) throw error;
    if (data?.success === false) throw new Error(data.message || 'Failed to create staff');

    const who = await auditUserLabel(userId);
    const action =
      role === 'county_admin'
        ? 'user.promote_county_admin'
        : role === 'assistant'
          ? 'user.promote_assistant'
          : 'user.promote_customer_service';
    const label =
      role === 'county_admin'
        ? 'Admin'
        : role === 'assistant'
          ? 'Assistant'
          : 'Customer Service';

    await logAdminAction({
      action,
      targetType: 'user',
      targetId: userId,
      summary: `Made ${who} ${label}`,
      metadata: {
        role,
        parent_staff_id: parentStaffId,
        staff: data,
        staff_id: data?.staff_id ?? null,
        operator_id: actor.operatorId,
      },
      actorUserId: actor.userId,
      actorLabel: actor.label,
    });

    revalidatePath('/staff');
    revalidatePath('/');
    return { success: true as const, data };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}

export async function deactivateStaff(staffId: string) {
  try {
    const { data: staffRow } = await supabaseAdmin
      .from('business_staff')
      .select('id, role, user_id')
      .eq('id', staffId)
      .maybeSingle();

    const { error } = await supabaseAdmin
      .from('business_staff')
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq('id', staffId);

    if (error) throw error;

    const who = staffRow?.user_id ? await auditUserLabel(staffRow.user_id) : staffId;
    await logAdminAction({
      action: 'staff.deactivate',
      targetType: 'staff',
      targetId: staffId,
      summary: `Deactivated ${staffRow?.role || 'staff'} role for ${who}`,
      metadata: { user_id: staffRow?.user_id, role: staffRow?.role },
    });

    revalidatePath('/staff');
    revalidatePath('/');
    return { success: true as const };
  } catch (error: any) {
    return { success: false as const, error: error.message };
  }
}
