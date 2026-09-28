import type { PortalRole } from '@/lib/permissions';
import type { ChartAnalytics, HierarchyResponse } from '@/lib/types';

export const CHART_PALETTE = [
  '#f59e0b',
  '#a855f7',
  '#3b82f6',
  '#10b981',
  '#ec4899',
  '#6366f1',
  '#14b8a6',
  '#f97316',
] as const;

export function formatCompact(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`;
  return n.toLocaleString();
}

export function truncateLabel(label: string, max = 14): string {
  if (label.length <= max) return label;
  return `${label.slice(0, max - 1)}…`;
}

export function buildNetworkBreakdown(data: HierarchyResponse, role: PortalRole) {
  const { stats } = data;
  const rows = [];

  if (role === 'super_bd') {
    rows.push({ name: 'Country Admins', value: stats.bd_admin_count, color: CHART_PALETTE[0] });
    rows.push({ name: 'BDs', value: stats.bd_count, color: CHART_PALETTE[1] });
  } else if (role === 'bd_admin') {
    rows.push({ name: 'BDs', value: stats.bd_count, color: CHART_PALETTE[1] });
  }

  rows.push({ name: 'Agencies', value: stats.agency_count, color: CHART_PALETTE[2] });
  rows.push({ name: 'Hosts', value: stats.host_count, color: CHART_PALETTE[3] });

  return rows.filter((row) => row.value > 0);
}

export function buildEarningsComparison(data: HierarchyResponse) {
  const { commission_diamonds, salary_diamonds } = data.stats;
  return [
    { name: 'Gift commission', diamonds: commission_diamonds, fill: CHART_PALETTE[1] },
    { name: 'Salary paid', diamonds: salary_diamonds, fill: CHART_PALETTE[3] },
  ];
}

export function buildFallbackAnalytics(data: HierarchyResponse): ChartAnalytics {
  const agencyCharm = new Map<string, number>();
  for (const host of data.tree.hosts) {
    const charm = host.period_charm ?? host.period_diamonds ?? 0;
    agencyCharm.set(host.agency_id, (agencyCharm.get(host.agency_id) ?? 0) + charm);
  }

  const agencyPerformance = data.tree.agencies
    .map((agency) => ({
      name: agency.name,
      agency_code: agency.agency_code,
      hosts: agency.host_count,
      diamonds: agencyCharm.get(agency.id) ?? 0, // value is charm; key kept for chart
      on_mic_seconds: data.tree.hosts
        .filter((h) => h.agency_id === agency.id)
        .reduce((sum, h) => sum + h.period_on_mic_seconds, 0),
    }))
    .sort((a, b) => b.diamonds - a.diamonds);

  const topHosts = [...data.tree.hosts]
    .sort(
      (a, b) =>
        (b.period_charm ?? b.period_diamonds) - (a.period_charm ?? a.period_diamonds),
    )
    .slice(0, 10)
    .map((host) => {
      const agency = data.tree.agencies.find((a) => a.id === host.agency_id);
      const charm = host.period_charm ?? host.period_diamonds;
      return {
        username: host.username,
        short_id: host.short_id,
        agency_name: agency?.name ?? '—',
        diamonds: charm,
        on_mic_seconds: host.period_on_mic_seconds,
        valid_days: host.period_valid_days,
      };
    });

  const roleBreakdown = [
    { role: 'Country Admin', count: data.stats.bd_admin_count },
    { role: 'BD', count: data.stats.bd_count },
  ].filter((row) => row.count > 0);

  return {
    period_id: data.period_id,
    commission_trend: [],
    agency_performance: agencyPerformance,
    top_hosts: topHosts,
    role_breakdown: roleBreakdown,
  };
}

export function mergeAnalytics(
  hierarchy: HierarchyResponse,
  remote: ChartAnalytics | null,
  role: PortalRole
): ChartAnalytics & { network: ReturnType<typeof buildNetworkBreakdown>; earnings: ReturnType<typeof buildEarningsComparison> } {
  const base = remote ?? buildFallbackAnalytics(hierarchy);

  return {
    ...base,
    agency_performance: base.agency_performance.length
      ? base.agency_performance
      : buildFallbackAnalytics(hierarchy).agency_performance,
    top_hosts: base.top_hosts.length ? base.top_hosts : buildFallbackAnalytics(hierarchy).top_hosts,
    network: buildNetworkBreakdown(hierarchy, role),
    earnings: buildEarningsComparison(hierarchy),
  };
}
