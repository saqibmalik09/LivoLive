import 'server-only';

import { supabaseAdmin } from '@/lib/supabase';
import {
  type SalaryHubRole,
  ROLE_LABELS,
  currentPeriodId,
  prevPeriodId,
  periodOptions,
  periodBounds,
  SALARY_HUB_ROLES,
  periodToBdMonth,
} from '@/lib/salary-hub/constants';
import {
  estimateAgencyUsd,
  estimateHostUsd,
  loadSalarySettings,
} from '@/lib/salary-hub/salary-calc';
import type { PeriodSalaryOverview } from '@/lib/salary-hub/types';

export type { PeriodSalaryOverview } from '@/lib/salary-hub/types';

export type { SalaryHubRole };
export {
  ROLE_LABELS,
  currentPeriodId,
  prevPeriodId,
  periodOptions,
  periodBounds,
  SALARY_HUB_ROLES,
};

export type StaffListItem = {
  id: string;
  role: string;
  staff_code: string | null;
  is_active: boolean;
  parent_staff_id: string | null;
  username: string;
  short_id: string | null;
  avatar_url: string | null;
  childStaffCount: number;
  agencyCount: number;
  hostCount: number;
  /** Present when enriched for BD pay UI */
  bdPayableUsd?: number;
  bdSettlementPaid?: boolean;
};

export type AgencyListItem = {
  id: string;
  name: string;
  agency_code: string | null;
  is_active: boolean;
  owner_username: string | null;
  sponsor_code: string | null;
  sponsor_username: string | null;
  hostCount: number;
  periodCharm: number;
  estimatedUsd: number;
  charmSalaryUsd: number;
  agentSalaryUsd: number;
  salaryLevel: number;
  settlementPaid: boolean;
};

export type HostListItem = {
  user_id: string;
  agency_id: string;
  agency_name: string;
  role: string;
  username: string;
  short_id: string | null;
  avatar_url: string | null;
  periodCharm: number;
  periodDiamonds: number;
  hostTierUsd: number;
  charmSalaryUsd: number;
  estimatedUsd: number;
  hostTierName: string | null;
  charmLevel: number;
};

type StaffRow = {
  id: string;
  role: string;
  staff_code: string | null;
  is_active: boolean;
  parent_staff_id: string | null;
  users: { username?: string; short_id?: string; avatar_url?: string } | null;
};

async function loadAllStaff(): Promise<StaffRow[]> {
  const { data } = await supabaseAdmin
    .from('business_staff')
    .select(
      `
      id,
      role,
      staff_code,
      is_active,
      parent_staff_id,
      users:user_id (username, short_id, avatar_url)
    `,
    )
    .order('created_at', { ascending: false });
  return (data || []).map((row: any) => ({
    ...row,
    users: Array.isArray(row.users) ? row.users[0] ?? null : row.users,
  }));
}

function collectDescendantStaffIds(
  rootId: string,
  all: StaffRow[],
): string[] {
  const childrenByParent = new Map<string, string[]>();
  for (const s of all) {
    if (!s.parent_staff_id) continue;
    const list = childrenByParent.get(s.parent_staff_id) || [];
    list.push(s.id);
    childrenByParent.set(s.parent_staff_id, list);
  }
  const out: string[] = [];
  const stack = [rootId];
  while (stack.length) {
    const id = stack.pop()!;
    const kids = childrenByParent.get(id) || [];
    for (const kid of kids) {
      out.push(kid);
      stack.push(kid);
    }
  }
  return out;
}

async function agencyIdsForStaffIds(staffIds: string[]): Promise<string[]> {
  if (staffIds.length === 0) return [];
  const { data } = await supabaseAdmin
    .from('agencies')
    .select('id, sponsor_staff_id')
    .in('sponsor_staff_id', staffIds);
  return (data || []).map((a) => a.id as string);
}

async function hostCountsByAgency(
  agencyIds: string[],
): Promise<Record<string, number>> {
  const map: Record<string, number> = {};
  if (agencyIds.length === 0) return map;
  const { data } = await supabaseAdmin
    .from('agency_members')
    .select('agency_id')
    .in('agency_id', agencyIds);
  for (const row of data || []) {
    const id = row.agency_id as string;
    map[id] = (map[id] || 0) + 1;
  }
  return map;
}

function normalizeSearchQuery(q?: string | null): string {
  return (q || '').trim().toLowerCase();
}

/** Match agency / staff / host list rows against a free-text search. */
export function matchesSalarySearch(
  q: string | null | undefined,
  ...fields: (string | number | null | undefined)[]
): boolean {
  const needle = normalizeSearchQuery(q);
  if (!needle) return true;
  return fields.some((f) => {
    if (f == null || f === '') return false;
    return String(f).toLowerCase().includes(needle);
  });
}

function escapeIlike(raw: string): string {
  return raw.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_');
}

export async function listStaffByRole(
  role: 'super_bd' | 'bd_admin' | 'bd',
  q?: string | null,
): Promise<StaffListItem[]> {
  const all = await loadAllStaff();
  const filtered = all.filter((s) => {
    const roleMatch =
      role === 'bd_admin'
        ? s.role === 'bd_admin' || s.role === 'county_admin'
        : s.role === role;
    if (!roleMatch) return false;
    return matchesSalarySearch(
      q,
      s.users?.username,
      s.users?.short_id,
      s.staff_code,
      s.role,
    );
  });

  const { data: agencies } = await supabaseAdmin
    .from('agencies')
    .select('id, sponsor_staff_id');
  const agenciesBySponsor = new Map<string, string[]>();
  for (const a of agencies || []) {
    if (!a.sponsor_staff_id) continue;
    const list = agenciesBySponsor.get(a.sponsor_staff_id) || [];
    list.push(a.id);
    agenciesBySponsor.set(a.sponsor_staff_id, list);
  }

  const allAgencyIds = (agencies || []).map((a) => a.id as string);
  const hostMap = await hostCountsByAgency(allAgencyIds);

  const directChildCount = all.reduce<Record<string, number>>((acc, s) => {
    if (s.parent_staff_id) {
      acc[s.parent_staff_id] = (acc[s.parent_staff_id] || 0) + 1;
    }
    return acc;
  }, {});

  return filtered.map((s) => {
    const descendantIds = collectDescendantStaffIds(s.id, all);
    const treeStaffIds = [s.id, ...descendantIds];
    const agencyIds = treeStaffIds.flatMap(
      (id) => agenciesBySponsor.get(id) || [],
    );
    const uniqueAgencyIds = Array.from(new Set(agencyIds));
    const hosts = uniqueAgencyIds.reduce(
      (sum, aid) => sum + (hostMap[aid] || 0),
      0,
    );

    return {
      id: s.id,
      role: s.role,
      staff_code: s.staff_code,
      is_active: s.is_active,
      parent_staff_id: s.parent_staff_id,
      username: s.users?.username || 'Staff',
      short_id: s.users?.short_id ?? null,
      avatar_url: s.users?.avatar_url ?? null,
      childStaffCount: directChildCount[s.id] || 0,
      agencyCount: uniqueAgencyIds.length,
      hostCount: hosts,
    };
  });
}

/** Attach BD monthly payable + paid flag for Salary Hub cards. */
export async function enrichBdStaffPayStatus(
  staff: StaffListItem[],
  periodYyyyMm: string,
): Promise<StaffListItem[]> {
  if (staff.length === 0) return staff;
  const ids = staff.map((s) => s.id);

  const [{ data: stats }, { data: settlements }] = await Promise.all([
    supabaseAdmin
      .from('bd_staff_monthly_stats')
      .select(
        'staff_id, est_total_usd, est_basic_usd, est_commission_usd, est_new_bd_usd, work_days, work_hours',
      )
      .eq('period_yyyy_mm', periodYyyyMm)
      .in('staff_id', ids),
    supabaseAdmin
      .from('bd_staff_settlements')
      .select('staff_id, status, total_usd')
      .eq('period_yyyy_mm', periodYyyyMm)
      .in('staff_id', ids),
  ]);

  const paid = new Set<string>();
  for (const s of settlements || []) {
    if (s.status === 'paid') paid.add(s.staff_id as string);
  }

  const payableByStaff: Record<string, number> = {};
  for (const row of stats || []) {
    const days = Number(row.work_days || 0) || 0;
    const hours = Number(row.work_hours || 0) || 0;
    let total = Number(row.est_total_usd || 0) || 0;
    // Match bd_center_settings defaults (10 days / 30 hours per half-period)
    if (days < 10 || hours < 30) {
      total =
        (Number(row.est_commission_usd || 0) || 0) +
        (Number(row.est_new_bd_usd || 0) || 0);
    }
    payableByStaff[row.staff_id as string] = total;
  }

  return staff.map((s) => ({
    ...s,
    bdPayableUsd: payableByStaff[s.id] ?? 0,
    bdSettlementPaid: paid.has(s.id),
  }));
}

/** All staff roles matching search (used when Salary Hub has a global `q`). */
export async function listStaffMatching(
  q: string | null | undefined,
): Promise<StaffListItem[]> {
  const needle = normalizeSearchQuery(q);
  if (!needle) return [];

  const all = await loadAllStaff();
  const roleSet = new Set(['super_bd', 'bd_admin', 'bd']);
  const filtered = all.filter((s) => {
    if (!roleSet.has(s.role)) return false;
    return matchesSalarySearch(
      q,
      s.users?.username,
      s.users?.short_id,
      s.staff_code,
      s.role,
    );
  });

  const { data: agencies } = await supabaseAdmin
    .from('agencies')
    .select('id, sponsor_staff_id');
  const agenciesBySponsor = new Map<string, string[]>();
  for (const a of agencies || []) {
    if (!a.sponsor_staff_id) continue;
    const list = agenciesBySponsor.get(a.sponsor_staff_id) || [];
    list.push(a.id);
    agenciesBySponsor.set(a.sponsor_staff_id, list);
  }

  const allAgencyIds = (agencies || []).map((a) => a.id as string);
  const hostMap = await hostCountsByAgency(allAgencyIds);

  const directChildCount = all.reduce<Record<string, number>>((acc, s) => {
    if (s.parent_staff_id) {
      acc[s.parent_staff_id] = (acc[s.parent_staff_id] || 0) + 1;
    }
    return acc;
  }, {});

  return filtered.map((s) => {
    const descendantIds = collectDescendantStaffIds(s.id, all);
    const treeStaffIds = [s.id, ...descendantIds];
    const agencyIds = treeStaffIds.flatMap(
      (id) => agenciesBySponsor.get(id) || [],
    );
    const uniqueAgencyIds = Array.from(new Set(agencyIds));
    const hosts = uniqueAgencyIds.reduce(
      (sum, aid) => sum + (hostMap[aid] || 0),
      0,
    );

    return {
      id: s.id,
      role: s.role,
      staff_code: s.staff_code,
      is_active: s.is_active,
      parent_staff_id: s.parent_staff_id,
      username: s.users?.username || 'Staff',
      short_id: s.users?.short_id ?? null,
      avatar_url: s.users?.avatar_url ?? null,
      childStaffCount: directChildCount[s.id] || 0,
      agencyCount: uniqueAgencyIds.length,
      hostCount: hosts,
    };
  });
}

export async function listAgencies(
  periodId: string,
  q?: string | null,
): Promise<AgencyListItem[]> {
  const settings = await loadSalarySettings();
  const { data: agencies } = await supabaseAdmin
    .from('agencies')
    .select(
      `
      id,
      name,
      agency_code,
      is_active,
      users:owner_id(username),
      sponsor:business_staff!sponsor_staff_id(
        staff_code,
        users:user_id(username)
      )
    `,
    )
    .order('created_at', { ascending: false });

  const ids = (agencies || []).map((a: any) => a.id as string);
  const hostMap = await hostCountsByAgency(ids);

  const charmByAgency: Record<string, number> = {};
  const hostCharmsByAgency: Record<string, number[]> = {};
  if (ids.length > 0) {
    const { data: members } = await supabaseAdmin
      .from('agency_members')
      .select('agency_id, user_id')
      .in('agency_id', ids);
    const userIds = Array.from(
      new Set((members || []).map((m) => m.user_id as string)),
    );
    const charmByUser: Record<string, number> = {};
    if (userIds.length > 0) {
      const { data: stats } = await supabaseAdmin
        .from('host_period_stats')
        .select('user_id, charm_points')
        .eq('period_id', periodId)
        .in('user_id', userIds);
      for (const s of stats || []) {
        charmByUser[s.user_id as string] = Number(s.charm_points || 0) || 0;
      }
    }
    for (const m of members || []) {
      const aid = m.agency_id as string;
      const hostCharm = charmByUser[m.user_id as string] || 0;
      charmByAgency[aid] =
        (charmByAgency[aid] || 0) + hostCharm;
      (hostCharmsByAgency[aid] ??= []).push(hostCharm);
    }
  }

  const paidAgency = new Set<string>();
  if (ids.length > 0) {
    const { data: settlements } = await supabaseAdmin
      .from('agency_period_settlements')
      .select('agency_id')
      .eq('period_id', periodId)
      .eq('status', 'paid')
      .in('agency_id', ids);
    for (const s of settlements || []) {
      paidAgency.add(s.agency_id as string);
    }
  }

  const mapped = (agencies || []).map((a: any) => {
    const owner = Array.isArray(a.users) ? a.users[0] : a.users;
    const sponsor = Array.isArray(a.sponsor) ? a.sponsor[0] : a.sponsor;
    const sponsorUser = sponsor
      ? Array.isArray(sponsor.users)
        ? sponsor.users[0]
        : sponsor.users
      : null;
    const totalCharm = charmByAgency[a.id] || 0;
    const est = estimateAgencyUsd(settings, hostCharmsByAgency[a.id] || []);
    return {
      id: a.id,
      name: a.name || 'Agency',
      agency_code: a.agency_code,
      is_active: a.is_active !== false,
      owner_username: owner?.username ?? null,
      sponsor_code: sponsor?.staff_code ?? null,
      sponsor_username: sponsorUser?.username ?? null,
      hostCount: hostMap[a.id] || 0,
      periodCharm: totalCharm,
      estimatedUsd: est.totalUsd,
      charmSalaryUsd: est.charmSalaryUsd,
      agentSalaryUsd: est.agentSalaryUsd,
      salaryLevel: est.level,
      settlementPaid: paidAgency.has(a.id),
    };
  });

  const needle = normalizeSearchQuery(q);
  if (!needle) return mapped;
  return mapped.filter((a) =>
    matchesSalarySearch(
      q,
      a.name,
      a.agency_code,
      a.owner_username,
      a.sponsor_username,
      a.sponsor_code,
    ),
  );
}

export async function listHosts(
  periodId: string,
  q?: string | null,
): Promise<HostListItem[]> {
  const settings = await loadSalarySettings();
  const needle = normalizeSearchQuery(q);

  let members: any[] | null = null;

  if (needle) {
    const like = `%${escapeIlike(needle)}%`;
    const matchedUserIds = new Set<string>();
    const matchedAgencyIds = new Set<string>();

    if (/^\d+$/.test(needle)) {
      const { data: byShort } = await supabaseAdmin
        .from('users')
        .select('id')
        .eq('short_id', parseInt(needle, 10))
        .limit(20);
      for (const u of byShort || []) matchedUserIds.add(u.id as string);
    }

    const [{ data: users }, { data: agenciesByName }, { data: agenciesByCode }] =
      await Promise.all([
        supabaseAdmin
          .from('users')
          .select('id')
          .ilike('username', like)
          .limit(80),
        supabaseAdmin
          .from('agencies')
          .select('id')
          .ilike('name', like)
          .limit(40),
        supabaseAdmin
          .from('agencies')
          .select('id')
          .ilike('agency_code', like)
          .limit(40),
      ]);
    for (const u of users || []) matchedUserIds.add(u.id as string);
    for (const a of agenciesByName || []) matchedAgencyIds.add(a.id as string);
    for (const a of agenciesByCode || []) matchedAgencyIds.add(a.id as string);

    if (matchedUserIds.size === 0 && matchedAgencyIds.size === 0) {
      return [];
    }

    const userIdList = Array.from(matchedUserIds);
    const agencyIdList = Array.from(matchedAgencyIds);
    const orParts: string[] = [];
    if (userIdList.length) orParts.push(`user_id.in.(${userIdList.join(',')})`);
    if (agencyIdList.length) {
      orParts.push(`agency_id.in.(${agencyIdList.join(',')})`);
    }

    const { data } = await supabaseAdmin
      .from('agency_members')
      .select(
        `
      user_id,
      agency_id,
      role,
      agencies:agency_id(name),
      users:user_id(username, short_id, avatar_url)
    `,
      )
      .or(orParts.join(','))
      .order('created_at', { ascending: false })
      .limit(100);
    members = data;
  } else {
    const { data } = await supabaseAdmin
      .from('agency_members')
      .select(
        `
      user_id,
      agency_id,
      role,
      agencies:agency_id(name),
      users:user_id(username, short_id, avatar_url)
    `,
      )
      .order('created_at', { ascending: false })
      .limit(200);
    members = data;
  }

  const userIds = (members || []).map((m: any) => m.user_id as string);
  const statsByUser: Record<
    string,
    {
      charm_points: number;
      total_diamonds: number;
      total_on_mic_seconds: number;
      valid_days: number;
    }
  > = {};

  if (userIds.length > 0) {
    const { data: stats } = await supabaseAdmin
      .from('host_period_stats')
      .select(
        'user_id, charm_points, total_diamonds, total_on_mic_seconds, valid_days',
      )
      .eq('period_id', periodId)
      .in('user_id', userIds);

    for (const t of stats || []) {
      statsByUser[t.user_id as string] = {
        charm_points: Number(t.charm_points || 0) || 0,
        total_diamonds: Number(t.total_diamonds || 0) || 0,
        total_on_mic_seconds: Number(t.total_on_mic_seconds || 0) || 0,
        valid_days: Number(t.valid_days || 0) || 0,
      };
    }
  }

  return (members || []).map((m: any) => {
    const agency = Array.isArray(m.agencies) ? m.agencies[0] : m.agencies;
    const user = Array.isArray(m.users) ? m.users[0] : m.users;
    const st = statsByUser[m.user_id] || null;
    const est = estimateHostUsd(settings, st);
    return {
      user_id: m.user_id,
      agency_id: m.agency_id,
      agency_name: agency?.name || 'Agency',
      role: m.role || 'host',
      username: user?.username || 'Host',
      short_id: user?.short_id ?? null,
      avatar_url: user?.avatar_url ?? null,
      periodCharm: st?.charm_points || 0,
      periodDiamonds: st?.total_diamonds || 0,
      hostTierUsd: est.hostTierUsd,
      charmSalaryUsd: est.charmSalaryUsd,
      estimatedUsd: est.estimatedUsd,
      hostTierName: est.hostTierName,
      charmLevel: est.charmLevel,
    };
  });
}

export type StaffDrilldown = {
  staff: StaffListItem & { diamonds: number };
  parent: { id: string; role: string; username: string } | null;
  countyAdmins: StaffListItem[];
  bds: StaffListItem[];
  assistants: StaffListItem[];
  customerService: StaffListItem[];
  agencies: AgencyListItem[];
  hosts: HostListItem[];
  periodId: string;
  totals: {
    countyAdminCount: number;
    bdCount: number;
    assistantCount: number;
    customerServiceCount: number;
    agencyCount: number;
    hostCount: number;
    periodCharm: number;
    periodDiamonds: number;
    periodSalaryPaid: number;
    estimatedHostUsd: number;
    estimatedAgencyUsd: number;
  };
};

export async function getStaffDrilldown(
  staffId: string,
  periodId: string,
): Promise<StaffDrilldown | null> {
  const all = await loadAllStaff();
  const root = all.find((s) => s.id === staffId);
  if (!root) return null;

  const descendantIds = collectDescendantStaffIds(staffId, all);
  const treeStaffIds = [staffId, ...descendantIds];
  const descendantStaff = all.filter((s) => descendantIds.includes(s.id));

  const countyAdmins = descendantStaff.filter(
    (s) => s.role === 'bd_admin' || s.role === 'county_admin',
  );
  const bds = descendantStaff.filter((s) => s.role === 'bd');
  const assistants = descendantStaff.filter((s) => s.role === 'assistant');
  const customerService = descendantStaff.filter(
    (s) => s.role === 'customer_service',
  );

  const agencyIds = await agencyIdsForStaffIds(treeStaffIds);
  const hostMap = await hostCountsByAgency(agencyIds);
  const settings = await loadSalarySettings();

  const { data: agencyRows } = await supabaseAdmin
    .from('agencies')
    .select(
      `
      id, name, agency_code, is_active,
      users:owner_id(username),
      sponsor:business_staff!sponsor_staff_id(staff_code, users:user_id(username))
    `,
    )
    .in('id', agencyIds.length ? agencyIds : ['00000000-0000-0000-0000-000000000000']);

  const { data: memberRows } = await supabaseAdmin
    .from('agency_members')
    .select(
      `
      user_id, agency_id, role,
      agencies:agency_id(name),
      users:user_id(username, short_id, avatar_url)
    `,
    )
    .in(
      'agency_id',
      agencyIds.length ? agencyIds : ['00000000-0000-0000-0000-000000000000'],
    )
    .limit(300);

  const hosts: HostListItem[] = (memberRows || []).map((m: any) => {
    const agency = Array.isArray(m.agencies) ? m.agencies[0] : m.agencies;
    const user = Array.isArray(m.users) ? m.users[0] : m.users;
    return {
      user_id: m.user_id,
      agency_id: m.agency_id,
      agency_name: agency?.name || 'Agency',
      role: m.role || 'host',
      username: user?.username || 'Host',
      short_id: user?.short_id ?? null,
      avatar_url: user?.avatar_url ?? null,
      periodCharm: 0,
      periodDiamonds: 0,
      hostTierUsd: 0,
      charmSalaryUsd: 0,
      estimatedUsd: 0,
      hostTierName: null,
      charmLevel: 0,
    };
  });

  const hostUserIds = hosts.map((h) => h.user_id);
  let periodCharm = 0;
  let periodDiamonds = 0;
  let estimatedHostUsd = 0;
  const charmByAgency: Record<string, number> = {};
  const hostCharmsByAgency: Record<string, number[]> = {};

  if (hostUserIds.length > 0) {
    const { data: stats } = await supabaseAdmin
      .from('host_period_stats')
      .select(
        'user_id, charm_points, total_diamonds, total_on_mic_seconds, valid_days',
      )
      .eq('period_id', periodId)
      .in('user_id', hostUserIds);
    for (const t of stats || []) {
      const charm = Number(t.charm_points || 0) || 0;
      const diamonds = Number(t.total_diamonds || 0) || 0;
      periodCharm += charm;
      periodDiamonds += diamonds;
      const host = hosts.find((h) => h.user_id === t.user_id);
      if (host) {
        host.periodCharm = charm;
        host.periodDiamonds = diamonds;
        const est = estimateHostUsd(settings, {
          charm_points: charm,
          total_diamonds: diamonds,
          total_on_mic_seconds: Number(t.total_on_mic_seconds || 0) || 0,
          valid_days: Number(t.valid_days || 0) || 0,
        });
        host.hostTierUsd = est.hostTierUsd;
        host.charmSalaryUsd = est.charmSalaryUsd;
        host.estimatedUsd = est.estimatedUsd;
        host.hostTierName = est.hostTierName;
        host.charmLevel = est.charmLevel;
        estimatedHostUsd += est.hostTierUsd;
        charmByAgency[host.agency_id] =
          (charmByAgency[host.agency_id] || 0) + charm;
        (hostCharmsByAgency[host.agency_id] ??= []).push(charm);
      }
    }
  }

  let estimatedAgencyUsd = 0;
  const agencies: AgencyListItem[] = (agencyRows || []).map((a: any) => {
    const owner = Array.isArray(a.users) ? a.users[0] : a.users;
    const sponsor = Array.isArray(a.sponsor) ? a.sponsor[0] : a.sponsor;
    const sponsorUser = sponsor
      ? Array.isArray(sponsor.users)
        ? sponsor.users[0]
        : sponsor.users
      : null;
    const totalCharm = charmByAgency[a.id] || 0;
    const est = estimateAgencyUsd(settings, hostCharmsByAgency[a.id] || []);
    estimatedAgencyUsd += est.totalUsd;
    return {
      id: a.id,
      name: a.name || 'Agency',
      agency_code: a.agency_code,
      is_active: a.is_active !== false,
      owner_username: owner?.username ?? null,
      sponsor_code: sponsor?.staff_code ?? null,
      sponsor_username: sponsorUser?.username ?? null,
      hostCount: hostMap[a.id] || 0,
      periodCharm: totalCharm,
      estimatedUsd: est.totalUsd,
      charmSalaryUsd: est.charmSalaryUsd,
      agentSalaryUsd: est.agentSalaryUsd,
      salaryLevel: est.level,
      settlementPaid: false,
    };
  });

  let periodSalaryPaid = 0;
  if (hostUserIds.length > 0) {
    const { data: payouts } = await supabaseAdmin
      .from('host_salary_payouts')
      .select('total_amount, beneficiary_user_id')
      .eq('period_id', periodId)
      .in('beneficiary_user_id', hostUserIds);
    for (const p of payouts || []) {
      periodSalaryPaid += Number(p.total_amount || 0) || 0;
    }
  }

  const { data: rootUser } = await supabaseAdmin
    .from('business_staff')
    .select('users:user_id(diamonds)')
    .eq('id', staffId)
    .maybeSingle();
  const diamondsUser = Array.isArray((rootUser as any)?.users)
    ? (rootUser as any).users[0]
    : (rootUser as any)?.users;

  let parent: StaffDrilldown['parent'] = null;
  if (root.parent_staff_id) {
    const p = all.find((s) => s.id === root.parent_staff_id);
    if (p) {
      parent = {
        id: p.id,
        role: p.role,
        username: p.users?.username || 'Staff',
      };
    }
  }

  const { data: allAgencies } = await supabaseAdmin
    .from('agencies')
    .select('id, sponsor_staff_id');
  const agenciesBySponsor = new Map<string, string[]>();
  for (const a of allAgencies || []) {
    if (!a.sponsor_staff_id) continue;
    const list = agenciesBySponsor.get(a.sponsor_staff_id) || [];
    list.push(a.id);
    agenciesBySponsor.set(a.sponsor_staff_id, list);
  }
  const globalHostMap = await hostCountsByAgency(
    (allAgencies || []).map((a) => a.id as string),
  );

  const enrich = (s: StaffRow): StaffListItem => {
    const desc = collectDescendantStaffIds(s.id, all);
    const tree = [s.id, ...desc];
    const aids = Array.from(
      new Set(tree.flatMap((id) => agenciesBySponsor.get(id) || [])),
    );
    return {
      id: s.id,
      role: s.role,
      staff_code: s.staff_code,
      is_active: s.is_active,
      parent_staff_id: s.parent_staff_id,
      username: s.users?.username || 'Staff',
      short_id: s.users?.short_id ?? null,
      avatar_url: s.users?.avatar_url ?? null,
      childStaffCount: all.filter((c) => c.parent_staff_id === s.id).length,
      agencyCount: aids.length,
      hostCount: aids.reduce((sum, id) => sum + (globalHostMap[id] || 0), 0),
    };
  };

  return {
    staff: {
      ...enrich(root),
      diamonds: Number(diamondsUser?.diamonds || 0) || 0,
    },
    parent,
    countyAdmins: countyAdmins.map(enrich),
    bds: bds.map(enrich),
    assistants: assistants.map(enrich),
    customerService: customerService.map(enrich),
    agencies,
    hosts,
    periodId,
    totals: {
      countyAdminCount: countyAdmins.length,
      bdCount: bds.length,
      assistantCount: assistants.length,
      customerServiceCount: customerService.length,
      agencyCount: agencies.length,
      hostCount: hosts.length,
      periodCharm,
      periodDiamonds,
      periodSalaryPaid,
      estimatedHostUsd,
      estimatedAgencyUsd,
    },
  };
}

/** One-glance totals for a hub period: Host + Agency + BD (+ staff counts). */
export async function getPeriodSalaryOverview(
  periodId: string,
): Promise<PeriodSalaryOverview> {
  const settings = await loadSalarySettings();
  const bdMonth = periodToBdMonth(periodId);

  const [
    { data: hostStats },
    { data: hostPayouts },
    agencies,
    { data: agencyPaid },
    { data: bdStats },
    { data: bdPaid },
    { data: staffRows },
  ] = await Promise.all([
    supabaseAdmin
      .from('host_period_stats')
      .select('user_id, charm_points, total_diamonds, total_on_mic_seconds, valid_days')
      .eq('period_id', periodId),
    supabaseAdmin
      .from('host_salary_payouts')
      .select('total_amount, status')
      .eq('period_id', periodId),
    listAgencies(periodId),
    supabaseAdmin
      .from('agency_period_settlements')
      .select('total_usd, status')
      .eq('period_id', periodId),
    supabaseAdmin
      .from('bd_staff_monthly_stats')
      .select('est_total_usd, achieved_level')
      .eq('period_yyyy_mm', bdMonth),
    supabaseAdmin
      .from('bd_staff_settlements')
      .select('total_usd, status')
      .eq('period_yyyy_mm', bdMonth),
    supabaseAdmin
      .from('business_staff')
      .select('role')
      .eq('is_active', true)
      .in('role', ['super_bd', 'county_admin', 'bd_admin', 'bd']),
  ]);

  let hostEst = 0;
  let hostWithProgress = 0;
  for (const s of hostStats || []) {
    const diamonds = Number(s.total_diamonds || 0) || 0;
    const charm = Number(s.charm_points || 0) || 0;
    if (diamonds > 0 || charm > 0) hostWithProgress += 1;
    hostEst += estimateHostUsd(settings, {
      charm_points: charm,
      total_diamonds: diamonds,
      total_on_mic_seconds: Number(s.total_on_mic_seconds || 0) || 0,
      valid_days: Number(s.valid_days || 0) || 0,
    }).estimatedUsd;
  }

  const hostPaidRows = (hostPayouts || []).filter(
    (p) => p.status === 'paid' || p.status === 'completed',
  );
  // host payouts are usually diamonds; convert via chain rate for display USD
  const hostPaidDiamonds = hostPaidRows.reduce(
    (sum, p) => sum + (Number(p.total_amount) || 0),
    0,
  );
  const hostPaidUsd = hostPaidDiamonds / (settings.diamondsPerDollar || 1000);

  const agencyEst = agencies.reduce((s, a) => s + a.estimatedUsd, 0);
  const agencyWithLevel = agencies.filter((a) => a.salaryLevel > 0).length;
  const agencyPaidRows = (agencyPaid || []).filter((p) => p.status === 'paid');
  const agencyPaidUsd = agencyPaidRows.reduce(
    (sum, p) => sum + (Number(p.total_usd) || 0),
    0,
  );

  const bdEst = (bdStats || []).reduce(
    (sum, r) => sum + (Number(r.est_total_usd) || 0),
    0,
  );
  const bdWithLevel = (bdStats || []).filter(
    (r) => (Number(r.achieved_level) || 0) > 0,
  ).length;
  const bdPaidRows = (bdPaid || []).filter((p) => p.status === 'paid');
  const bdPaidUsd = bdPaidRows.reduce(
    (sum, p) => sum + (Number(p.total_usd) || 0),
    0,
  );

  let superBd = 0;
  let countyAdmin = 0;
  let bdCount = 0;
  for (const s of staffRows || []) {
    const role = String(s.role || '');
    if (role === 'super_bd') superBd += 1;
    else if (role === 'county_admin' || role === 'bd_admin') countyAdmin += 1;
    else if (role === 'bd') bdCount += 1;
  }

  const grandEstimatedUsd = hostEst + agencyEst + bdEst;
  const grandPaidUsd = hostPaidUsd + agencyPaidUsd + bdPaidUsd;

  return {
    periodId,
    bdMonth,
    hosts: {
      count: (hostStats || []).length,
      withProgress: hostWithProgress,
      estimatedUsd: hostEst,
      paidUsd: hostPaidUsd,
      paidRows: hostPaidRows.length,
    },
    agencies: {
      count: agencies.length,
      withLevel: agencyWithLevel,
      estimatedUsd: agencyEst,
      paidUsd: agencyPaidUsd,
      paidRows: agencyPaidRows.length,
    },
    bd: {
      count: (bdStats || []).length || bdCount,
      withLevel: bdWithLevel,
      estimatedUsd: bdEst,
      paidUsd: bdPaidUsd,
      paidRows: bdPaidRows.length,
    },
    staff: { superBd, countyAdmin, bd: bdCount },
    grandEstimatedUsd,
    grandPaidUsd,
  };
}
