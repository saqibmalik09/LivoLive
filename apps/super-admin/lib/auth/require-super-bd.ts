import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { normalizePortalRole } from '@/lib/permissions';
import type { PortalRole } from '@/lib/permissions';

export type StaffGateInfo = {
  authenticated?: boolean;
  user_id?: string;
  username?: string;
  short_id?: number;
  staff_id?: string;
  staff_role?: string;
  staff_code?: string;
  can_access_portal?: boolean;
  child_role?: string | null;
  is_super_bd?: boolean;
  super_bd_staff_id?: string;
};

export type PortalStaff = {
  id: string;
  role: PortalRole;
  staff_code: string;
  user_id: string;
  is_active: boolean;
};

/** Portal is Super Admin (`super_bd`) only. */
export async function requireSuperBd() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect('/login');
  }

  const { data: gate, error: gateError } = await supabase.rpc('get_my_staff_gate_info');
  const info = gate as StaffGateInfo | null;
  const role = normalizePortalRole(info?.staff_role) ?? info?.staff_role;

  if (
    gateError ||
    !info?.staff_id ||
    !info.is_super_bd ||
    role !== 'super_bd'
  ) {
    redirect('/access-denied');
  }

  return {
    supabase,
    user,
    staff: {
      id: info.staff_id,
      role: 'super_bd' as PortalRole,
      staff_code: info.staff_code ?? '',
      user_id: user.id,
      is_active: true,
    } satisfies PortalStaff,
    gate: info,
  };
}

/** @deprecated Use requireSuperBd — portal is Super Admin only. */
export async function requireStaff() {
  return requireSuperBd();
}

export async function fetchStaffGateInfo(): Promise<StaffGateInfo | null> {
  const supabase = await createClient();
  const { data } = await supabase.rpc('get_my_staff_gate_info');
  return (data as StaffGateInfo) ?? null;
}

export async function fetchHierarchy(periodId?: string | null) {
  const { supabase } = await requireSuperBd();
  const { data, error } = await supabase.rpc('get_staff_portal_hierarchy', {
    p_period_id: periodId ?? null,
  });
  if (error) {
    const { data: fallback, error: fallbackError } = await supabase.rpc('get_super_bd_hierarchy');
    if (fallbackError) throw new Error(fallbackError.message);
    return fallback;
  }
  return data;
}

export async function fetchHostPeriodStats(hostId: string) {
  const { supabase } = await requireSuperBd();
  const { data, error } = await supabase.rpc('get_portal_host_period_stats', {
    p_host_id: hostId,
  });
  if (error) throw new Error(error.message);
  return (data || []) as import('@/lib/types').HostPeriodStat[];
}

export async function fetchApplications() {
  const { supabase } = await requireSuperBd();
  const { data, error } = await supabase.rpc('list_subtree_agency_applications');
  if (error) throw new Error(error.message);
  return (data || []) as import('@/lib/types').AgencyApplication[];
}

export async function fetchChartAnalytics(): Promise<import('@/lib/types').ChartAnalytics | null> {
  const { supabase } = await requireSuperBd();
  const { data, error } = await supabase.rpc('get_super_bd_chart_analytics');
  if (error) return null;
  return data as import('@/lib/types').ChartAnalytics;
}
