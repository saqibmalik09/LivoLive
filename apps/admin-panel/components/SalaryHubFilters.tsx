"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Search, X } from "lucide-react";
import { useEffect, useState, useTransition } from "react";
import {
  SALARY_HUB_PERIOD_COOKIE,
  SALARY_HUB_ROLES,
  buildPeriodId,
  listSelectablePeriods,
  monthPeriodIds,
  parsePeriodId,
  periodDaysLabel,
  periodLabel,
  type PeriodPart,
  type SalaryHubRole,
} from "@/lib/salary-hub/constants";
function setPeriodCookie(period: string) {
  const maxAge = 60 * 60 * 24 * 180;
  document.cookie = `${SALARY_HUB_PERIOD_COOKIE}=${encodeURIComponent(period)}; path=/; max-age=${maxAge}; SameSite=Lax`;
}
export function SalaryHubFilters({
  role,
  period,
  q = "",
  monthlyMode = false,
}: {
  role: SalaryHubRole;
  period: string;
  q?: string;
  periods?: string[];
  monthlyMode?: boolean;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [searchDraft, setSearchDraft] = useState(q);
  useEffect(() => {
    setPeriodCookie(period);
  }, [period]);
  useEffect(() => {
    setSearchDraft(q);
  }, [q]);
  const parsed = parsePeriodId(period) || {
    year: new Date().getFullYear(),
    month: new Date().getMonth() + 1,
    half: "A" as PeriodPart,
  };
  const cycleIds = monthPeriodIds(parsed.year, parsed.month);
  const isWeekly = cycleIds.some((id) => /-W[1-4]$/.test(id));
  const monthOptions = (() => {
    const seen = new Set<string>();
    const opts: {
      value: string;
      label: string;
    }[] = [];
    for (const id of listSelectablePeriods(18)) {
      const p = parsePeriodId(id);
      if (!p) continue;
      const key = `${p.year}-${String(p.month).padStart(2, "0")}`;
      if (seen.has(key)) continue;
      seen.add(key);
      const label = new Date(p.year, p.month - 1, 1).toLocaleString("en", {
        month: "long",
        year: "numeric",
      });
      opts.push({ value: key, label });
    }
    return opts;
  })();
  function go(nextRole: SalaryHubRole, nextPeriod: string, nextQ = searchDraft) {
    setPeriodCookie(nextPeriod);
    const params = new URLSearchParams();
    params.set("role", nextRole);
    params.set("period", nextPeriod);
    const trimmed = nextQ.trim();
    if (trimmed) params.set("q", trimmed);
    startTransition(() => {
      router.push(`/salary-hub?${params.toString()}`);
    });
  }
  function onMonthChange(ym: string) {
    const [y, m] = ym.split("-").map(Number);
    const same = buildPeriodId(y, m, parsed.half);
    const ids = monthPeriodIds(y, m);
    go(role, ids.includes(same) ? same : ids[0]);
  }
  function onHalfChange(periodId: string) {
    go(role, periodId);
  }
  function submitSearch(e?: React.FormEvent) {
    e?.preventDefault();
    go(role, period, searchDraft);
  }
  function clearSearch() {
    setSearchDraft("");
    go(role, period, "");
  }
  return (
    <div className="space-y-4">
      <form
        onSubmit={submitSearch}
        className="glass-card p-4 flex flex-col sm:flex-row gap-3 border-emerald-500/15"
      >
        <div className="relative flex-1">
          <Search size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-white/35" />
          <input
            value={searchDraft}
            onChange={(e) => setSearchDraft(e.target.value)}
            placeholder="Search agency, host, BD, username, short ID, code…"
            className="w-full bg-black/40 border border-white/15 rounded-xl pl-11 pr-10 py-3 text-sm font-medium text-white outline-none focus:border-emerald-400/50 placeholder:text-white/30"
            disabled={pending}
          />
          {searchDraft ? (
            <button
              type="button"
              onClick={clearSearch}
              className="absolute right-3 top-1/2 -translate-y-1/2 p-1 rounded-lg text-white/40 hover:text-white"
              aria-label="Clear search"
            >
              <X size={14} />
            </button>
          ) : null}
        </div>
        <button
          type="submit"
          disabled={pending}
          className="px-5 py-3 rounded-xl bg-emerald-500/20 border border-emerald-400/40 text-emerald-200 text-[10px] font-black uppercase tracking-widest hover:bg-emerald-500/30 disabled:opacity-60"
        >
          {pending ? "Searching…" : "Search"}
        </button>
      </form>

      <div className="flex flex-wrap gap-2">
        {SALARY_HUB_ROLES.map((r) => {
          const active = r.id === role && !q.trim();
          return (
            <button
              key={r.id}
              type="button"
              onClick={() => go(r.id, period, "")}
              className={`px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest border transition-all ${
                active
                  ? "bg-emerald-500/20 border-emerald-400/40 text-emerald-300"
                  : "bg-white/5 border-white/10 text-white/50 hover:text-white hover:border-white/20"
              }`}
            >
              {r.label}
            </button>
          );
        })}
      </div>

      <div className="glass-card p-5 flex flex-col sm:flex-row sm:items-end gap-4 flex-wrap border-emerald-500/20">
        <div className="space-y-2 min-w-[200px]">
          <label className="text-[10px] font-black uppercase tracking-widest text-white/40 block">
            Month
          </label>
          <select
            value={`${parsed.year}-${String(parsed.month).padStart(2, "0")}`}
            onChange={(e) => onMonthChange(e.target.value)}
            className="w-full bg-black/40 border border-white/15 rounded-xl px-4 py-2.5 text-sm font-bold text-white outline-none focus:border-emerald-400/50"
          >
            {monthOptions.map((o) => (
              <option key={o.value} value={o.value} className="bg-zinc-900">
                {o.label}
              </option>
            ))}
          </select>
        </div>

        {monthlyMode ? (
          <div className="space-y-2">
            <span className="text-[10px] font-black uppercase tracking-widest text-white/40 block">
              Cycle
            </span>
            <div className="min-w-[160px] px-4 py-2.5 rounded-xl text-sm font-black border bg-emerald-500/25 border-emerald-400/50 text-emerald-200 text-center">
              MONTHLY
              <span className="block text-[9px] font-bold uppercase tracking-widest opacity-70 mt-0.5">
                Full month (1–end)
              </span>
            </div>
          </div>
        ) : (
          <div className="space-y-2">
            <span className="text-[10px] font-black uppercase tracking-widest text-white/40 block">
              {isWeekly ? "Week (7-day)" : "Half (15-day)"}
            </span>
            <div className="flex gap-2 flex-wrap">
              {cycleIds.map((id) => {
                const half = parsePeriodId(id)!.half;
                const active = parsed.half === half;
                return (
                  <button
                    key={id}
                    type="button"
                    onClick={() => onHalfChange(id)}
                    className={`min-w-[88px] px-4 py-2.5 rounded-xl text-sm font-black border transition-all ${
                      active
                        ? "bg-emerald-500/25 border-emerald-400/50 text-emerald-200"
                        : "bg-white/5 border-white/10 text-white/45 hover:text-white"
                    }`}
                  >
                    {half}
                    <span className="block text-[9px] font-bold uppercase tracking-widest opacity-70 mt-0.5">
                      {periodDaysLabel(id)}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        <div className="sm:ml-auto flex flex-col items-start sm:items-end gap-1">
          <p className="text-[10px] font-black uppercase tracking-widest text-emerald-400/70">
            Active period
          </p>
          {(() => {
            const shown = monthlyMode
              ? `${parsed.year}-${String(parsed.month).padStart(2, "0")}-M`
              : period;
            return (
              <>
                <p className="text-sm font-black text-white">{periodLabel(shown)}</p>
                <p className="text-[10px] text-white/30 font-mono">{shown}</p>
              </>
            );
          })()}
        </div>

        <Link
          href="/salary-runs"
          className="text-[10px] font-black uppercase tracking-widest text-emerald-400/70 hover:text-emerald-300 sm:self-center"
        >
          Salary Runs →
        </Link>
      </div>
    </div>
  );
}
