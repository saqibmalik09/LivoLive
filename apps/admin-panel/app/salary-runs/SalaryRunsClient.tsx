"use client";
import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { Loader2, Play, Eye, Wallet } from "lucide-react";
import { useRouter } from "next/navigation";
import {
  previewSalaryPeriod,
  calculateSalaryPeriod,
  executeSalaryPayout,
  executeBdSalaryPayout,
  executeAgencySalaryPayout,
  fetchPeriodSalaryOverview,
} from "./actions";
import { PeriodSalaryOverviewPanel } from "@/components/PeriodSalaryOverview";
import type { PeriodSalaryOverview } from "@/lib/salary-hub/types";
import { formatUsd, periodToBdMonth } from "@/lib/salary-hub/constants";
export function SalaryRunsClient({
  periods,
  payouts,
  initialOverview,
}: {
  periods: any[];
  payouts: any[];
  initialOverview: PeriodSalaryOverview | null;
}) {
  const router = useRouter();
  const [selected, setSelected] = useState(periods[0]?.period_id || "");
  const [loading, setLoading] = useState<string | null>(null);
  const [preview, setPreview] = useState<any>(null);
  const [overview, setOverview] = useState<PeriodSalaryOverview | null>(initialOverview);
  const [overviewLoading, setOverviewLoading] = useState(false);
  const skipInitialFetch = useRef(
    Boolean(initialOverview && initialOverview.periodId === periods[0]?.period_id),
  );
  useEffect(() => {
    if (!selected) return;
    if (skipInitialFetch.current && selected === initialOverview?.periodId) {
      skipInitialFetch.current = false;
      return;
    }
    skipInitialFetch.current = false;
    let cancelled = false;
    setOverviewLoading(true);
    fetchPeriodSalaryOverview(selected).then((res) => {
      if (cancelled) return;
      if (res.success) setOverview(res.data);
      else setOverview(null);
      setOverviewLoading(false);
    });
    return () => {
      cancelled = true;
    };
  }, [selected, initialOverview]);
  const periodPayouts = payouts.filter((p) => p.period_id === selected);
  async function refreshOverview(periodId: string) {
    const res = await fetchPeriodSalaryOverview(periodId);
    if (res.success) setOverview(res.data);
  }
  async function handlePreview() {
    if (!selected) return;
    setLoading("preview");
    const res = await previewSalaryPeriod(selected);
    if (res.success) setPreview(res.data);
    else alert(res.error);
    setLoading(null);
  }
  async function handleCalculate() {
    if (!selected || !confirm(`Calculate salary for ${selected}?`)) return;
    setLoading("calc");
    const res = await calculateSalaryPeriod(selected);
    if (res.success) {
      await refreshOverview(selected);
      router.refresh();
      alert(`Calculated. Qualified hosts: ${res.data?.qualified_hosts ?? 0}`);
    } else alert(res.error);
    setLoading(null);
  }
  async function handlePay() {
    if (!selected || !confirm(`Pay all pending HOST diamond rows for ${selected}?`)) return;
    setLoading("pay");
    const res = await executeSalaryPayout(selected);
    if (res.success) {
      await refreshOverview(selected);
      router.refresh();
      alert(`Paid ${res.data?.rows_paid ?? 0} rows, ${res.data?.total_diamonds ?? 0} diamonds`);
    } else alert(res.error);
    setLoading(null);
  }
  async function handlePayBd() {
    if (!selected) return;
    const ym = periodToBdMonth(selected);
    const unpaidEst =
      overview && overview.bdMonth === ym
        ? Math.max(0, (overview.bd.estimatedUsd || 0) - (overview.bd.paidUsd || 0))
        : null;
    const msg =
      unpaidEst != null
        ? `Pay BD period USD for ${ym}?\n\nEst unpaid ~ ${formatUsd(unpaidEst)}\nDollars go to each BD user's cash wallet.`
        : `Pay BD period USD for ${ym}?\n\nDollars go to each BD user's cash wallet.`;
    if (!confirm(msg)) return;
    setLoading("payBd");
    const res = await executeBdSalaryPayout(selected);
    if (res.success) {
      await refreshOverview(selected);
      router.refresh();
      const d = (res.data ?? {}) as Record<string, unknown>;
      alert(`BD payout ${res.bdMonth}: ${Number(d.bds_paid ?? 0)} BD(s) credited to cash wallet`);
    } else alert(res.error);
    setLoading(null);
  }
  async function handlePayAgency() {
    if (!selected) return;
    const unpaidEst = overview
      ? Math.max(0, (overview.agencies.estimatedUsd || 0) - (overview.agencies.paidUsd || 0))
      : null;
    const msg =
      unpaidEst != null
        ? `Pay Agency period USD for ${selected}?\n\nEst unpaid ~ ${formatUsd(unpaidEst)}\nDollars go to each agency owner's cash wallet.`
        : `Pay Agency period USD for ${selected}?\n\nDollars go to each agency owner's cash wallet.`;
    if (!confirm(msg)) return;
    setLoading("payAgency");
    const res = await executeAgencySalaryPayout(selected);
    if (res.success) {
      await refreshOverview(selected);
      router.refresh();
      const d = (res.data ?? {}) as Record<string, unknown>;
      alert(
        `Agency payout ${res.periodId}: ${Number(d.agencies_paid ?? 0)} agency owner(s) credited to cash wallet`,
      );
    } else alert(res.error);
    setLoading(null);
  }
  return (
    <div className="space-y-8">
      <div className="flex flex-wrap gap-4 items-end">
        <div>
          <label className="text-[10px] font-black uppercase tracking-widest text-white/30 block mb-2">
            Period
          </label>
          <select
            value={selected}
            onChange={(e) => {
              setSelected(e.target.value);
              setPreview(null);
            }}
            className="bg-white/5 border border-white/10 rounded-xl px-4 py-3 font-bold"
          >
            {periods.map((p) => (
              <option key={p.period_id} value={p.period_id} className="bg-black">
                {p.period_id} ({p.status}) — {p.start_date} to {p.end_date}
              </option>
            ))}
          </select>
        </div>
        <button
          onClick={handlePreview}
          disabled={!!loading}
          className="px-5 py-3 bg-white/10 rounded-xl flex items-center gap-2 text-sm font-bold"
        >
          {loading === "preview" ? (
            <Loader2 className="animate-spin" size={16} />
          ) : (
            <Eye size={16} />
          )}
          Preview
        </button>
        <button
          onClick={handleCalculate}
          disabled={!!loading}
          className="px-5 py-3 bg-purple-500 text-black rounded-xl flex items-center gap-2 text-sm font-black"
        >
          {loading === "calc" ? <Loader2 className="animate-spin" size={16} /> : <Play size={16} />}
          Calculate
        </button>
        <button
          onClick={handlePay}
          disabled={!!loading}
          className="px-5 py-3 bg-emerald-500 text-black rounded-xl flex items-center gap-2 text-sm font-black"
        >
          {loading === "pay" ? (
            <Loader2 className="animate-spin" size={16} />
          ) : (
            <Wallet size={16} />
          )}
          Pay Host (diamonds)
        </button>
        <button
          onClick={handlePayAgency}
          disabled={!!loading || !selected}
          className="px-5 py-3 bg-pink-500 text-black rounded-xl flex items-center gap-2 text-sm font-black"
          title={selected ? `Pays agency owners for ${selected} → cash wallet` : undefined}
        >
          {loading === "payAgency" ? (
            <Loader2 className="animate-spin" size={16} />
          ) : (
            <Wallet size={16} />
          )}
          Pay Agency (USD)
        </button>
        <button
          onClick={handlePayBd}
          disabled={!!loading || !selected}
          className="px-5 py-3 bg-sky-500 text-black rounded-xl flex items-center gap-2 text-sm font-black"
          title={selected ? `Pays BD period ${periodToBdMonth(selected)} → cash wallet` : undefined}
        >
          {loading === "payBd" ? (
            <Loader2 className="animate-spin" size={16} />
          ) : (
            <Wallet size={16} />
          )}
          Pay BD (USD)
        </button>
        <Link
          href={`/salary-hub?period=${selected}`}
          className="px-5 py-3 bg-white/5 border border-white/10 rounded-xl text-sm font-bold text-white/70 hover:text-white"
        >
          Open Salary Hub
        </Link>
      </div>

      {overviewLoading && !overview ? (
        <div className="glass-card p-8 flex items-center gap-3 text-white/40">
          <Loader2 className="animate-spin" size={18} />
          Loading period totals…
        </div>
      ) : overview ? (
        <div className={overviewLoading ? "opacity-60 transition-opacity" : ""}>
          <PeriodSalaryOverviewPanel overview={overview} hubLinks />
        </div>
      ) : null}

      {preview && (
        <div className="glass-card p-8 grid grid-cols-2 md:grid-cols-4 gap-6">
          <div>
            <p className="text-[10px] text-white/30 uppercase font-black">Qualified Hosts</p>
            <p className="text-3xl font-black">{preview.qualified_hosts}</p>
          </div>
          <div>
            <p className="text-[10px] text-white/30 uppercase font-black">Host Diamonds</p>
            <p className="text-3xl font-black text-emerald-400">
              {preview.total_host_diamonds?.toLocaleString()}
            </p>
          </div>
          <div>
            <p className="text-[10px] text-white/30 uppercase font-black">Chain Diamonds</p>
            <p className="text-3xl font-black text-amber-400">
              {preview.total_chain_diamonds?.toLocaleString()}
            </p>
          </div>
          <div>
            <p className="text-[10px] text-white/30 uppercase font-black">Grand Total</p>
            <p className="text-3xl font-black">{preview.grand_total?.toLocaleString()}</p>
          </div>
        </div>
      )}

      <div className="glass-card p-8">
        <h3 className="text-lg font-black mb-2">Host payout rows — {selected}</h3>
        <p className="text-xs text-white/35 mb-6">
          <strong className="text-white/60">Pay Host</strong> = diamonds (same as before).{" "}
          <strong className="text-white/60">Pay Agency (USD)</strong> = owner cash wallet for this
          A/B period. <strong className="text-white/60">Pay BD (USD)</strong> = monthly BD cash
          (period → month, e.g. 2026-07-A → 2026-07).
        </p>
        {periodPayouts.length === 0 ? (
          <p className="text-white/40">No payout rows yet. Run Calculate first.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-[10px] uppercase text-white/30">
                  <th className="pb-4">Role</th>
                  <th className="pb-4">User</th>
                  <th className="pb-4">Amount</th>
                  <th className="pb-4">Status</th>
                </tr>
              </thead>
              <tbody>
                {periodPayouts.map((row) => (
                  <tr key={row.id} className="border-t border-white/5">
                    <td className="py-3 font-bold">{row.beneficiary_role}</td>
                    <td className="py-3">
                      {row.users?.username ?? row.beneficiary_user_id?.slice(0, 8)}
                    </td>
                    <td className="py-3 font-black text-emerald-400">
                      {row.total_amount?.toLocaleString()}
                    </td>
                    <td className="py-3">{row.status}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
