import Link from "next/link";
import { ArrowLeft, ShieldAlert, ClipboardCheck } from "lucide-react";
import {
  getAgencyPeriodAudit,
  getBdMonthAudit,
  getHostPeriodAudit,
  getLeadershipMonthAudit,
  type AgencyPeriodAuditRow,
  type BdMonthAuditRow,
  type HostPeriodAuditRow,
  type LeadershipMonthAuditRow,
} from "@/lib/salary-hub/audit";
import { getHubPeriod } from "@/lib/salary-hub/period";
import {
  formatUsd,
  periodLabel,
  periodToBdMonth,
  periodToCalendarMonth,
} from "@/lib/salary-hub/constants";
import { AmountValue } from "@/components/AmountValue";
import { SalaryEntityPayButton } from "@/components/SalaryEntityPayButton";
import { SalaryAuditPeriodPicker } from "./SalaryAuditPeriodPicker";
export const dynamic = "force-dynamic";
export const revalidate = 0;
function formatDiamonds(n: number): string {
  if (!Number.isFinite(n) || n === 0) return "0";
  if (Math.abs(n) >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (Math.abs(n) >= 1000) return `${(n / 1000).toFixed(1)}K`;
  return String(Math.round(n));
}
export default async function SalaryAuditPage({
  searchParams,
}: {
  searchParams: Promise<{
    period?: string;
  }>;
}) {
  const sp = await searchParams;
  const period = await getHubPeriod(sp.period);
  const bdMonth = periodToBdMonth(period);
  const calendarMonth = periodToCalendarMonth(period);
  let hostRows: HostPeriodAuditRow[] = [];
  let agencyRows: AgencyPeriodAuditRow[] = [];
  let bdRows: BdMonthAuditRow[] = [];
  let leadershipRows: LeadershipMonthAuditRow[] = [];
  let hostError: string | null = null;
  let agencyError: string | null = null;
  let bdError: string | null = null;
  let leadershipError: string | null = null;
  const [hostRes, agencyRes, bdRes, leadershipRes] = await Promise.allSettled([
    getHostPeriodAudit(period),
    getAgencyPeriodAudit(period),
    getBdMonthAudit(bdMonth),
    getLeadershipMonthAudit(calendarMonth),
  ]);
  if (hostRes.status === "fulfilled") hostRows = hostRes.value;
  else hostError = hostRes.reason?.message || "Jobs audit failed";
  if (agencyRes.status === "fulfilled") agencyRows = agencyRes.value;
  else agencyError = agencyRes.reason?.message || "Agency audit failed";
  if (bdRes.status === "fulfilled") bdRows = bdRes.value;
  else bdError = bdRes.reason?.message || "BD audit failed";
  if (leadershipRes.status === "fulfilled") leadershipRows = leadershipRes.value;
  else leadershipError = leadershipRes.reason?.message || "Super/County audit failed";
  const superRows = leadershipRows.filter((r) => r.normalized_role === "super_bd");
  const countyRows = leadershipRows.filter((r) => r.normalized_role === "county_admin");
  const hostUnpaid = hostRows.filter((r) => r.flag_unpaid_with_due).length;
  const hostBlocked = hostRows.filter((r) => r.flag_blocked_by_attendance).length;
  const hostSelf = hostRows.filter((r) => r.flag_mostly_self_gift).length;
  const hostEstTotal = hostRows.reduce((s, r) => s + r.est_usd, 0);
  const hostPaidDiamonds = hostRows.reduce(
    (s, r) => s + (r.payout_status === "paid" ? r.payout_diamonds : 0),
    0,
  );
  const agencyDouble = agencyRows.filter((r) => r.flag_double_pay).length;
  const agencyOver = agencyRows.filter((r) => r.flag_over_withdraw).length;
  const agencySelf = agencyRows.filter((r) => r.flag_mostly_self_gift).length;
  const bdUnpaid = bdRows.filter((r) => r.flag_unpaid_with_due).length;
  const bdOver = bdRows.filter((r) => r.flag_over_withdraw).length;
  const bdNoAtt = bdRows.filter((r) => r.flag_no_attendance && r.payable_usd > 0).length;
  const bdDueTotal = bdRows.reduce((s, r) => s + r.payable_usd, 0);
  const bdPaidTotal = bdRows.reduce(
    (s, r) => s + (r.settlement_status === "paid" ? r.settlement_total_usd : 0),
    0,
  );
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
        <span className="text-[10px] font-black uppercase tracking-[0.4em] text-amber-500 mb-1 block">
          Track · Reconcile
        </span>
        <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
          <ClipboardCheck size={44} className="text-amber-400" />
          Salary Audit
        </h1>
        <p className="text-white/50 mt-2 font-medium max-w-2xl">
          Period select → Jobs + Agency + BD + Super Admin + County Admin: estimates, commission,
          tree size, cash / diamond flags.
        </p>
      </header>

      <div className="flex flex-wrap gap-4 items-end">
        <SalaryAuditPeriodPicker period={period} />
        <Link
          href={`/salary-hub?period=${period}`}
          className="px-5 py-3 bg-white/5 border border-white/10 rounded-xl text-sm font-bold text-white/70 hover:text-white"
        >
          Salary Hub
        </Link>
        <Link
          href="/withdrawals"
          className="px-5 py-3 bg-white/5 border border-white/10 rounded-xl text-sm font-bold text-white/70 hover:text-white"
        >
          Withdrawals
        </Link>
      </div>

      <section className="space-y-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-sky-400/80">
              Jobs · Host
            </p>
            <h2 className="text-2xl font-black">{periodLabel(period)}</h2>
            <p className="text-xs text-white/40 mt-1">
              Host tier salary pays diamonds (not cash). BLOCKED = diamonds enough but days/hrs
              short.
            </p>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            <Stat label="Hosts" value={String(hostRows.length)} />
            <Stat label="Payable est" value={formatUsd(hostEstTotal)} />
            <Stat label="Paid diamonds" value={formatDiamonds(hostPaidDiamonds)} />
            <Stat
              label="Flags"
              value={String(hostUnpaid + hostBlocked + hostSelf)}
              tone={hostUnpaid ? "bad" : hostBlocked || hostSelf ? "warn" : "ok"}
            />
          </div>
        </div>

        {hostError && (
          <div className="glass-card p-4 border-red-500/30 text-red-300 text-sm">
            <ShieldAlert className="inline mr-2" size={16} />
            {hostError}
          </div>
        )}

        <div className="glass-card p-6 overflow-x-auto">
          <p className="text-xs text-white/35 mb-4">
            Est $ = full tier (diamonds + ≥hrs + ≥days). Diamond tier = if only diamonds counted.
            UNPAID = tier due but payout not paid.
          </p>
          {hostRows.length === 0 && !hostError ? (
            <p className="text-white/40 text-sm">Is period ki koi host activity nahi.</p>
          ) : (
            <table className="w-full text-sm min-w-[1100px]">
              <thead>
                <tr className="text-left text-[10px] uppercase tracking-widest text-white/30">
                  <th className="pb-3 pr-3">Flag</th>
                  <th className="pb-3 pr-3">UID</th>
                  <th className="pb-3 pr-3">Host / Agency</th>
                  <th className="pb-3 pr-3 text-right">Diamonds</th>
                  <th className="pb-3 pr-3 text-right">Days / Hrs</th>
                  <th className="pb-3 pr-3 text-right">Est $</th>
                  <th className="pb-3 pr-3 text-right">Dia tier $</th>
                  <th className="pb-3 pr-3 text-right">Paid ◆</th>
                  <th className="pb-3 pr-3 text-right">Self-gift %</th>
                  <th className="pb-3 pr-3 text-right">Pend WD</th>
                  <th className="pb-3">Links</th>
                </tr>
              </thead>
              <tbody>
                {hostRows.map((r) => (
                  <tr key={r.user_id} className="border-t border-white/5 align-top">
                    <td className="py-3 pr-3">
                      <HostFlags row={r} />
                    </td>
                    <td className="py-3 pr-3 font-black">{r.short_id ?? "—"}</td>
                    <td className="py-3 pr-3">
                      <p className="font-bold">{r.username}</p>
                      <p className="text-xs text-white/40">
                        {r.agency_name || "No agency"}
                        {r.agency_code ? ` · ${r.agency_code}` : ""}
                        {r.tier_name ? ` · ${r.tier_name}` : ""}
                      </p>
                    </td>
                    <td className="py-3 pr-3 text-right text-white/80">
                      {formatDiamonds(r.total_diamonds)}
                    </td>
                    <td
                      className={`py-3 pr-3 text-right ${
                        r.flag_blocked_by_attendance ? "text-amber-300/80" : "text-white/70"
                      }`}
                    >
                      {r.valid_days}d / {r.work_hours}h
                    </td>
                    <td className="py-3 pr-3 text-right">
                      <AmountValue
                        value={formatUsd(r.est_usd)}
                        size="sm"
                        className="text-emerald-400"
                      />
                    </td>
                    <td className="py-3 pr-3 text-right text-white/50">
                      {formatUsd(r.diamond_only_usd)}
                    </td>
                    <td className="py-3 pr-3 text-right">
                      {r.payout_status === "paid" ? (
                        <>
                          <span className="text-emerald-300 font-bold">
                            {formatDiamonds(r.payout_diamonds)}
                          </span>
                          <span className="block text-[9px] text-white/30">paid</span>
                        </>
                      ) : r.payout_status ? (
                        <span className="text-amber-300/80 text-xs font-bold uppercase">
                          {r.payout_status}
                        </span>
                      ) : (
                        <span className="text-white/35">—</span>
                      )}
                    </td>
                    <td
                      className={`py-3 pr-3 text-right font-bold ${
                        r.self_gift_pct >= 50 ? "text-amber-300" : "text-white/50"
                      }`}
                    >
                      {r.self_gift_pct.toFixed(0)}%
                    </td>
                    <td className="py-3 pr-3 text-right text-amber-300/90">
                      {formatUsd(r.pending_withdraw_usd)}
                    </td>
                    <td className="py-3 whitespace-nowrap">
                      <Link
                        href={`/users/${r.user_id}`}
                        className="text-[11px] font-bold text-white/50 hover:text-white mr-3"
                      >
                        User
                      </Link>
                      {r.agency_id && (
                        <Link
                          href={`/agencies/${r.agency_id}`}
                          className="text-[11px] font-bold text-white/50 hover:text-white mr-3"
                        >
                          Agency
                        </Link>
                      )}
                      {r.pending_withdraw_usd > 0 && (
                        <Link
                          href={`/withdrawals?q=${r.short_id ?? ""}`}
                          className="text-[11px] font-bold text-violet-300 hover:text-violet-200"
                        >
                          WD
                        </Link>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </section>

      <section className="space-y-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-pink-400/80">
              Agency · A/B
            </p>
            <h2 className="text-2xl font-black">{periodLabel(period)}</h2>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            <Stat label="Agencies" value={String(agencyRows.length)} />
            <Stat
              label="Double / over WD"
              value={String(agencyDouble + agencyOver)}
              tone={agencyDouble + agencyOver ? "bad" : "ok"}
            />
            <Stat
              label="Self-gift ≥50%"
              value={String(agencySelf)}
              tone={agencySelf ? "warn" : "ok"}
            />
          </div>
        </div>

        {agencyError && (
          <div className="glass-card p-4 border-red-500/30 text-red-300 text-sm">
            <ShieldAlert className="inline mr-2" size={16} />
            {agencyError}
          </div>
        )}

        <div className="glass-card p-6 overflow-x-auto">
          <p className="text-xs text-white/35 mb-4">
            Implied = cash + pending WD. Ratio &gt; 1.01 → double-pay suspect.
          </p>
          {agencyRows.length === 0 && !agencyError ? (
            <p className="text-white/40 text-sm">Is period ki koi paid agency settlement nahi.</p>
          ) : (
            <table className="w-full text-sm min-w-[980px]">
              <thead>
                <tr className="text-left text-[10px] uppercase tracking-widest text-white/30">
                  <th className="pb-3 pr-3">Flag</th>
                  <th className="pb-3 pr-3">UID</th>
                  <th className="pb-3 pr-3">Owner / Agency</th>
                  <th className="pb-3 pr-3 text-right">Salary</th>
                  <th className="pb-3 pr-3 text-right">Cash</th>
                  <th className="pb-3 pr-3 text-right">Pending WD</th>
                  <th className="pb-3 pr-3 text-right">Implied</th>
                  <th className="pb-3 pr-3 text-right">Ratio</th>
                  <th className="pb-3 pr-3 text-right">Members</th>
                  <th className="pb-3 pr-3 text-right">Self-gift %</th>
                  <th className="pb-3 pr-3">Pay</th>
                  <th className="pb-3">Links</th>
                </tr>
              </thead>
              <tbody>
                {agencyRows.map((r) => (
                  <tr key={r.agency_id} className="border-t border-white/5 align-top">
                    <td className="py-3 pr-3">
                      <AgencyFlags row={r} />
                    </td>
                    <td className="py-3 pr-3 font-black">{r.owner_short_id ?? "—"}</td>
                    <td className="py-3 pr-3">
                      <p className="font-bold">{r.owner_username}</p>
                      <p className="text-xs text-white/40">
                        {r.agency_name}
                        {r.agency_code ? ` · ${r.agency_code}` : ""}
                        {r.achieved_level ? ` · LV ${r.achieved_level}` : ""}
                      </p>
                    </td>
                    <td className="py-3 pr-3 text-right">
                      <AmountValue
                        value={formatUsd(r.salary_usd)}
                        size="sm"
                        className="text-emerald-400"
                      />
                    </td>
                    <td className="py-3 pr-3 text-right text-white/80">
                      {formatUsd(r.cash_balance)}
                    </td>
                    <td className="py-3 pr-3 text-right text-amber-300/90">
                      {formatUsd(r.pending_withdraw_usd)}
                    </td>
                    <td className="py-3 pr-3 text-right font-bold">
                      {formatUsd(r.implied_cash_usd)}
                    </td>
                    <td
                      className={`py-3 pr-3 text-right font-black ${
                        (r.salary_ratio || 0) > 1.01 ? "text-red-400" : "text-white/50"
                      }`}
                    >
                      {r.salary_ratio == null ? "—" : r.salary_ratio.toFixed(2)}
                    </td>
                    <td className="py-3 pr-3 text-right">{r.member_count}</td>
                    <td
                      className={`py-3 pr-3 text-right font-bold ${
                        r.self_gift_pct >= 50 ? "text-amber-300" : "text-white/50"
                      }`}
                    >
                      {r.self_gift_pct.toFixed(0)}%
                    </td>
                    <td className="py-3 pr-3">
                      <SalaryEntityPayButton
                        kind="agency"
                        periodId={r.period_id}
                        entityId={r.agency_id}
                        label={r.agency_name}
                        amountUsd={r.salary_usd}
                        alreadyPaid={r.settlement_status === "paid"}
                        disabled={!(r.salary_usd > 0)}
                      />
                    </td>
                    <td className="py-3 whitespace-nowrap">
                      <Link
                        href={`/users/${r.owner_user_id}`}
                        className="text-[11px] font-bold text-white/50 hover:text-white mr-3"
                      >
                        User
                      </Link>
                      <Link
                        href={`/agencies/${r.agency_id}`}
                        className="text-[11px] font-bold text-white/50 hover:text-white mr-3"
                      >
                        Agency
                      </Link>
                      {r.pending_withdraw_usd > 0 && (
                        <Link
                          href={`/withdrawals?q=${r.owner_short_id ?? ""}`}
                          className="text-[11px] font-bold text-violet-300 hover:text-violet-200"
                        >
                          WD
                        </Link>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </section>

      <LeadershipSection
        title="Super Admin · Monthly"
        accent="text-violet-400/80"
        month={calendarMonth}
        hubPeriod={period}
        rows={superRows}
        error={leadershipError}
        emptyLabel="No Super Admin staff."
        note="Gift-chain commission (diamonds) for the calendar month. No BD basic salary settlement."
      />

      <LeadershipSection
        title="County Admin · Monthly"
        accent="text-fuchsia-400/80"
        month={calendarMonth}
        hubPeriod={period}
        rows={countyRows}
        error={leadershipError}
        emptyLabel="No County Admin staff."
        note="Gift-chain commission (diamonds) + downline agencies/hosts under this County."
      />

      <section className="space-y-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-amber-400/80">
              BD · Period A/B
            </p>
            <h2 className="text-2xl font-black">{bdMonth}</h2>
            <p className="text-xs text-white/40 mt-1">
              Same half as hub ({periodLabel(period)}) · pay day 16 (A) / 1 (B)
            </p>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            <Stat label="BD staff" value={String(bdRows.length)} />
            <Stat label="Payable est" value={formatUsd(bdDueTotal)} />
            <Stat label="Already paid" value={formatUsd(bdPaidTotal)} />
            <Stat
              label="Flags"
              value={String(bdUnpaid + bdOver + bdNoAtt)}
              tone={bdUnpaid + bdOver ? "bad" : bdNoAtt ? "warn" : "ok"}
            />
          </div>
        </div>

        {bdError && (
          <div className="glass-card p-4 border-red-500/30 text-red-300 text-sm">
            <ShieldAlert className="inline mr-2" size={16} />
            {bdError}
          </div>
        )}

        <div className="glass-card p-6 overflow-x-auto">
          <p className="text-xs text-white/35 mb-4">
            Payable = basic (only if ≥10 days & ≥30 hrs) + commission + new BD. UNPAID = due &gt; 0
            but settlement not paid. NO ATT = attendance short.
          </p>
          {bdRows.length === 0 && !bdError ? (
            <p className="text-white/40 text-sm">No BD staff rows.</p>
          ) : (
            <table className="w-full text-sm min-w-[1100px]">
              <thead>
                <tr className="text-left text-[10px] uppercase tracking-widest text-white/30">
                  <th className="pb-3 pr-3">Flag</th>
                  <th className="pb-3 pr-3">UID</th>
                  <th className="pb-3 pr-3">BD</th>
                  <th className="pb-3 pr-3 text-right">LV</th>
                  <th className="pb-3 pr-3 text-right">Target $</th>
                  <th className="pb-3 pr-3 text-right">Days / Hrs</th>
                  <th className="pb-3 pr-3 text-right">Basic</th>
                  <th className="pb-3 pr-3 text-right">Comm</th>
                  <th className="pb-3 pr-3 text-right">New BD</th>
                  <th className="pb-3 pr-3 text-right">Payable</th>
                  <th className="pb-3 pr-3 text-right">Paid</th>
                  <th className="pb-3 pr-3 text-right">Cash</th>
                  <th className="pb-3 pr-3 text-right">Pend WD</th>
                  <th className="pb-3 pr-3">Pay</th>
                  <th className="pb-3">Links</th>
                </tr>
              </thead>
              <tbody>
                {bdRows.map((r) => (
                  <tr key={r.staff_id} className="border-t border-white/5 align-top">
                    <td className="py-3 pr-3">
                      <BdFlags row={r} />
                    </td>
                    <td className="py-3 pr-3 font-black">{r.short_id ?? "—"}</td>
                    <td className="py-3 pr-3">
                      <p className="font-bold">{r.username}</p>
                      <p className="text-xs text-white/40">
                        {r.staff_code || "—"}
                        {r.is_active ? "" : " · OFF"}
                        {r.new_agencies ? ` · +${r.new_agencies} agencies` : ""}
                      </p>
                    </td>
                    <td className="py-3 pr-3 text-right">{r.achieved_level}</td>
                    <td className="py-3 pr-3 text-right text-white/70">
                      {formatUsd(r.agency_target_usd)}
                    </td>
                    <td
                      className={`py-3 pr-3 text-right ${
                        r.basic_qualifies ? "text-emerald-300" : "text-amber-300/80"
                      }`}
                    >
                      {r.work_days}d / {r.work_hours}h
                    </td>
                    <td className="py-3 pr-3 text-right">
                      {formatUsd(r.est_basic_usd)}
                      {!r.basic_qualifies && r.est_basic_usd > 0 ? (
                        <span className="block text-[9px] text-white/30">blocked</span>
                      ) : null}
                    </td>
                    <td className="py-3 pr-3 text-right">{formatUsd(r.est_commission_usd)}</td>
                    <td className="py-3 pr-3 text-right">{formatUsd(r.est_new_bd_usd)}</td>
                    <td className="py-3 pr-3 text-right">
                      <AmountValue
                        value={formatUsd(r.payable_usd)}
                        size="sm"
                        className="text-emerald-400"
                      />
                    </td>
                    <td className="py-3 pr-3 text-right">
                      {r.settlement_status === "paid" ? (
                        <>
                          <span className="text-emerald-300 font-bold">
                            {formatUsd(r.settlement_total_usd)}
                          </span>
                          <span className="block text-[9px] text-white/30">paid</span>
                        </>
                      ) : (
                        <span className="text-white/35">—</span>
                      )}
                    </td>
                    <td className="py-3 pr-3 text-right text-white/80">
                      {formatUsd(r.cash_balance)}
                    </td>
                    <td className="py-3 pr-3 text-right text-amber-300/90">
                      {formatUsd(r.pending_withdraw_usd)}
                    </td>
                    <td className="py-3 pr-3">
                      <SalaryEntityPayButton
                        kind="bd"
                        periodId={r.period_yyyy_mm}
                        entityId={r.staff_id}
                        label={r.username}
                        amountUsd={r.payable_usd}
                        alreadyPaid={r.settlement_status === "paid"}
                        disabled={!r.is_active || !(r.payable_usd > 0)}
                      />
                    </td>
                    <td className="py-3 whitespace-nowrap">
                      <Link
                        href={`/users/${r.user_id}`}
                        className="text-[11px] font-bold text-white/50 hover:text-white mr-3"
                      >
                        User
                      </Link>
                      <Link
                        href={`/salary-hub/staff/${r.staff_id}?period=${period}`}
                        className="text-[11px] font-bold text-white/50 hover:text-white mr-3"
                      >
                        Hub
                      </Link>
                      {r.pending_withdraw_usd > 0 && (
                        <Link
                          href={`/withdrawals?q=${r.short_id ?? ""}`}
                          className="text-[11px] font-bold text-violet-300 hover:text-violet-200"
                        >
                          WD
                        </Link>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </section>
    </div>
  );
}
function Stat({
  label,
  value,
  tone = "neutral",
}: {
  label: string;
  value: string;
  tone?: "neutral" | "ok" | "warn" | "bad";
}) {
  const color =
    tone === "ok"
      ? "text-emerald-300"
      : tone === "warn"
        ? "text-amber-300"
        : tone === "bad"
          ? "text-red-300"
          : "text-white";
  return (
    <div className="rounded-xl bg-black/35 border border-white/10 px-3 py-2 min-w-[100px]">
      <p className="text-[9px] font-black uppercase tracking-widest text-white/30">{label}</p>
      <p className={`text-lg font-black mt-0.5 ${color}`}>{value}</p>
    </div>
  );
}
function LeadershipSection({
  title,
  accent,
  month,
  hubPeriod,
  rows,
  error,
  emptyLabel,
  note,
}: {
  title: string;
  accent: string;
  month: string;
  hubPeriod: string;
  rows: LeadershipMonthAuditRow[];
  error: string | null;
  emptyLabel: string;
  note: string;
}) {
  const noDown = rows.filter((r) => r.flag_no_downline).length;
  const wdFlag = rows.filter((r) => r.flag_over_withdraw).length;
  const inactiveComm = rows.filter((r) => r.flag_inactive_with_commission).length;
  const commDiamonds = rows.reduce((s, r) => s + r.commission_diamonds, 0);
  const commUsd = rows.reduce((s, r) => s + r.commission_usd, 0);
  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className={`text-[10px] font-black uppercase tracking-widest ${accent}`}>{title}</p>
          <h2 className="text-2xl font-black">{month}</h2>
          <p className="text-xs text-white/40 mt-1">
            From hub period {hubPeriod} · {note}
          </p>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
          <Stat label="Staff" value={String(rows.length)} />
          <Stat label="Commission ◆" value={formatDiamonds(commDiamonds)} />
          <Stat label="Comm ~$" value={formatUsd(commUsd)} />
          <Stat
            label="Flags"
            value={String(noDown + wdFlag + inactiveComm)}
            tone={inactiveComm || wdFlag ? "warn" : noDown ? "warn" : "ok"}
          />
        </div>
      </div>

      {error && (
        <div className="glass-card p-4 border-red-500/30 text-red-300 text-sm">
          <ShieldAlert className="inline mr-2" size={16} />
          {error}
        </div>
      )}

      <div className="glass-card p-6 overflow-x-auto">
        <p className="text-xs text-white/35 mb-4">
          NO DOWN = active but no child staff/agencies. WD? = pending withdraw with zero month
          commission. OFF+COMM = inactive staff still earning gift commission.
        </p>
        {rows.length === 0 && !error ? (
          <p className="text-white/40 text-sm">{emptyLabel}</p>
        ) : (
          <table className="w-full text-sm min-w-[1000px]">
            <thead>
              <tr className="text-left text-[10px] uppercase tracking-widest text-white/30">
                <th className="pb-3 pr-3">Flag</th>
                <th className="pb-3 pr-3">UID</th>
                <th className="pb-3 pr-3">Staff</th>
                <th className="pb-3 pr-3 text-right">Children</th>
                <th className="pb-3 pr-3 text-right">Agencies</th>
                <th className="pb-3 pr-3 text-right">Hosts</th>
                <th className="pb-3 pr-3 text-right">Comm ◆</th>
                <th className="pb-3 pr-3 text-right">Comm $</th>
                <th className="pb-3 pr-3 text-right">Gifts</th>
                <th className="pb-3 pr-3 text-right">Cash</th>
                <th className="pb-3 pr-3 text-right">Pend WD</th>
                <th className="pb-3">Links</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.staff_id} className="border-t border-white/5 align-top">
                  <td className="py-3 pr-3">
                    <LeadershipFlags row={r} />
                  </td>
                  <td className="py-3 pr-3 font-black">{r.short_id ?? "—"}</td>
                  <td className="py-3 pr-3">
                    <p className="font-bold">{r.username}</p>
                    <p className="text-xs text-white/40">
                      {r.staff_code || "—"}
                      {r.is_active ? "" : " · OFF"}
                      {r.parent_username ? ` · under ${r.parent_username}` : ""}
                    </p>
                  </td>
                  <td className="py-3 pr-3 text-right">{r.child_staff_count}</td>
                  <td className="py-3 pr-3 text-right">{r.agency_count}</td>
                  <td className="py-3 pr-3 text-right">{r.host_count}</td>
                  <td className="py-3 pr-3 text-right text-emerald-300 font-bold">
                    {formatDiamonds(r.commission_diamonds)}
                  </td>
                  <td className="py-3 pr-3 text-right text-white/70">
                    {formatUsd(r.commission_usd)}
                  </td>
                  <td className="py-3 pr-3 text-right text-white/50">{r.gift_events}</td>
                  <td className="py-3 pr-3 text-right text-white/80">
                    {formatUsd(r.cash_balance)}
                  </td>
                  <td className="py-3 pr-3 text-right text-amber-300/90">
                    {formatUsd(r.pending_withdraw_usd)}
                  </td>
                  <td className="py-3 whitespace-nowrap">
                    <Link
                      href={`/users/${r.user_id}`}
                      className="text-[11px] font-bold text-white/50 hover:text-white mr-3"
                    >
                      User
                    </Link>
                    <Link
                      href={`/salary-hub/staff/${r.staff_id}?period=${hubPeriod}`}
                      className="text-[11px] font-bold text-white/50 hover:text-white mr-3"
                    >
                      Hub
                    </Link>
                    {r.pending_withdraw_usd > 0 && (
                      <Link
                        href={`/withdrawals?q=${r.short_id ?? ""}`}
                        className="text-[11px] font-bold text-violet-300 hover:text-violet-200"
                      >
                        WD
                      </Link>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
function LeadershipFlags({ row }: { row: LeadershipMonthAuditRow }) {
  const bits: {
    label: string;
    className: string;
  }[] = [];
  if (row.flag_inactive_with_commission)
    bits.push({ label: "OFF+COMM", className: "bg-red-500/20 text-red-300" });
  if (row.flag_over_withdraw)
    bits.push({ label: "WD?", className: "bg-amber-500/15 text-amber-300" });
  if (row.flag_no_downline)
    bits.push({
      label: "NO DOWN",
      className: "bg-amber-500/15 text-amber-300",
    });
  if (bits.length === 0)
    bits.push({ label: "OK", className: "bg-emerald-500/15 text-emerald-300" });
  return (
    <div className="flex flex-col gap-1">
      {bits.map((b) => (
        <span
          key={b.label}
          className={`text-[9px] font-black uppercase tracking-widest px-2 py-1 rounded-md w-fit ${b.className}`}
        >
          {b.label}
        </span>
      ))}
    </div>
  );
}
function HostFlags({ row }: { row: HostPeriodAuditRow }) {
  const bits: {
    label: string;
    className: string;
  }[] = [];
  if (row.flag_unpaid_with_due)
    bits.push({ label: "UNPAID", className: "bg-red-500/20 text-red-300" });
  if (row.flag_withheld) bits.push({ label: "WITHHELD", className: "bg-red-500/20 text-red-300" });
  if (row.flag_paid_mismatch)
    bits.push({ label: "MISMATCH", className: "bg-red-500/20 text-red-300" });
  if (row.flag_blocked_by_attendance)
    bits.push({
      label: "BLOCKED",
      className: "bg-amber-500/15 text-amber-300",
    });
  if (row.flag_mostly_self_gift)
    bits.push({
      label: "SELF GIFT",
      className: "bg-amber-500/15 text-amber-300",
    });
  if (bits.length === 0)
    bits.push({ label: "OK", className: "bg-emerald-500/15 text-emerald-300" });
  return (
    <div className="flex flex-col gap-1">
      {bits.map((b) => (
        <span
          key={b.label}
          className={`text-[9px] font-black uppercase tracking-widest px-2 py-1 rounded-md w-fit ${b.className}`}
        >
          {b.label}
        </span>
      ))}
    </div>
  );
}
function AgencyFlags({ row }: { row: AgencyPeriodAuditRow }) {
  const bits: {
    label: string;
    className: string;
  }[] = [];
  if (row.flag_double_pay) bits.push({ label: "DOUBLE", className: "bg-red-500/20 text-red-300" });
  if (row.flag_over_withdraw)
    bits.push({ label: "OVER WD", className: "bg-red-500/20 text-red-300" });
  if (row.flag_mostly_self_gift)
    bits.push({
      label: "SELF GIFT",
      className: "bg-amber-500/15 text-amber-300",
    });
  if (bits.length === 0)
    bits.push({ label: "OK", className: "bg-emerald-500/15 text-emerald-300" });
  return (
    <div className="flex flex-col gap-1">
      {bits.map((b) => (
        <span
          key={b.label}
          className={`text-[9px] font-black uppercase tracking-widest px-2 py-1 rounded-md w-fit ${b.className}`}
        >
          {b.label}
        </span>
      ))}
    </div>
  );
}
function BdFlags({ row }: { row: BdMonthAuditRow }) {
  const bits: {
    label: string;
    className: string;
  }[] = [];
  if (row.flag_unpaid_with_due)
    bits.push({ label: "UNPAID", className: "bg-red-500/20 text-red-300" });
  if (row.flag_over_withdraw)
    bits.push({ label: "OVER WD", className: "bg-red-500/20 text-red-300" });
  if (row.flag_no_attendance)
    bits.push({
      label: "NO ATT",
      className: "bg-amber-500/15 text-amber-300",
    });
  if (bits.length === 0)
    bits.push({ label: "OK", className: "bg-emerald-500/15 text-emerald-300" });
  return (
    <div className="flex flex-col gap-1">
      {bits.map((b) => (
        <span
          key={b.label}
          className={`text-[9px] font-black uppercase tracking-widest px-2 py-1 rounded-md w-fit ${b.className}`}
        >
          {b.label}
        </span>
      ))}
    </div>
  );
}
