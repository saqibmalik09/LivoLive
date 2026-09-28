import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { ReactNode } from 'react';
import {
  ArrowLeft,
  Building2,
  Network,
  Users,
  Wallet,
  Banknote,
  Gem,
} from 'lucide-react';
import {
  getStaffDrilldown,
  ROLE_LABELS,
  periodOptions,
} from '@/lib/salary-hub/queries';
import { withPeriod } from '@/lib/salary-hub/constants';
import { getHubPeriod } from '@/lib/salary-hub/period';
import { formatUsd } from '@/lib/salary-hub/salary-calc';

export default async function MasterStaffDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ period?: string }>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const period = await getHubPeriod(sp.period);

  const data = await getStaffDrilldown(id, period);
  if (!data) notFound();

  const {
    staff,
    parent,
    countyAdmins,
    bds,
    assistants,
    customerService,
    agencies,
    hosts,
    totals,
  } = data;

  const periods = periodOptions();

  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/staff"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft
          size={16}
          className="group-hover:-translate-x-1 transition-transform"
        />
        <span className="text-[10px] font-black uppercase tracking-widest">
          Staff
        </span>
      </Link>

      <div className="glass-card p-4 flex flex-wrap gap-2 items-center">
        <p className="text-[10px] font-black uppercase tracking-widest text-white/40 mr-2">
          Period
        </p>
        {periods.slice(0, 6).map((p) => (
          <Link
            key={p}
            href={`/staff/${id}?period=${p}`}
            className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest ${
              p === period
                ? 'bg-amber-500 text-black'
                : 'bg-white/5 text-white/50 hover:bg-white/10'
            }`}
          >
            {p}
          </Link>
        ))}
      </div>

      <div className="glass-card p-8 space-y-4">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-amber-400">
              {ROLE_LABELS[staff.role] || staff.role}
            </p>
            <h1 className="text-4xl font-black italic tracking-tighter">
              {staff.username}
            </h1>
            <p className="text-white/40 text-sm mt-1">
              Code {staff.staff_code || '—'}
              {staff.short_id ? ` · ID ${staff.short_id}` : ''}
              {parent
                ? ` · Parent ${parent.username} (${ROLE_LABELS[parent.role] || parent.role})`
                : ''}
            </p>
            <p className="text-emerald-300/90 text-sm mt-2 font-bold flex items-center gap-2">
              <Gem size={14} />
              Wallet diamonds: {staff.diamonds.toLocaleString()}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            {staff.short_id != null && (
              <Link
                href={`/users?search=${encodeURIComponent(String(staff.short_id))}`}
                className="px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest bg-white/5 border border-white/10 hover:border-white/25"
              >
                Find user
              </Link>
            )}
            <Link
              href={withPeriod(
                `/agencies${staff.role === 'bd' ? `?sponsor_staff_id=${staff.id}` : ''}`,
                period,
              )}
              className="px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest bg-emerald-500/15 border border-emerald-400/30 text-emerald-300"
            >
              Agencies
            </Link>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 gap-3">
        <Stat icon={Network} label="Admins" value={totals.countyAdminCount} tint="text-amber-400" />
        <Stat icon={Network} label="BDs" value={totals.bdCount} tint="text-orange-400" />
        <Stat icon={Users} label="Assistants" value={totals.assistantCount} tint="text-sky-400" />
        <Stat icon={Users} label="CS" value={totals.customerServiceCount} tint="text-cyan-400" />
        <Stat icon={Building2} label="Agencies" value={totals.agencyCount} tint="text-pink-400" />
        <Stat icon={Users} label="Hosts" value={totals.hostCount} tint="text-blue-400" />
        <Stat
          icon={Banknote}
          label="Period diamonds"
          value={totals.periodDiamonds.toLocaleString()}
          tint="text-emerald-400"
        />
        <Stat
          icon={Banknote}
          label="Period charm"
          value={totals.periodCharm.toLocaleString()}
          tint="text-amber-400"
        />
        <Stat
          icon={Wallet}
          label="Host salary $"
          value={formatUsd(totals.estimatedHostUsd)}
          tint="text-emerald-300"
        />
        <Stat
          icon={Wallet}
          label="Agency salary $"
          value={formatUsd(totals.estimatedAgencyUsd)}
          tint="text-pink-300"
        />
        <Stat
          icon={Wallet}
          label="Paid (host)"
          value={totals.periodSalaryPaid.toLocaleString()}
          tint="text-violet-300"
        />
      </div>

      {countyAdmins.length > 0 && (
        <Section title="County / Admins" count={countyAdmins.length}>
          {countyAdmins.map((s) => (
            <StaffCard key={s.id} item={s} period={period} />
          ))}
        </Section>
      )}

      {bds.length > 0 && (
        <Section title="BDs" count={bds.length}>
          {bds.map((s) => (
            <StaffCard key={s.id} item={s} period={period} />
          ))}
        </Section>
      )}

      {assistants.length > 0 && (
        <Section title="Assistants" count={assistants.length}>
          {assistants.map((s) => (
            <StaffCard key={s.id} item={s} period={period} />
          ))}
        </Section>
      )}

      {customerService.length > 0 && (
        <Section title="Customer Service" count={customerService.length}>
          {customerService.map((s) => (
            <StaffCard key={s.id} item={s} period={period} />
          ))}
        </Section>
      )}

      <Section title="Agencies" count={agencies.length}>
        {agencies.map((a) => (
          <Link
            key={a.id}
            href={withPeriod(`/agencies/${a.id}`, period)}
            className="glass-card p-5 hover:border-pink-500/25 transition-colors"
          >
            <p className="text-[10px] font-black uppercase tracking-widest text-pink-400/70">
              Agency
            </p>
            <p className="font-black text-lg">{a.name}</p>
            <p className="text-xs text-white/40 mt-1">
              Owner {a.owner_username || '—'} · BD {a.sponsor_username || '—'} ·{' '}
              {a.hostCount} hosts
            </p>
            <p className="text-sm font-black text-emerald-400 mt-2">
              {formatUsd(a.estimatedUsd)}
              <span className="text-[10px] font-bold text-white/30 uppercase ml-2">
                LV {a.salaryLevel} · charm {a.periodCharm.toLocaleString()}
              </span>
            </p>
          </Link>
        ))}
        {agencies.length === 0 && (
          <p className="text-white/30 text-sm col-span-full">
            No sponsored agencies in this tree.
          </p>
        )}
      </Section>

      <Section title={`Hosts · ${period}`} count={hosts.length}>
        {hosts.slice(0, 120).map((h) => (
          <Link
            key={`${h.agency_id}-${h.user_id}`}
            href={`/users/${h.user_id}`}
            className="glass-card p-5 hover:border-blue-500/25 transition-colors"
          >
            <p className="text-[10px] font-black uppercase tracking-widest text-blue-400/70">
              {h.role}
            </p>
            <p className="font-black text-lg">{h.username}</p>
            <p className="text-xs text-white/40 mt-1">
              {h.agency_name}
              {h.short_id != null ? ` · UID ${h.short_id}` : ''}
            </p>
            <p className="text-xs mt-2 space-x-2">
              <span className="text-emerald-400 font-bold tabular-nums">
                {h.periodDiamonds.toLocaleString()} dia
              </span>
              <span className="text-amber-400/90 font-bold tabular-nums">
                {h.periodCharm.toLocaleString()} charm
              </span>
              <span className="text-white/70 font-bold tabular-nums">
                {formatUsd(h.estimatedUsd)} salary
              </span>
            </p>
          </Link>
        ))}
        {hosts.length === 0 && (
          <p className="text-white/30 text-sm col-span-full">No hosts under this tree.</p>
        )}
        {hosts.length > 120 && (
          <p className="text-white/30 text-xs col-span-full">
            Showing first 120 of {hosts.length} hosts.
          </p>
        )}
      </Section>
    </div>
  );
}

function Stat({
  icon: Icon,
  label,
  value,
  tint,
}: {
  icon: typeof Users;
  label: string;
  value: string | number;
  tint: string;
}) {
  return (
    <div className="glass-card p-4 text-center min-w-0 overflow-hidden">
      <Icon size={16} className={`mx-auto mb-2 shrink-0 ${tint}`} />
      <p className={`text-xl font-black tabular-nums truncate ${tint}`}>{value}</p>
      <p className="text-[9px] font-black uppercase tracking-widest text-white/30 mt-2">
        {label}
      </p>
    </div>
  );
}

function Section({
  title,
  count,
  children,
}: {
  title: string;
  count: number;
  children: ReactNode;
}) {
  return (
    <section className="space-y-4">
      <h2 className="text-xl font-black uppercase tracking-widest text-white/60">
        {title}{' '}
        <span className="text-white/30 font-bold normal-case tracking-normal text-sm">
          ({count})
        </span>
      </h2>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">{children}</div>
    </section>
  );
}

function StaffCard({
  item,
  period,
}: {
  item: {
    id: string;
    role: string;
    username: string;
    staff_code: string | null;
    agencyCount: number;
    hostCount: number;
  };
  period: string;
}) {
  return (
    <Link
      href={`/staff/${item.id}?period=${period}`}
      className="glass-card p-5 hover:border-amber-500/25 transition-colors"
    >
      <p className="text-[10px] font-black uppercase tracking-widest text-amber-400/70">
        {ROLE_LABELS[item.role] || item.role}
      </p>
      <p className="font-black text-lg">{item.username}</p>
      <p className="text-xs text-white/40 mt-1">
        Code {item.staff_code || '—'} · {item.agencyCount} agencies · {item.hostCount}{' '}
        hosts
      </p>
    </Link>
  );
}
