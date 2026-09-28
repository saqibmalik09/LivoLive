import { normalizePortalRole } from '@/lib/permissions';
import type { AgencyNode, HierarchyResponse, HostNode, StaffNode } from '@/lib/types';
import type { NetworkRole } from '@/lib/period';

export function matchesSearch(q: string, ...parts: Array<string | number | null | undefined>) {
  const needle = q.trim().toLowerCase();
  if (!needle) return true;
  return parts.some((p) => p != null && String(p).toLowerCase().includes(needle));
}

export function filterStaffByRole(staff: StaffNode[], role: 'county_admin' | 'bd'): StaffNode[] {
  return staff.filter((s) => normalizePortalRole(s.role) === role && s.depth > 0);
}

export function hostCountUnderStaff(
  staffId: string,
  agencies: AgencyNode[],
  hosts: HostNode[],
  allStaff: StaffNode[],
): number {
  const agencyIds = new Set(
    agencies.filter((a) => a.sponsor_staff_id === staffId).map((a) => a.id),
  );
  // Also count agencies sponsored by descendants
  const childIds = new Set(
    allStaff.filter((s) => s.parent_staff_id === staffId).map((s) => s.id),
  );
  for (const a of agencies) {
    if (a.sponsor_staff_id && childIds.has(a.sponsor_staff_id)) {
      agencyIds.add(a.id);
    }
  }
  return hosts.filter((h) => agencyIds.has(h.agency_id)).length;
}

export function agencyNameById(agencies: AgencyNode[]): Record<string, string> {
  return Object.fromEntries(agencies.map((a) => [a.id, a.name]));
}

export function parseNetworkRole(raw?: string | null): NetworkRole {
  if (raw === 'county_admin' || raw === 'bd' || raw === 'agency' || raw === 'host') return raw;
  if (raw === 'bd_admin') return 'county_admin';
  return 'county_admin';
}

export function filterHierarchy(
  data: HierarchyResponse,
  role: NetworkRole,
  search: string,
  activeOnly: boolean,
) {
  const { staff, agencies, hosts } = data.tree;

  if (role === 'county_admin' || role === 'bd') {
    let rows = filterStaffByRole(staff, role);
    if (activeOnly) rows = rows.filter((s) => s.is_active);
    rows = rows.filter((s) =>
      matchesSearch(search, s.username, s.short_id, s.staff_code, s.role),
    );
    return { staff: rows, agencies: [] as AgencyNode[], hosts: [] as HostNode[] };
  }

  if (role === 'agency') {
    let rows = [...agencies];
    if (activeOnly) rows = rows.filter((a) => a.is_active);
    rows = rows.filter((a) =>
      matchesSearch(
        search,
        a.name,
        a.agency_code,
        a.owner_username,
        a.owner_short_id,
        a.sponsor_username,
      ),
    );
    return { staff: [] as StaffNode[], agencies: rows, hosts: [] as HostNode[] };
  }

  let hostRows = [...hosts];
  hostRows = hostRows.filter((h) =>
    matchesSearch(
      search,
      h.username,
      h.short_id,
      agencyNameById(agencies)[h.agency_id],
    ),
  );
  return { staff: [] as StaffNode[], agencies: [] as AgencyNode[], hosts: hostRows };
}
