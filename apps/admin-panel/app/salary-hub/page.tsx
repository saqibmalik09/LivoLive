import Link from "next/link";
import { ArrowLeft, Banknote, Building2, Network, Users } from "lucide-react";
import { SalaryHubFilters } from "@/components/SalaryHubFilters";
import { AmountValue } from "@/components/AmountValue";
import { PeriodSalaryOverviewPanel } from "@/components/PeriodSalaryOverview";
import {
  getPeriodSalaryOverview,
  listAgencies,
  listHosts,
  listStaffByRole,
  listStaffMatching,
  enrichBdStaffPayStatus,
  ROLE_LABELS,
  type SalaryHubRole,
  type StaffListItem,
  type AgencyListItem,
  type HostListItem,
} from "@/lib/salary-hub/queries";
import { periodToBdMonth, withPeriod } from "@/lib/salary-hub/constants";
import { getHubPeriod } from "@/lib/salary-hub/period";
import { formatUsd } from "@/lib/salary-hub/salary-calc";
import { SalaryEntityPayButton } from "@/components/SalaryEntityPayButton";
function parseRole(raw?: string): SalaryHubRole {
  if (
    raw === "super_bd" ||
    raw === "bd_admin" ||
    raw === "bd" ||
    raw === "agency" ||
    raw === "host"
  ) {
    return raw;
  }
  return "super_bd";
}
function StaffCards({
  staff,
  roleHint,
  period,
}: {
  staff: StaffListItem[];
  roleHint: SalaryHubRole | "search";
  period: string;
}) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      {staff.map((s) => (
        <div
          key={s.id}
          className="glass-card p-6 hover:border-emerald-500/30 transition-colors group relative"
        >
          <div className="absolute top-4 right-4 z-10">
            {s.role === "bd" ? (
              <SalaryEntityPayButton
                kind="bd"
                periodId={period}
                entityId={s.id}
                label={s.username}
                amountUsd={s.bdPayableUsd}
                alreadyPaid={s.bdSettlementPaid}
                disabled={!s.is_active || !(s.bdPayableUsd && s.bdPayableUsd > 0)}
              />
            ) : null}
          </div>
          <Link href={`/salary-hub/staff/${s.id}?period=${period}`} className="block">
            <div className="flex items-start justify-between gap-3 pr-16">
              <div>
                <p className="text-[10px] font-black uppercase tracking-widest text-emerald-400/70">
                  {ROLE_LABELS[s.role] || s.role}
                </p>
                <h2 className="text-xl font-black group-hover:text-emerald-200 transition-colors">
                  {s.username}
                </h2>
                <p className="text-xs text-white/40 mt-1">
                  Code {s.staff_code || "—"}
                  {s.short_id ? ` · ID ${s.short_id}` : ""}
                </p>
                {(roleHint === "bd" || s.role === "bd") && s.bdPayableUsd != null ? (
                  <p className="text-xs text-amber-300/80 mt-1 font-bold">
                    Payable {formatUsd(s.bdPayableUsd ?? 0)} · {periodToBdMonth(period)}
                  </p>
                ) : null}
              </div>
              <span
                className={`text-[9px] font-black uppercase tracking-widest px-2 py-1 rounded-lg ${
                  s.is_active ? "bg-emerald-500/15 text-emerald-300" : "bg-white/5 text-white/30"
                }`}
              >
                {s.is_active ? "Active" : "Off"}
              </span>
            </div>
            <div className="mt-5 grid grid-cols-3 gap-3 text-center">
              <div className="rounded-xl bg-black/30 border border-white/5 py-3">
                <Network size={14} className="mx-auto text-amber-400/70 mb-1" />
                <p className="text-lg font-black">{s.childStaffCount}</p>
                <p className="text-[9px] uppercase tracking-widest text-white/30">Team</p>
              </div>
              <div className="rounded-xl bg-black/30 border border-white/5 py-3">
                <Building2 size={14} className="mx-auto text-pink-400/70 mb-1" />
                <p className="text-lg font-black">{s.agencyCount}</p>
                <p className="text-[9px] uppercase tracking-widest text-white/30">Agencies</p>
              </div>
              <div className="rounded-xl bg-black/30 border border-white/5 py-3">
                <Users size={14} className="mx-auto text-blue-400/70 mb-1" />
                <p className="text-lg font-black">{s.hostCount}</p>
                <p className="text-[9px] uppercase tracking-widest text-white/30">Hosts</p>
              </div>
            </div>
          </Link>
        </div>
      ))}
      {staff.length === 0 && <p className="text-white/30 text-sm">No staff matched.</p>}
    </div>
  );
}
function AgencyCards({ agencies, period }: { agencies: AgencyListItem[]; period: string }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      {agencies.map((a) => (
        <div
          key={a.id}
          className="glass-card p-6 hover:border-pink-500/30 transition-colors relative"
        >
          <div className="absolute top-4 right-4 z-10">
            <SalaryEntityPayButton
              kind="agency"
              periodId={period}
              entityId={a.id}
              label={a.name}
              amountUsd={a.estimatedUsd}
              alreadyPaid={a.settlementPaid}
              disabled={!a.is_active || a.estimatedUsd <= 0}
            />
          </div>
          <Link href={withPeriod(`/agencies/${a.id}`, period)} className="block">
            <div className="flex items-start justify-between gap-3 min-w-0 pr-16">
              <div className="min-w-0 flex-1">
                <p className="text-[10px] font-black uppercase tracking-widest text-pink-400/70">
                  Agency{a.salaryLevel ? ` · LV ${a.salaryLevel}` : ""}
                </p>
                <h2 className="text-xl font-black">{a.name}</h2>
                <p className="text-xs text-white/40 mt-1">
                  Owner {a.owner_username || "—"}
                  {a.agency_code ? ` · ${a.agency_code}` : ""}
                </p>
                <p className="text-xs text-white/35 mt-1">
                  Sponsor {a.sponsor_username || "—"}
                  {a.sponsor_code ? ` (${a.sponsor_code})` : ""}
                </p>
                <p className="text-xs text-white/35 mt-1 break-all">
                  Charm {a.periodCharm.toLocaleString()} · Host ${a.charmSalaryUsd.toLocaleString()}{" "}
                  + Agent ${a.agentSalaryUsd.toLocaleString()}
                </p>
              </div>
              <div className="text-right min-w-0 max-w-[45%]">
                <AmountValue
                  value={formatUsd(a.estimatedUsd)}
                  size="md"
                  className="text-emerald-400 text-right"
                />
                <p className="text-[9px] uppercase tracking-widest text-white/30 mt-1">
                  Est. USD · {period}
                </p>
                <p className="text-sm font-black mt-2">{a.hostCount}</p>
                <p className="text-[9px] uppercase tracking-widest text-white/30">Hosts</p>
              </div>
            </div>
          </Link>
        </div>
      ))}
      {agencies.length === 0 && <p className="text-white/30 text-sm">No agencies matched.</p>}
    </div>
  );
}
function HostCards({ hosts, period }: { hosts: HostListItem[]; period: string }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      {hosts.map((h) => (
        <Link
          key={`${h.agency_id}-${h.user_id}`}
          href={withPeriod(`/agencies/${h.agency_id}/hosts/${h.user_id}`, period)}
          className="glass-card p-6 hover:border-blue-500/30 transition-colors"
        >
          <div className="flex items-start justify-between gap-3 min-w-0">
            <div className="min-w-0 flex-1">
              <p className="text-[10px] font-black uppercase tracking-widest text-blue-400/70">
                {h.role}
              </p>
              <h2 className="text-xl font-black truncate">{h.username}</h2>
              <p className="text-xs text-white/40 mt-1 truncate">
                {h.agency_name}
                {h.short_id ? ` · ID ${h.short_id}` : ""}
              </p>
            </div>
            <div className="text-right min-w-0 max-w-[55%] shrink-0">
              <AmountValue
                value={formatUsd(h.estimatedUsd)}
                size="md"
                className="text-emerald-400 text-right"
              />
              <p className="text-[9px] uppercase tracking-widest text-white/30 mt-1">
                Host salary · {period}
              </p>
              <p className="text-[10px] text-amber-400/80 mt-1 break-all">
                Charm {formatUsd(h.charmSalaryUsd)}
                {h.charmLevel ? ` · LV ${h.charmLevel}` : ""}
              </p>
              <AmountValue
                value={h.periodDiamonds}
                size="sm"
                className="text-white/50 text-right mt-2"
              />
              <p className="text-[9px] uppercase tracking-widest text-white/25">Diamonds</p>
            </div>
          </div>
        </Link>
      ))}
      {hosts.length === 0 && <p className="text-white/30 text-sm">No hosts matched.</p>}
    </div>
  );
}
export default async function SalaryHubPage({
  searchParams,
}: {
  searchParams: Promise<{
    role?: string;
    period?: string;
    q?: string;
  }>;
}) {
  const sp = await searchParams;
  const role = parseRole(sp.role);
  const period = await getHubPeriod(sp.period);
  const q = (sp.q || "").trim();
  const searching = q.length > 0;
  const staffRoles = role === "super_bd" || role === "bd_admin" || role === "bd";
  const [overview, staffRaw, agencies, hosts] = await Promise.all([
    getPeriodSalaryOverview(period),
    searching ? listStaffMatching(q) : staffRoles ? listStaffByRole(role) : Promise.resolve([]),
    searching || role === "agency"
      ? listAgencies(period, searching ? q : undefined)
      : Promise.resolve([]),
    searching || role === "host"
      ? listHosts(period, searching ? q : undefined)
      : Promise.resolve([]),
  ]);
  const staff =
    searching || role === "bd"
      ? await enrichBdStaffPayStatus(staffRaw, periodToBdMonth(period))
      : staffRaw;
  const showStaff = searching || staffRoles;
  const showAgencies = searching || role === "agency";
  const showHosts = searching || role === "host";
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Dashboard</span>
      </Link>

      <header>
        <span className="text-[10px] font-black uppercase tracking-[0.4em] text-emerald-500 mb-1 block">
          Hierarchy · Salary
        </span>
        <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
          <Banknote size={44} className="text-emerald-400" />
          Salary Hub
        </h1>
        <p className="text-white/50 mt-2 font-medium">
          Select a period once — Host + Agency + BD totals (est / paid) show below. Role tabs are
          for per-person detail. Use search to find any agency, host, or staff.
        </p>
      </header>

      <SalaryHubFilters role={role} period={period} q={q} />

      <PeriodSalaryOverviewPanel overview={overview} hubLinks />

      <p className="text-xs text-white/40">
        Cash vs salary mismatch / self-gift track:{" "}
        <Link
          href={`/salary-audit?period=${period}`}
          className="text-amber-300 font-bold hover:underline"
        >
          Open Salary Audit
        </Link>
      </p>

      {searching && (
        <p className="text-sm text-emerald-300/90 font-medium">
          Results for “{q}” · staff {staff.length} · agencies {agencies.length} · hosts{" "}
          {hosts.length}
        </p>
      )}

      {showStaff && (
        <section className="space-y-4">
          <p className="text-[10px] font-black uppercase tracking-widest text-white/30">
            {searching ? "Staff" : ROLE_LABELS[role]} · {staff.length}
          </p>
          <StaffCards staff={staff} roleHint={searching ? "search" : role} period={period} />
        </section>
      )}

      {showAgencies && (
        <section className="space-y-4">
          <p className="text-[10px] font-black uppercase tracking-widest text-white/30">
            Agencies · {agencies.length}
          </p>
          <AgencyCards agencies={agencies} period={period} />
        </section>
      )}

      {showHosts && (
        <section className="space-y-4">
          <p className="text-[10px] font-black uppercase tracking-widest text-white/30">
            Hosts · {hosts.length}
            {!searching ? " (latest 200)" : ""} · {period}
          </p>
          <HostCards hosts={hosts} period={period} />
        </section>
      )}
    </div>
  );
}
