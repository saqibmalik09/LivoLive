import "server-only";
import { supabaseAdmin } from "@/lib/supabase";
export type AgencyPeriodAuditRow = {
  agency_id: string;
  agency_name: string;
  agency_code: string | null;
  owner_user_id: string;
  owner_username: string;
  owner_short_id: number | null;
  period_id: string;
  salary_usd: number;
  achieved_level: number;
  total_charm: number;
  paid_at: string | null;
  settlement_status: string;
  member_count: number;
  stats_charm: number;
  self_gift_charm: number;
  self_gift_pct: number;
  cash_balance: number;
  pending_withdraw_usd: number;
  completed_withdraw_usd: number;
  implied_cash_usd: number;
  salary_ratio: number | null;
  flag_double_pay: boolean;
  flag_over_withdraw: boolean;
  flag_mostly_self_gift: boolean;
  flag_ok: boolean;
};
export type HostPeriodAuditRow = {
  user_id: string;
  username: string;
  short_id: number | null;
  agency_id: string | null;
  agency_name: string | null;
  agency_code: string | null;
  period_id: string;
  total_diamonds: number;
  total_on_mic_seconds: number;
  valid_days: number;
  work_hours: number;
  charm_points: number;
  self_gift_charm: number;
  self_gift_pct: number;
  tier_id: string | null;
  tier_name: string | null;
  est_usd: number;
  est_diamonds: number;
  diamond_only_usd: number;
  payout_id: string | null;
  payout_status: string | null;
  payout_diamonds: number;
  paid_at: string | null;
  diamonds_balance: number;
  cash_balance: number;
  pending_withdraw_usd: number;
  flag_unpaid_with_due: boolean;
  flag_withheld: boolean;
  flag_paid_mismatch: boolean;
  flag_mostly_self_gift: boolean;
  flag_blocked_by_attendance: boolean;
  flag_ok: boolean;
};
export type BdMonthAuditRow = {
  staff_id: string;
  user_id: string;
  username: string;
  short_id: number | null;
  staff_code: string | null;
  role: string;
  is_active: boolean;
  period_yyyy_mm: string;
  agency_target_usd: number;
  work_days: number;
  work_hours: number;
  new_agencies: number;
  achieved_level: number;
  est_basic_usd: number;
  est_commission_usd: number;
  est_new_bd_usd: number;
  est_total_usd: number;
  payable_usd: number;
  basic_qualifies: boolean;
  in_new_bd_window: boolean;
  last_calculated_at: string | null;
  settlement_status: string | null;
  settlement_total_usd: number;
  settlement_basic_usd: number;
  settlement_commission_usd: number;
  settlement_new_bd_usd: number;
  paid_at: string | null;
  cash_balance: number;
  pending_withdraw_usd: number;
  completed_withdraw_usd: number;
  implied_cash_usd: number;
  flag_unpaid_with_due: boolean;
  flag_over_withdraw: boolean;
  flag_no_attendance: boolean;
  flag_ok: boolean;
};
export type LeadershipMonthAuditRow = {
  staff_id: string;
  user_id: string;
  username: string;
  short_id: number | null;
  staff_code: string | null;
  role: string;
  normalized_role: "super_bd" | "county_admin" | string;
  is_active: boolean;
  period_yyyy_mm: string;
  parent_staff_id: string | null;
  parent_username: string | null;
  child_staff_count: number;
  agency_count: number;
  host_count: number;
  commission_diamonds: number;
  commission_usd: number;
  gift_events: number;
  diamonds_balance: number;
  cash_balance: number;
  pending_withdraw_usd: number;
  completed_withdraw_usd: number;
  implied_cash_usd: number;
  flag_inactive_with_commission: boolean;
  flag_over_withdraw: boolean;
  flag_no_downline: boolean;
  flag_ok: boolean;
};
export async function getAgencyPeriodAudit(periodId: string): Promise<AgencyPeriodAuditRow[]> {
  const { data, error } = await supabaseAdmin.rpc("admin_agency_period_audit", {
    p_period_id: periodId,
  });
  if (error) throw new Error(error.message);
  return (data || []).map((r: any) => ({
    agency_id: r.agency_id,
    agency_name: r.agency_name,
    agency_code: r.agency_code,
    owner_user_id: r.owner_user_id,
    owner_username: r.owner_username,
    owner_short_id: r.owner_short_id == null ? null : Number(r.owner_short_id),
    period_id: r.period_id,
    salary_usd: Number(r.salary_usd) || 0,
    achieved_level: Number(r.achieved_level) || 0,
    total_charm: Number(r.total_charm) || 0,
    paid_at: r.paid_at,
    settlement_status: r.settlement_status,
    member_count: Number(r.member_count) || 0,
    stats_charm: Number(r.stats_charm) || 0,
    self_gift_charm: Number(r.self_gift_charm) || 0,
    self_gift_pct: Number(r.self_gift_pct) || 0,
    cash_balance: Number(r.cash_balance) || 0,
    pending_withdraw_usd: Number(r.pending_withdraw_usd) || 0,
    completed_withdraw_usd: Number(r.completed_withdraw_usd) || 0,
    implied_cash_usd: Number(r.implied_cash_usd) || 0,
    salary_ratio: r.salary_ratio == null ? null : Number(r.salary_ratio),
    flag_double_pay: !!r.flag_double_pay,
    flag_over_withdraw: !!r.flag_over_withdraw,
    flag_mostly_self_gift: !!r.flag_mostly_self_gift,
    flag_ok: !!r.flag_ok,
  }));
}
export async function getHostPeriodAudit(periodId: string): Promise<HostPeriodAuditRow[]> {
  const { data, error } = await supabaseAdmin.rpc("admin_host_period_audit", {
    p_period_id: periodId,
  });
  if (error) throw new Error(error.message);
  return (data || []).map((r: any) => ({
    user_id: r.user_id,
    username: r.username,
    short_id: r.short_id == null ? null : Number(r.short_id),
    agency_id: r.agency_id ?? null,
    agency_name: r.agency_name ?? null,
    agency_code: r.agency_code ?? null,
    period_id: r.period_id,
    total_diamonds: Number(r.total_diamonds) || 0,
    total_on_mic_seconds: Number(r.total_on_mic_seconds) || 0,
    valid_days: Number(r.valid_days) || 0,
    work_hours: Number(r.work_hours) || 0,
    charm_points: Number(r.charm_points) || 0,
    self_gift_charm: Number(r.self_gift_charm) || 0,
    self_gift_pct: Number(r.self_gift_pct) || 0,
    tier_id: r.tier_id ?? null,
    tier_name: r.tier_name ?? null,
    est_usd: Number(r.est_usd) || 0,
    est_diamonds: Number(r.est_diamonds) || 0,
    diamond_only_usd: Number(r.diamond_only_usd) || 0,
    payout_id: r.payout_id ?? null,
    payout_status: r.payout_status ?? null,
    payout_diamonds: Number(r.payout_diamonds) || 0,
    paid_at: r.paid_at,
    diamonds_balance: Number(r.diamonds_balance) || 0,
    cash_balance: Number(r.cash_balance) || 0,
    pending_withdraw_usd: Number(r.pending_withdraw_usd) || 0,
    flag_unpaid_with_due: !!r.flag_unpaid_with_due,
    flag_withheld: !!r.flag_withheld,
    flag_paid_mismatch: !!r.flag_paid_mismatch,
    flag_mostly_self_gift: !!r.flag_mostly_self_gift,
    flag_blocked_by_attendance: !!r.flag_blocked_by_attendance,
    flag_ok: !!r.flag_ok,
  }));
}
export async function getLeadershipMonthAudit(
  periodYyyyMm: string,
): Promise<LeadershipMonthAuditRow[]> {
  const { data, error } = await supabaseAdmin.rpc("admin_leadership_month_audit", {
    p_period_yyyy_mm: periodYyyyMm,
  });
  if (error) throw new Error(error.message);
  return (data || []).map((r: any) => ({
    staff_id: r.staff_id,
    user_id: r.user_id,
    username: r.username,
    short_id: r.short_id == null ? null : Number(r.short_id),
    staff_code: r.staff_code,
    role: r.role,
    normalized_role: r.normalized_role,
    is_active: !!r.is_active,
    period_yyyy_mm: r.period_yyyy_mm,
    parent_staff_id: r.parent_staff_id ?? null,
    parent_username: r.parent_username ?? null,
    child_staff_count: Number(r.child_staff_count) || 0,
    agency_count: Number(r.agency_count) || 0,
    host_count: Number(r.host_count) || 0,
    commission_diamonds: Number(r.commission_diamonds) || 0,
    commission_usd: Number(r.commission_usd) || 0,
    gift_events: Number(r.gift_events) || 0,
    diamonds_balance: Number(r.diamonds_balance) || 0,
    cash_balance: Number(r.cash_balance) || 0,
    pending_withdraw_usd: Number(r.pending_withdraw_usd) || 0,
    completed_withdraw_usd: Number(r.completed_withdraw_usd) || 0,
    implied_cash_usd: Number(r.implied_cash_usd) || 0,
    flag_inactive_with_commission: !!r.flag_inactive_with_commission,
    flag_over_withdraw: !!r.flag_over_withdraw,
    flag_no_downline: !!r.flag_no_downline,
    flag_ok: !!r.flag_ok,
  }));
}
export async function getBdMonthAudit(periodYyyyMm: string): Promise<BdMonthAuditRow[]> {
  const { data, error } = await supabaseAdmin.rpc("admin_bd_month_audit", {
    p_period_yyyy_mm: periodYyyyMm,
  });
  if (error) throw new Error(error.message);
  return (data || []).map((r: any) => ({
    staff_id: r.staff_id,
    user_id: r.user_id,
    username: r.username,
    short_id: r.short_id == null ? null : Number(r.short_id),
    staff_code: r.staff_code,
    role: r.role,
    is_active: !!r.is_active,
    period_yyyy_mm: r.period_yyyy_mm,
    agency_target_usd: Number(r.agency_target_usd) || 0,
    work_days: Number(r.work_days) || 0,
    work_hours: Number(r.work_hours) || 0,
    new_agencies: Number(r.new_agencies) || 0,
    achieved_level: Number(r.achieved_level) || 0,
    est_basic_usd: Number(r.est_basic_usd) || 0,
    est_commission_usd: Number(r.est_commission_usd) || 0,
    est_new_bd_usd: Number(r.est_new_bd_usd) || 0,
    est_total_usd: Number(r.est_total_usd) || 0,
    payable_usd: Number(r.payable_usd) || 0,
    basic_qualifies: !!r.basic_qualifies,
    in_new_bd_window: !!r.in_new_bd_window,
    last_calculated_at: r.last_calculated_at,
    settlement_status: r.settlement_status,
    settlement_total_usd: Number(r.settlement_total_usd) || 0,
    settlement_basic_usd: Number(r.settlement_basic_usd) || 0,
    settlement_commission_usd: Number(r.settlement_commission_usd) || 0,
    settlement_new_bd_usd: Number(r.settlement_new_bd_usd) || 0,
    paid_at: r.paid_at,
    cash_balance: Number(r.cash_balance) || 0,
    pending_withdraw_usd: Number(r.pending_withdraw_usd) || 0,
    completed_withdraw_usd: Number(r.completed_withdraw_usd) || 0,
    implied_cash_usd: Number(r.implied_cash_usd) || 0,
    flag_unpaid_with_due: !!r.flag_unpaid_with_due,
    flag_over_withdraw: !!r.flag_over_withdraw,
    flag_no_attendance: !!r.flag_no_attendance,
    flag_ok: !!r.flag_ok,
  }));
}
