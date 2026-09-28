import { supabaseAdmin } from "@/lib/supabase";
export type StaffRole =
  "super_bd" | "county_admin" | "bd_admin" | "bd" | "assistant" | "customer_service" | string;
export type StaffUserBrief = {
  id: string;
  username: string | null;
  short_id: number | null;
  avatar_url: string | null;
};
export type StaffNode = {
  id: string;
  role: StaffRole;
  staff_code: string;
  is_active: boolean;
  parent_staff_id: string | null;
  created_by_user_id: string | null;
  created_at: string;
  user: StaffUserBrief | null;
};
export type SubtreeCounts = {
  countyAdmins: number;
  bds: number;
  assistants: number;
  customerService: number;
  agencies: number;
  hosts: number;
  staffTotal: number;
};
export type SuperAdminBranch = {
  staff: StaffNode;
  children: StaffNode[];
  counts: SubtreeCounts;
  agencies: Array<{
    id: string;
    name: string | null;
    agency_code: string | null;
    is_active: boolean;
    sponsor_staff_id: string | null;
    sponsor_username: string | null;
  }>;
};
export type OperatorTreeTotals = {
  superAdmins: number;
  countyAdmins: number;
  bds: number;
  assistants: number;
  customerService: number;
  agencies: number;
  hosts: number;
  directStaff: number;
};
export type OperatorTree = {
  operatorUserId: string;
  directStaff: StaffNode[];
  superAdmins: SuperAdminBranch[];
  otherDirect: StaffNode[];
  totals: OperatorTreeTotals;
};
export const STAFF_ROLE_LABELS: Record<string, string> = {
  super_bd: "Super Admin",
  county_admin: "County Admin",
  bd_admin: "BD Admin",
  bd: "BD",
  assistant: "Assistant",
  customer_service: "Customer Service",
};
function unwrapUser(raw: unknown): StaffUserBrief | null {
  if (!raw) return null;
  const row = Array.isArray(raw) ? raw[0] : raw;
  if (!row || typeof row !== "object") return null;
  const u = row as Record<string, unknown>;
  return {
    id: String(u.id ?? ""),
    username: (u.username as string | null) ?? null,
    short_id: (u.short_id as number | null) ?? null,
    avatar_url: (u.avatar_url as string | null) ?? null,
  };
}
function mapStaffRow(row: any): StaffNode {
  return {
    id: row.id,
    role: row.role,
    staff_code: row.staff_code,
    is_active: row.is_active,
    parent_staff_id: row.parent_staff_id ?? null,
    created_by_user_id: row.created_by_user_id ?? null,
    created_at: row.created_at,
    user: unwrapUser(row.users),
  };
}
function emptyCounts(): SubtreeCounts {
  return {
    countyAdmins: 0,
    bds: 0,
    assistants: 0,
    customerService: 0,
    agencies: 0,
    hosts: 0,
    staffTotal: 0,
  };
}
export function collectSubtreeIds(rootId: string, byParent: Map<string, StaffNode[]>): string[] {
  const out: string[] = [];
  const queue = [rootId];
  const seen = new Set<string>();
  while (queue.length) {
    const id = queue.shift()!;
    if (seen.has(id)) continue;
    seen.add(id);
    const kids = byParent.get(id) || [];
    for (const kid of kids) {
      out.push(kid.id);
      queue.push(kid.id);
    }
  }
  return out;
}
function countRoles(
  nodes: StaffNode[],
): Pick<SubtreeCounts, "countyAdmins" | "bds" | "assistants" | "customerService" | "staffTotal"> {
  let countyAdmins = 0;
  let bds = 0;
  let assistants = 0;
  let customerService = 0;
  for (const n of nodes) {
    if (n.role === "county_admin" || n.role === "bd_admin") countyAdmins += 1;
    else if (n.role === "bd") bds += 1;
    else if (n.role === "assistant") assistants += 1;
    else if (n.role === "customer_service") customerService += 1;
  }
  return {
    countyAdmins,
    bds,
    assistants,
    customerService,
    staffTotal: nodes.length,
  };
}
async function loadAllStaff(): Promise<StaffNode[]> {
  const { data, error } = await supabaseAdmin
    .from("business_staff")
    .select(
      "id, role, staff_code, is_active, parent_staff_id, created_by_user_id, created_at, users:user_id(id, username, short_id, avatar_url)",
    )
    .order("created_at", { ascending: true });
  if (error) throw error;
  return (data || []).map(mapStaffRow);
}
async function agencyHostCountsForBdIds(bdIds: string[]): Promise<{
  agencies: Array<{
    id: string;
    name: string | null;
    agency_code: string | null;
    is_active: boolean;
    sponsor_staff_id: string | null;
  }>;
  hostCount: number;
  sponsorUsernames: Map<string, string | null>;
}> {
  if (bdIds.length === 0) {
    return { agencies: [], hostCount: 0, sponsorUsernames: new Map() };
  }
  const { data: agencies, error: agErr } = await supabaseAdmin
    .from("agencies")
    .select("id, name, agency_code, is_active, sponsor_staff_id")
    .in("sponsor_staff_id", bdIds);
  if (agErr) throw agErr;
  const agencyRows = agencies || [];
  const agencyIds = agencyRows.map((a) => a.id);
  let hostCount = 0;
  if (agencyIds.length > 0) {
    const { count, error: memErr } = await supabaseAdmin
      .from("agency_members")
      .select("id", { count: "exact", head: true })
      .in("agency_id", agencyIds);
    if (memErr) throw memErr;
    hostCount = count ?? 0;
  }
  return {
    agencies: agencyRows,
    hostCount,
    sponsorUsernames: new Map(),
  };
}
export async function getOperatorTree(operatorUserId: string): Promise<OperatorTree> {
  const allStaff = await loadAllStaff();
  const byParent = new Map<string, StaffNode[]>();
  const byId = new Map<string, StaffNode>();
  for (const s of allStaff) {
    byId.set(s.id, s);
    if (s.parent_staff_id) {
      const list = byParent.get(s.parent_staff_id) || [];
      list.push(s);
      byParent.set(s.parent_staff_id, list);
    }
  }
  const directStaff = allStaff.filter((s) => s.created_by_user_id === operatorUserId);
  const directIds = new Set(directStaff.map((s) => s.id));
  const createdSuperAdmins = directStaff.filter((s) => s.role === "super_bd");
  const superAdmins: SuperAdminBranch[] = [];
  const listedUnderSa = new Set<string>();
  for (const sa of createdSuperAdmins) {
    const descendantIds = collectSubtreeIds(sa.id, byParent);
    const children = descendantIds.map((id) => byId.get(id)).filter((n): n is StaffNode => !!n);
    for (const c of children) listedUnderSa.add(c.id);
    const bdIds = children.filter((c) => c.role === "bd").map((c) => c.id);
    const { agencies, hostCount } = await agencyHostCountsForBdIds(bdIds);
    const roleCounts = countRoles(children);
    const bdUsername = new Map(
      children.filter((c) => c.role === "bd").map((c) => [c.id, c.user?.username ?? null]),
    );
    superAdmins.push({
      staff: sa,
      children,
      counts: {
        ...roleCounts,
        agencies: agencies.length,
        hosts: hostCount,
      },
      agencies: agencies.map((a) => ({
        ...a,
        sponsor_username: a.sponsor_staff_id ? (bdUsername.get(a.sponsor_staff_id) ?? null) : null,
      })),
    });
  }
  const otherDirect = directStaff.filter((s) => s.role !== "super_bd" && !listedUnderSa.has(s.id));
  const allBdIds = new Set<string>();
  let countyAdmins = 0;
  let bds = 0;
  let assistants = 0;
  let customerService = 0;
  for (const branch of superAdmins) {
    countyAdmins += branch.counts.countyAdmins;
    bds += branch.counts.bds;
    assistants += branch.counts.assistants;
    customerService += branch.counts.customerService;
    for (const c of branch.children) {
      if (c.role === "bd") allBdIds.add(c.id);
    }
  }
  for (const s of otherDirect) {
    if (s.role === "county_admin" || s.role === "bd_admin") countyAdmins += 1;
    else if (s.role === "bd") {
      bds += 1;
      allBdIds.add(s.id);
    } else if (s.role === "assistant") assistants += 1;
    else if (s.role === "customer_service") customerService += 1;
  }
  const { agencies: allAgencies, hostCount: allHosts } = await agencyHostCountsForBdIds([
    ...allBdIds,
  ]);
  return {
    operatorUserId,
    directStaff,
    superAdmins,
    otherDirect,
    totals: {
      superAdmins: createdSuperAdmins.length,
      countyAdmins,
      bds,
      assistants,
      customerService,
      agencies: allAgencies.length,
      hosts: allHosts,
      directStaff: directStaff.length,
    },
  };
}
export async function getOperatorTreeTotals(operatorUserId: string): Promise<OperatorTreeTotals> {
  const tree = await getOperatorTree(operatorUserId);
  return tree.totals;
}
export async function getOperatorTreeTotalsBatch(
  operatorUserIds: string[],
): Promise<Map<string, OperatorTreeTotals>> {
  const unique = [...new Set(operatorUserIds.filter(Boolean))];
  const map = new Map<string, OperatorTreeTotals>();
  if (unique.length === 0) return map;
  const allStaff = await loadAllStaff();
  const byParent = new Map<string, StaffNode[]>();
  const byId = new Map<string, StaffNode>();
  for (const s of allStaff) {
    byId.set(s.id, s);
    if (s.parent_staff_id) {
      const list = byParent.get(s.parent_staff_id) || [];
      list.push(s);
      byParent.set(s.parent_staff_id, list);
    }
  }
  const { data: allAgencies } = await supabaseAdmin.from("agencies").select("id, sponsor_staff_id");
  const agenciesBySponsor = new Map<string, string[]>();
  for (const a of allAgencies || []) {
    if (!a.sponsor_staff_id) continue;
    const list = agenciesBySponsor.get(a.sponsor_staff_id) || [];
    list.push(a.id);
    agenciesBySponsor.set(a.sponsor_staff_id, list);
  }
  const allAgencyIds = (allAgencies || []).map((a) => a.id);
  const hostCountByAgency = new Map<string, number>();
  if (allAgencyIds.length > 0) {
    const { data: members } = await supabaseAdmin.from("agency_members").select("agency_id");
    for (const m of members || []) {
      hostCountByAgency.set(m.agency_id, (hostCountByAgency.get(m.agency_id) || 0) + 1);
    }
  }
  for (const opUserId of unique) {
    const direct = allStaff.filter((s) => s.created_by_user_id === opUserId);
    const createdSAs = direct.filter((s) => s.role === "super_bd");
    const listedUnderSa = new Set<string>();
    const bdIds = new Set<string>();
    let countyAdmins = 0;
    let bds = 0;
    let assistants = 0;
    let customerService = 0;
    for (const sa of createdSAs) {
      const descIds = collectSubtreeIds(sa.id, byParent);
      for (const id of descIds) {
        listedUnderSa.add(id);
        const n = byId.get(id);
        if (!n) continue;
        if (n.role === "county_admin" || n.role === "bd_admin") countyAdmins += 1;
        else if (n.role === "bd") {
          bds += 1;
          bdIds.add(n.id);
        } else if (n.role === "assistant") assistants += 1;
        else if (n.role === "customer_service") customerService += 1;
      }
    }
    for (const s of direct) {
      if (s.role === "super_bd" || listedUnderSa.has(s.id)) continue;
      if (s.role === "county_admin" || s.role === "bd_admin") countyAdmins += 1;
      else if (s.role === "bd") {
        bds += 1;
        bdIds.add(s.id);
      } else if (s.role === "assistant") assistants += 1;
      else if (s.role === "customer_service") customerService += 1;
    }
    let agencies = 0;
    let hosts = 0;
    for (const bdId of bdIds) {
      const agIds = agenciesBySponsor.get(bdId) || [];
      agencies += agIds.length;
      for (const agId of agIds) hosts += hostCountByAgency.get(agId) || 0;
    }
    map.set(opUserId, {
      superAdmins: createdSAs.length,
      countyAdmins,
      bds,
      assistants,
      customerService,
      agencies,
      hosts,
      directStaff: direct.length,
    });
  }
  return map;
}
