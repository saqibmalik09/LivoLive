export type PortalRole = 'super_bd' | 'county_admin' | 'bd_admin' | 'bd' | 'assistant' | 'customer_service';
export type ChildStaffRole = 'county_admin' | 'bd' | 'assistant' | 'customer_service';

const ROLE_LABELS: Record<string, string> = {
  super_bd: 'Super Admin',
  county_admin: 'Country Admin',
  bd_admin: 'Country Admin',
  bd: 'BD',
  assistant: 'Assistant',
  customer_service: 'Customer Service',
};

export function staffRoleLabel(role: string | undefined | null): string {
  if (!role) return '';
  return ROLE_LABELS[role] ?? ROLE_LABELS[normalizePortalRole(role) ?? ''] ?? role;
}

export function normalizePortalRole(role: string | undefined | null): string | null {
  if (!role) return null;
  if (role === 'bd_admin') return 'county_admin';
  return role;
}

/** Web portal login roles — Super Admin only. */
export function isPortalRole(role: string | undefined | null): role is PortalRole {
  return normalizePortalRole(role) === 'super_bd';
}

/**
 * Super Admin web panel is LIMITED:
 * - ban/unban + view subtree targets
 * - NO user PII edit, NO policy amount edits, NO settlements
 */
export function getPortalPermissions(role: PortalRole | string) {
  const r = normalizePortalRole(role) ?? role;

  if (r === 'super_bd') {
    return {
      label: ROLE_LABELS.super_bd,
      canCreateStaff: true,
      childRole: 'county_admin' as ChildStaffRole,
      creatableRoles: ['county_admin', 'bd', 'assistant', 'customer_service'] as ChildStaffRole[],
      createStaffLabel: 'Add Country Admin / BD / Assistant / CS',
      createStaffActionLabel: 'Create team member',
      showBdAdminStat: true,
      showBdStat: true,
      applicationsScope: 'subtree' as const,
      canBanUnban: true,
      canGrantVip: true,
      canDeactivateStaff: true,
      canDeactivateAgency: true,
      canViewSubtreeTargets: true,
      canEditUserProfile: false,
      canViewPersonalDetails: false,
      canEditPolicy: false,
      canRunSettlements: false,
      canOpenAgencyDetailPii: false,
    };
  }

  // Non–Super Admin: no web portal capabilities
  return {
    label: ROLE_LABELS[r] ?? r,
    canCreateStaff: false,
    childRole: null as ChildStaffRole | null,
    creatableRoles: [] as ChildStaffRole[],
    createStaffLabel: null as string | null,
    createStaffActionLabel: null as string | null,
    showBdAdminStat: false,
    showBdStat: false,
    applicationsScope: 'subtree' as const,
    canBanUnban: false,
    canGrantVip: false,
    canDeactivateStaff: false,
    canDeactivateAgency: false,
    canViewSubtreeTargets: false,
    canEditUserProfile: false,
    canViewPersonalDetails: false,
    canEditPolicy: false,
    canRunSettlements: false,
    canOpenAgencyDetailPii: false,
  };
}
