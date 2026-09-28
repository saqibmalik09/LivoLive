import { supabaseAdmin } from '@/lib/supabase';
import { cn } from '@/lib/cn';
import {
  Building2,
  Network,
  ScrollText,
  ShoppingBag,
  Users,
} from 'lucide-react';
import Link from 'next/link';

async function getDashboardStats() {
  const [
    usersRes,
    staffRes,
    agenciesRes,
    superBdRes,
    countyAdminRes,
    assistantRes,
    csRes,
    bdRes,
  ] = await Promise.all([
    supabaseAdmin.from('users').select('*', { count: 'exact', head: true }),
    supabaseAdmin
      .from('business_staff')
      .select('*', { count: 'exact', head: true })
      .eq('is_active', true),
    supabaseAdmin.from('agencies').select('*', { count: 'exact', head: true }),
    supabaseAdmin
      .from('business_staff')
      .select('*', { count: 'exact', head: true })
      .eq('role', 'super_bd')
      .eq('is_active', true),
    supabaseAdmin
      .from('business_staff')
      .select('*', { count: 'exact', head: true })
      .in('role', ['county_admin', 'bd_admin'])
      .eq('is_active', true),
    supabaseAdmin
      .from('business_staff')
      .select('*', { count: 'exact', head: true })
      .eq('role', 'assistant')
      .eq('is_active', true),
    supabaseAdmin
      .from('business_staff')
      .select('*', { count: 'exact', head: true })
      .eq('role', 'customer_service')
      .eq('is_active', true),
    supabaseAdmin
      .from('business_staff')
      .select('*', { count: 'exact', head: true })
      .eq('role', 'bd')
      .eq('is_active', true),
  ]);

  return {
    users: usersRes.count ?? 0,
    staff: staffRes.count ?? 0,
    agencies: agenciesRes.count ?? 0,
    hierarchy: {
      super_bd: superBdRes.count ?? 0,
      county_admin: countyAdminRes.count ?? 0,
      assistant: assistantRes.count ?? 0,
      customer_service: csRes.count ?? 0,
      bd: bdRes.count ?? 0,
    },
  };
}

export default async function MasterDashboard() {
  const stats = await getDashboardStats();

  return (
    <div className="space-y-12">
      <header>
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-purple-400 to-blue-400 tracking-tighter">
          SK Live Master Panel
        </h1>
        <p className="text-white/60 mt-2 font-medium">
          Limited ops: users, staff chain (diamonds &amp; salary), agencies, shop grants
        </p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <StatsCard
          title="Users"
          value={stats.users.toLocaleString()}
          icon={Users}
          trend="Registered accounts"
          color="from-purple-500/25 to-transparent"
          iconColor="text-purple-400"
          href="/users"
        />
        <StatsCard
          title="Active Staff"
          value={stats.staff.toLocaleString()}
          icon={Network}
          trend="business_staff is_active"
          color="from-amber-500/25 to-transparent"
          iconColor="text-amber-400"
          href="/staff"
        />
        <StatsCard
          title="Agencies"
          value={stats.agencies.toLocaleString()}
          icon={Building2}
          trend="All agencies"
          color="from-emerald-500/25 to-transparent"
          iconColor="text-emerald-400"
          href="/agencies"
        />
      </div>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="glass-card">
          <h3 className="text-xl font-bold mb-6 flex items-center gap-2">
            <Network className="text-amber-400" />
            Hierarchy summary
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <HierarchyStat label="Super Admin" value={stats.hierarchy.super_bd} />
            <HierarchyStat label="Admin" value={stats.hierarchy.county_admin} />
            <HierarchyStat label="Assistant" value={stats.hierarchy.assistant} />
            <HierarchyStat label="Customer Service" value={stats.hierarchy.customer_service} />
            <HierarchyStat label="BD" value={stats.hierarchy.bd} />
          </div>
        </div>

        <div className="glass-card">
          <h3 className="text-xl font-bold mb-6">Quick links</h3>
          <div className="grid grid-cols-2 gap-4">
            <ActionButton label="Users" icon={Users} href="/users" color="text-purple-400" />
            <ActionButton label="Staff" icon={Network} href="/staff" color="text-amber-400" />
            <ActionButton label="Agencies" icon={Building2} href="/agencies" color="text-emerald-400" />
            <ActionButton label="Shop Grant" icon={ShoppingBag} href="/shop" color="text-orange-400" />
            <ActionButton label="Audit Log" icon={ScrollText} href="/audit" color="text-white/60" />
          </div>
        </div>
      </section>
    </div>
  );
}

function StatsCard({
  title,
  value,
  icon: Icon,
  trend,
  color,
  iconColor,
  href,
}: {
  title: string;
  value: string;
  icon: React.ComponentType<{ size?: number; strokeWidth?: number }>;
  trend: string;
  color: string;
  iconColor: string;
  href: string;
}) {
  return (
    <Link
      href={href}
      className={`glass-card bg-gradient-to-br ${color} hover:border-white/20 hover:shadow-purple-500/10 transition-all cursor-pointer group relative overflow-hidden block`}
    >
      <div className="absolute top-0 right-0 w-32 h-32 bg-white/5 blur-3xl -mr-16 -mt-16 rounded-full" />
      <div className="flex items-start justify-between relative z-10">
        <div>
          <p className="text-white/50 text-[10px] font-bold uppercase tracking-[0.2em] mb-2">
            {title}
          </p>
          <h2 className="text-4xl font-black tracking-tight">{value}</h2>
        </div>
        <div
          className={cn(
            'p-4 rounded-2xl bg-black/40 border border-white/5 group-hover:scale-110 transition-transform duration-500',
            iconColor,
          )}
        >
          <Icon size={28} strokeWidth={1.5} />
        </div>
      </div>
      <div className="mt-8 flex items-center gap-2 relative z-10">
        <div className="h-1 w-12 bg-white/10 rounded-full overflow-hidden">
          <div className="h-full bg-current w-2/3" />
        </div>
        <p className="text-[10px] font-bold text-white/40 uppercase tracking-wider">{trend}</p>
      </div>
    </Link>
  );
}

function HierarchyStat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-2xl bg-white/5 border border-white/5 px-4 py-3">
      <p className="text-[10px] font-black uppercase tracking-widest text-white/40">{label}</p>
      <p className="text-2xl font-black mt-1">{value.toLocaleString()}</p>
    </div>
  );
}

function ActionButton({
  label,
  icon: Icon,
  color = 'text-white',
  href = '#',
}: {
  label: string;
  icon: React.ComponentType<{ size?: number }>;
  color?: string;
  href?: string;
}) {
  return (
    <Link
      href={href}
      className="glass flex flex-col items-center justify-center p-6 rounded-[2rem] gap-3 hover:bg-white/5 transition-all group border border-white/5 hover:border-white/10 active:scale-95"
    >
      <div className={cn('p-3 rounded-xl bg-white/5 group-hover:bg-white/10 transition-colors', color)}>
        <Icon size={22} />
      </div>
      <span className="text-[10px] font-bold uppercase tracking-[0.15em] text-white/60 group-hover:text-white transition-colors">
        {label}
      </span>
    </Link>
  );
}
