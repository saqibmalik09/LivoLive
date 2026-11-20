import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import type { ReactNode } from "react";
import { ArrowLeft, Building2, Network, Users, Wallet, Banknote } from "lucide-react";
import {
  getStaffDrilldown,
  getStaffDrilldownMonthly,
  getStaffDrilldownWholeMonth,
  resolveBdPeriodId,
  ROLE_LABELS,
} from "@/lib/salary-hub/queries";
import { AmountValue } from "@/components/AmountValue";
import { HubPeriodBanner } from "@/components/HubPeriodBanner";
import { withPeriod } from "@/lib/salary-hub/constants";
import { getHubPeriod } from "@/lib/salary-hub/period";
import { formatUsd } from "@/lib/salary-hub/salary-calc";
export default async function SalaryHubDrillPage({
  params,
  searchParams,
}: {
  params: Promise<{
    kind: string;
    id: string;
  }>;
  searchParams: Promise<{
    period?: string;
  }>;
}) {
  const { kind, id } = await params;
  const sp = await searchParams;
  const period = await getHubPeriod(sp.period);
  if (kind === "agency") {
    redirect(withPeriod(`/agencies/${id}`, period));
  }
  if (kind !== "staff") notFound();
  let data = await getStaffDrilldown(id, period);
  if (!data) notFound();
  let displayPeriod = period;
  if (data.staff.role === "bd") {
    const bdPeriod = await resolveBdPeriodId(period);
    if (bdPeriod.endsWith("-M") && bdPeriod !== period) {
      const monthly = await getStaffDrilldownMonthly(id, bdPeriod);
      if (monthly) {
        data = monthly;
        displayPeriod = bdPeriod;
      }
    }
  }
  if (data.staff.role === "super_bd") {
    const monthPeriod = `${period.slice(0, 7)}-M`;
    const monthly = await getStaffDrilldownWholeMonth(id, monthPeriod);
    if (monthly) {
      data = monthly;
      displayPeriod = monthPeriod;
    }
  }
  const hostsPeriod = data.staff.role === "super_bd" ? displayPeriod : period;
  const { staff, parent, countyAdmins, bds, agencies, hosts, totals } = data;
  return (
    <div className="space-y-10 pb-32">
      <Link
        href={`/salary-hub?role=${staff.role}&period=${period}`}
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Salary Hub</span>
      </Link>

      <HubPeriodBanner
        period={displayPeriod}
        hubHref={`/salary-hub?role=${staff.role}&period=${period}`}
      />

      <div className="glass-card p-8 space-y-4">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-emerald-400">
              {ROLE_LABELS[staff.role] || staff.role}
            </p>
            <h1 className="text-4xl font-black italic tracking-tighter">{staff.username}</h1>
            <p className="text-white/40 text-sm mt-1">
              Code {staff.staff_code || "—"}
              {staff.short_id ? ` · ID ${staff.short_id}` : ""}
              {parent
                ? ` · Parent ${parent.username} (${ROLE_LABELS[parent.role] || parent.role})`
                : ""}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Link
              href={`/staff/${staff.id}`}
              className="px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest bg-white/5 border border-white/10 hover:border-white/25"
            >
              Staff page
            </Link>
            <Link
              href="/salary-runs"
              className="px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest bg-emerald-500/15 border border-emerald-400/30 text-emerald-300"
            >
              Salary runs
            </Link>
            <Link
              href="/settings/bd-center"
              className="px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest bg-amber-500/10 border border-amber-400/20 text-amber-200"
            >
              BD center
            </Link>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-4 gap-3">
        <Stat icon={Network} label="County" value={totals.countyAdminCount} tint="text-amber-400" />
        <Stat icon={Network} label="BDs" value={totals.bdCount} tint="text-orange-400" />
        <Stat icon={Building2} label="Agencies" value={totals.agencyCount} tint="text-pink-400" />
        <Stat icon={Users} label="Hosts" value={totals.hostCount} tint="text-blue-400" />
        <Stat
          icon={Banknote}
          label="Diamonds"
          value={totals.periodDiamonds.toLocaleString()}
          tint="text-emerald-400"
        />
        <Stat
          icon={Banknote}
          label="Charm"
          value={totals.periodCharm.toLocaleString()}
          tint="text-amber-400"
        />
        <Stat
          icon={Wallet}
          label="Host $"
          value={formatUsd(totals.estimatedHostUsd)}
          tint="text-emerald-300"
        />
        <Stat
          icon={Wallet}
          label="Agency $"
          value={formatUsd(totals.estimatedAgencyUsd)}
          tint="text-pink-300"
        />
        <Stat
          icon={Wallet}
          label="Paid"
          value={totals.periodSalaryPaid.toLocaleString()}
          tint="text-violet-300"
        />
      </div>

      {countyAdmins.length > 0 && (
        <Section title="County Admins" count={countyAdmins.length}>
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
              Owner {a.owner_username || "—"} · {a.hostCount} hosts
            </p>
            <p className="text-sm font-black text-emerald-400 mt-2">
              {formatUsd(a.estimatedUsd)}
              <span className="text-[10px] font-bold text-white/30 uppercase ml-2">
                LV {a.salaryLevel}
              </span>
            </p>
          </Link>
        ))}
        {agencies.length === 0 && (
          <p className="text-white/30 text-sm col-span-full">No sponsored agencies in this tree.</p>
        )}
      </Section>

      <Section title={`Hosts · ${hostsPeriod}`} count={hosts.length}>
        {hosts.slice(0, 100).map((h) => (
          <Link
            key={`${h.agency_id}-${h.user_id}`}
            href={withPeriod(`/agencies/${h.agency_id}/hosts/${h.user_id}`, period)}
            className="glass-card p-5 hover:border-blue-500/25 transition-colors"
          >
            <p className="text-[10px] font-black uppercase tracking-widest text-blue-400/70">
              {h.role}
            </p>
            <p className="font-black text-lg">{h.username}</p>
            <p className="text-xs text-white/40 mt-1 break-all">
              {h.agency_name} ·{" "}
              <span className="text-emerald-400 font-bold tabular-nums">
                {formatUsd(h.estimatedUsd)}
              </span>{" "}
              host · charm{" "}
              <span className="text-amber-400/90 font-bold tabular-nums">
                {formatUsd(h.charmSalaryUsd)}
              </span>
            </p>
          </Link>
        ))}
        {hosts.length === 0 && (
          <p className="text-white/30 text-sm col-span-full">No hosts under this tree.</p>
        )}
        {hosts.length > 100 && (
          <p className="text-white/30 text-xs col-span-full">
            Showing first 100 of {hosts.length} hosts.
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
      <AmountValue value={value} size="md" className={tint} />
      <p className="text-[9px] font-black uppercase tracking-widest text-white/30 mt-2">{label}</p>
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
        {title}{" "}
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
      href={`/salary-hub/staff/${item.id}?period=${period}`}
      className="glass-card p-5 hover:border-emerald-500/25 transition-colors"
    >
      <p className="text-[10px] font-black uppercase tracking-widest text-emerald-400/70">
        {ROLE_LABELS[item.role] || item.role}
      </p>
      <p className="font-black text-lg">{item.username}</p>
      <p className="text-xs text-white/40 mt-1">
        Code {item.staff_code || "—"} · {item.agencyCount} agencies · {item.hostCount} hosts
      </p>
    </Link>
  );
}
