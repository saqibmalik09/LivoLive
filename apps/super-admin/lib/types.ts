export type StaffNode = {
  id: string;
  parent_staff_id: string | null;
  role: string;
  staff_code: string;
  is_active: boolean;
  user_id: string;
  username: string;
  short_id: number;
  avatar_url: string | null;
  depth: number;
  direct_team_count: number;
  direct_agency_count: number;
};

export type AgencyNode = {
  id: string;
  name: string;
  agency_code: string;
  is_active: boolean;
  owner_id: string;
  owner_username: string;
  owner_short_id: number;
  owner_avatar_url: string | null;
  sponsor_staff_id: string;
  sponsor_username: string | null;
  sponsor_role: string | null;
  created_at: string;
  host_count: number;
  period_charm?: number;
  period_on_mic_seconds?: number;
};

export type HostPeriodStat = {
  period_id: string;
  total_diamonds: number;
  charm_points: number;
  total_on_mic_seconds: number;
  valid_days: number;
};

export type HostNode = {
  member_id: string;
  agency_id: string;
  user_id: string;
  username: string;
  short_id: number;
  avatar_url: string | null;
  joined_at: string;
  period_diamonds: number;
  period_charm?: number;
  period_on_mic_seconds: number;
  period_valid_days: number;
};

export type HierarchyResponse = {
  success: boolean;
  me: {
    staff_id: string;
    role: string;
    staff_code: string;
    is_active: boolean;
    user_id: string;
    username: string;
    short_id: number;
    avatar_url: string | null;
    diamonds: number;
  };
  period_id: string;
  stats: {
    bd_admin_count: number;
    bd_count: number;
    agency_count: number;
    host_count: number;
    pending_applications: number;
    commission_diamonds: number;
    salary_diamonds: number;
  };
  tree: {
    staff: StaffNode[];
    agencies: AgencyNode[];
    hosts: HostNode[];
  };
};

export type AgencyApplication = {
  id: string;
  user_id: string;
  real_name: string | null;
  status: string;
  created_at: string;
  target_staff_id: string;
  username: string;
  short_id: number;
  avatar_url: string | null;
  target_staff_code: string;
  target_staff_role: string;
  target_staff_username: string;
};

export type SearchUser = {
  id: string;
  username: string;
  short_id: number;
  avatar_url: string | null;
  is_banned?: boolean;
  ban_reason?: string | null;
};

export type ChartAnalytics = {
  period_id: string;
  commission_trend: {
    label: string;
    day: string;
    diamonds: number;
  }[];
  agency_performance: {
    name: string;
    agency_code: string;
    hosts: number;
    diamonds: number;
    on_mic_seconds: number;
  }[];
  top_hosts: {
    username: string;
    short_id: number;
    agency_name: string;
    diamonds: number;
    on_mic_seconds: number;
    valid_days: number;
  }[];
  role_breakdown: {
    role: string;
    count: number;
  }[];
};
