import Link from 'next/link';
import { fetchHierarchy, fetchChartAnalytics } from '@/lib/auth/require-super-bd';
import { getPortalPermissions, isPortalRole } from '@/lib/permissions';
import { StatCard } from '@/components/StatCard';
import { HierarchyTree } from '@/components/HierarchyTree';
import { DashboardCharts } from '@/components/DashboardCharts';
import type { HierarchyResponse, ChartAnalytics } from '@/lib/types';
import {
  Users,
  Network,
  Building2,
  Mic,
  ClipboardList,
  Gem,
  ArrowRight,
} from 'lucide-react';

export default async function DashboardPage() {
  const [data, analytics] = await Promise.all([
    fetchHierarchy() as Promise<HierarchyResponse>,
    fetchChartAnalytics() as Promise<ChartAnalytics | null>,
  ]);
  const { me, stats, tree, period_id } = data;
  const role = isPortalRole(me.role) ? me.role : 'bd';
  const permissions = getPortalPermissions(role);

  return (
    <div className="space-y-8">
      <div className="space-y-2">
        <p className="text-[10px] font-black uppercase tracking-[0.2em] text-amber-400/80">Welcome back</p>
        <h1 className="text-3xl md:text-4xl font-black italic tracking-tight">{me.username}</h1>
        <p className="text-sm text-white/50">
          <span className="text-amber-300/90">{permissions.label}</span>
          {' · '}
          Staff code <span className="font-mono text-amber-300/80">{me.staff_code}</span> · Period {period_id}
        </p>
      </div>

      <div
        className={`grid gap-3 md:gap-4 ${
          permissions.showBdAdminStat
            ? 'grid-cols-2 lg:grid-cols-4'
            : permissions.showBdStat
              ? 'grid-cols-2 lg:grid-cols-3'
              : 'grid-cols-2'
        }`}
      >
        {permissions.showBdAdminStat && (
          <StatCard label="Country Admins" value={stats.bd_admin_count} icon={Users} />
        )}
        {permissions.showBdStat && <StatCard label="BDs" value={stats.bd_count} icon={Network} />}
        <StatCard label="Agencies" value={stats.agency_count} icon={Building2} />
        <StatCard label="Hosts" value={stats.host_count} icon={Mic} />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-3 md:gap-4">
        <StatCard label="Pending requests" value={stats.pending_applications} icon={ClipboardList} accent="text-orange-400" />
        <StatCard
          label="Gift commission"
          value={stats.commission_diamonds.toLocaleString()}
          icon={Gem}
          accent="text-purple-400"
        />
        <StatCard
          label="Salary paid"
          value={stats.salary_diamonds.toLocaleString()}
          icon={Gem}
          accent="text-emerald-400"
        />
      </div>

      <div className="flex flex-wrap gap-3">
        <Link href="/network" className="btn-primary text-sm">
          Network Hub
          <ArrowRight size={16} />
        </Link>
        <Link href="/applications" className="btn-ghost text-sm">
          Review requests
        </Link>
        {permissions.canCreateStaff && permissions.createStaffLabel && (
          <Link href="/create-staff" className="btn-ghost text-sm">
            {permissions.createStaffLabel}
          </Link>
        )}
      </div>

      <DashboardCharts hierarchy={data} analytics={analytics} role={role} />

      <section className="glass-card p-5 md:p-8">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-black uppercase tracking-widest text-white/70">Your network</h2>
          <Link href="/network" className="text-xs text-amber-400 hover:underline">
            Network Hub
          </Link>
        </div>
        <HierarchyTree
          staff={tree.staff}
          agencies={tree.agencies}
          hosts={tree.hosts}
          rootStaffId={me.staff_id}
          compact
        />
      </section>
    </div>
  );
}
