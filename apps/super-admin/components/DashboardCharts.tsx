'use client';

import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { mergeAnalytics, formatCompact, truncateLabel, CHART_PALETTE } from '@/lib/chart-data';
import type { PortalRole } from '@/lib/permissions';
import type { ChartAnalytics, HierarchyResponse } from '@/lib/types';
import { BarChart3, Gem, TrendingUp, Users } from 'lucide-react';

type DashboardChartsProps = {
  hierarchy: HierarchyResponse;
  analytics: ChartAnalytics | null;
  role: PortalRole;
};

type ChartCardProps = {
  title: string;
  subtitle?: string;
  icon: React.ReactNode;
  children: React.ReactNode;
  className?: string;
};

const AXIS = { fill: 'rgba(255,255,255,0.35)', fontSize: 11 };
const GRID = 'rgba(255,255,255,0.06)';

function ChartCard({ title, subtitle, icon, children, className = '' }: ChartCardProps) {
  return (
    <div className={`glass-card p-5 md:p-6 flex flex-col min-h-[320px] ${className}`}>
      <div className="flex items-start justify-between gap-3 mb-5">
        <div>
          <p className="text-[10px] font-black uppercase tracking-[0.18em] text-white/40">{title}</p>
          {subtitle ? <p className="text-xs text-white/30 mt-1">{subtitle}</p> : null}
        </div>
        <div className="w-9 h-9 rounded-xl bg-white/5 flex items-center justify-center text-amber-400/90 shrink-0">
          {icon}
        </div>
      </div>
      <div className="flex-1 min-h-[240px]">{children}</div>
    </div>
  );
}

function GlassTooltip({
  active,
  payload,
  label,
  valueLabel = 'Diamonds',
}: {
  active?: boolean;
  payload?: { name?: string; value?: number; color?: string; payload?: Record<string, unknown> }[];
  label?: string;
  valueLabel?: string;
}) {
  if (!active || !payload?.length) return null;

  return (
    <div className="rounded-xl border border-white/10 bg-black/90 px-3 py-2.5 shadow-2xl backdrop-blur-md">
      {label ? <p className="text-[10px] uppercase tracking-wider text-white/40 mb-1.5">{label}</p> : null}
      {payload.map((entry, i) => (
        <div key={i} className="flex items-center gap-2 text-sm">
          <span
            className="w-2 h-2 rounded-full shrink-0"
            style={{ backgroundColor: entry.color ?? CHART_PALETTE[i % CHART_PALETTE.length] }}
          />
          <span className="text-white/70">{entry.name ?? valueLabel}</span>
          <span className="font-bold tabular-nums ml-auto">
            {typeof entry.value === 'number' ? formatCompact(entry.value) : entry.value}
          </span>
        </div>
      ))}
    </div>
  );
}

export function DashboardCharts({ hierarchy, analytics, role }: DashboardChartsProps) {
  const data = mergeAnalytics(hierarchy, analytics, role);
  const networkTotal = data.network.reduce((sum, row) => sum + row.value, 0);
  const hasTrend = data.commission_trend.some((row) => row.diamonds > 0);

  const agencyChart = data.agency_performance.slice(0, 8).map((row) => ({
    ...row,
    shortName: truncateLabel(row.name, 12),
  }));

  const hostsChart = data.top_hosts.map((row) => ({
    ...row,
    shortName: truncateLabel(row.username, 10),
  }));

  return (
    <section className="space-y-4">
      <div className="flex items-end justify-between gap-4">
        <div>
          <p className="text-[10px] font-black uppercase tracking-[0.2em] text-purple-400/80">Insights</p>
          <h2 className="text-xl md:text-2xl font-black tracking-tight mt-1">Network analytics</h2>
        </div>
        <p className="text-xs text-white/30 hidden sm:block">Period {data.period_id}</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Network breakdown" subtitle="Your full subtree" icon={<Users size={18} />}>
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={data.network}
                dataKey="value"
                nameKey="name"
                cx="50%"
                cy="50%"
                innerRadius="52%"
                outerRadius="78%"
                paddingAngle={3}
                stroke="rgba(0,0,0,0.4)"
                strokeWidth={2}
              >
                {data.network.map((entry, i) => (
                  <Cell key={entry.name} fill={entry.color ?? CHART_PALETTE[i % CHART_PALETTE.length]} />
                ))}
              </Pie>
              <Tooltip content={<GlassTooltip valueLabel="Count" />} />
              <Legend
                verticalAlign="bottom"
                iconType="circle"
                formatter={(value) => <span className="text-xs text-white/50">{value}</span>}
              />
              <text x="50%" y="46%" textAnchor="middle" fill="rgba(255,255,255,0.35)" fontSize={10}>
                TOTAL
              </text>
              <text x="50%" y="54%" textAnchor="middle" fill="#fff" fontSize={22} fontWeight={800}>
                {networkTotal}
              </text>
            </PieChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard
          title="Commission trend"
          subtitle={hasTrend ? 'Last 14 days · gift commission' : 'Apply migration for daily trend'}
          icon={<TrendingUp size={18} />}
        >
          {hasTrend ? (
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={data.commission_trend} margin={{ top: 8, right: 8, left: -16, bottom: 0 }}>
                <defs>
                  <linearGradient id="commissionFill" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#a855f7" stopOpacity={0.45} />
                    <stop offset="100%" stopColor="#a855f7" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid stroke={GRID} vertical={false} />
                <XAxis dataKey="label" tick={AXIS} axisLine={false} tickLine={false} />
                <YAxis tick={AXIS} axisLine={false} tickLine={false} tickFormatter={formatCompact} />
                <Tooltip content={<GlassTooltip />} />
                <Area
                  type="monotone"
                  dataKey="diamonds"
                  name="Commission"
                  stroke="#c084fc"
                  strokeWidth={2.5}
                  fill="url(#commissionFill)"
                  dot={{ r: 3, fill: '#a855f7', strokeWidth: 0 }}
                  activeDot={{ r: 5, fill: '#f59e0b' }}
                />
              </AreaChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-full flex flex-col items-center justify-center text-center px-4">
              <div className="w-14 h-14 rounded-2xl bg-purple-500/10 flex items-center justify-center mb-4">
                <TrendingUp className="text-purple-400/60" size={28} />
              </div>
              <p className="text-sm text-white/50 max-w-xs">
                Daily commission chart will appear once chart analytics migration is applied.
              </p>
              <p className="text-xs text-white/25 mt-2 font-mono">20250621130000_super_bd_chart_analytics.sql</p>
            </div>
          )}
        </ChartCard>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <ChartCard
          title="Agency performance"
          subtitle="Period charm by agency"
          icon={<BarChart3 size={18} />}
          className="lg:col-span-2"
        >
          {agencyChart.length ? (
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={agencyChart} margin={{ top: 8, right: 8, left: -16, bottom: 0 }}>
                <CartesianGrid stroke={GRID} vertical={false} />
                <XAxis dataKey="shortName" tick={AXIS} axisLine={false} tickLine={false} />
                <YAxis tick={AXIS} axisLine={false} tickLine={false} tickFormatter={formatCompact} />
                <Tooltip
                  content={
                    <GlassTooltip
                      valueLabel="Charm"
                      active
                      payload={undefined}
                      label={undefined}
                    />
                  }
                  labelFormatter={(_, payload) =>
                    (payload?.[0]?.payload as { name?: string })?.name ?? ''
                  }
                />
                <Bar dataKey="diamonds" name="Charm" radius={[6, 6, 0, 0]} maxBarSize={48}>
                  {agencyChart.map((_, i) => (
                    <Cell key={i} fill={CHART_PALETTE[i % CHART_PALETTE.length]} fillOpacity={0.9} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <EmptyState message="No agencies in your network yet." />
          )}
        </ChartCard>

        <ChartCard title="Earnings split" subtitle="Commission vs salary" icon={<Gem size={18} />}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={data.earnings} margin={{ top: 8, right: 8, left: -16, bottom: 0 }}>
              <CartesianGrid stroke={GRID} vertical={false} />
              <XAxis dataKey="name" tick={AXIS} axisLine={false} tickLine={false} interval={0} />
              <YAxis tick={AXIS} axisLine={false} tickLine={false} tickFormatter={formatCompact} />
              <Tooltip content={<GlassTooltip />} />
              <Bar dataKey="diamonds" name="Diamonds" radius={[6, 6, 0, 0]} maxBarSize={56}>
                {data.earnings.map((entry) => (
                  <Cell key={entry.name} fill={entry.fill} fillOpacity={0.95} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>

      <ChartCard
        title="Top hosts"
        subtitle="Highest period charm in your subtree"
        icon={<Users size={18} />}
        className="min-h-[360px]"
      >
        {hostsChart.length ? (
          <ResponsiveContainer width="100%" height={280}>
            <BarChart
              layout="vertical"
              data={hostsChart}
              margin={{ top: 4, right: 16, left: 4, bottom: 4 }}
            >
              <CartesianGrid stroke={GRID} horizontal={false} />
              <XAxis type="number" tick={AXIS} axisLine={false} tickLine={false} tickFormatter={formatCompact} />
              <YAxis
                type="category"
                dataKey="shortName"
                tick={AXIS}
                axisLine={false}
                tickLine={false}
                width={72}
              />
              <Tooltip
                content={<GlassTooltip valueLabel="Charm" />}
                labelFormatter={(_, payload) => {
                  const row = payload?.[0]?.payload as { username?: string; agency_name?: string };
                  return row ? `${row.username} · ${row.agency_name}` : '';
                }}
              />
              <Bar dataKey="diamonds" name="Charm" radius={[0, 6, 6, 0]} maxBarSize={22}>
                {hostsChart.map((_, i) => (
                  <Cell
                    key={i}
                    fill={i === 0 ? '#f59e0b' : CHART_PALETTE[(i + 2) % CHART_PALETTE.length]}
                    fillOpacity={0.92}
                  />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        ) : (
          <EmptyState message="No host activity recorded this period." />
        )}
      </ChartCard>
    </section>
  );
}

function EmptyState({ message }: { message: string }) {
  return (
    <div className="h-full flex items-center justify-center text-sm text-white/40 text-center px-6">
      {message}
    </div>
  );
}
