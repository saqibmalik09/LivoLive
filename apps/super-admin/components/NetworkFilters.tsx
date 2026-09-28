'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useTransition } from 'react';
import {
  NETWORK_PERIOD_COOKIE,
  NETWORK_ROLES,
  buildPeriodId,
  listSelectablePeriods,
  parsePeriodId,
  type NetworkRole,
} from '@/lib/period';

function setPeriodCookie(period: string) {
  const maxAge = 60 * 60 * 24 * 180;
  document.cookie = `${NETWORK_PERIOD_COOKIE}=${encodeURIComponent(period)}; path=/; max-age=${maxAge}; SameSite=Lax`;
}

export function NetworkFilters({
  role,
  period,
  search,
  activeOnly,
  basePath = '/network',
}: {
  role: NetworkRole;
  period: string;
  search: string;
  activeOnly: boolean;
  basePath?: string;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  useEffect(() => {
    setPeriodCookie(period);
  }, [period]);

  const parsed = parsePeriodId(period) || {
    year: new Date().getFullYear(),
    month: new Date().getMonth() + 1,
    half: 'A' as const,
  };

  const monthOptions = (() => {
    const seen = new Set<string>();
    const opts: { value: string; label: string }[] = [];
    for (const id of listSelectablePeriods(12)) {
      const p = parsePeriodId(id);
      if (!p) continue;
      const key = `${p.year}-${String(p.month).padStart(2, '0')}`;
      if (seen.has(key)) continue;
      seen.add(key);
      const label = new Date(p.year, p.month - 1, 1).toLocaleString('en', {
        month: 'long',
        year: 'numeric',
      });
      opts.push({ value: key, label });
    }
    return opts;
  })();

  function go(next: {
    role?: NetworkRole;
    period?: string;
    search?: string;
    active?: boolean;
  }) {
    const params = new URLSearchParams();
    params.set('role', next.role ?? role);
    params.set('period', next.period ?? period);
    const q = next.search ?? search;
    if (q.trim()) params.set('q', q.trim());
    if (next.active ?? activeOnly) params.set('active', '1');
    setPeriodCookie(next.period ?? period);
    startTransition(() => {
      router.push(`${basePath}?${params.toString()}`);
    });
  }

  return (
    <div className={`space-y-4 ${pending ? 'opacity-70' : ''}`}>
      <div className="flex flex-wrap gap-2">
        {NETWORK_ROLES.map((r) => {
          const active = r.id === role;
          return (
            <button
              key={r.id}
              type="button"
              onClick={() => go({ role: r.id })}
              className={`px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest border transition-all ${
                active
                  ? 'bg-amber-500/20 border-amber-400/40 text-amber-300'
                  : 'bg-white/5 border-white/10 text-white/50 hover:text-white hover:border-white/20'
              }`}
            >
              {r.label}
            </button>
          );
        })}
      </div>

      <div className="glass-card p-5 flex flex-col lg:flex-row lg:items-end gap-4 flex-wrap border-amber-500/20">
        <div className="space-y-2 min-w-[200px] flex-1">
          <label className="text-[10px] font-black uppercase tracking-widest text-white/40 block">
            Search
          </label>
          <input
            defaultValue={search}
            key={`${role}-${search}`}
            placeholder="Name, ID, code…"
            className="w-full rounded-xl bg-black/40 border border-white/10 px-4 py-2.5 text-sm outline-none focus:border-amber-500/40"
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                go({ search: (e.target as HTMLInputElement).value });
              }
            }}
          />
        </div>

        <div className="space-y-2 min-w-[180px]">
          <label className="text-[10px] font-black uppercase tracking-widest text-white/40 block">
            Month
          </label>
          <select
            value={`${parsed.year}-${String(parsed.month).padStart(2, '0')}`}
            onChange={(e) => {
              const [y, m] = e.target.value.split('-').map(Number);
              go({ period: buildPeriodId(y, m, parsed.half) });
            }}
            className="w-full rounded-xl bg-black/40 border border-white/10 px-3 py-2.5 text-sm"
          >
            {monthOptions.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-2">
          <label className="text-[10px] font-black uppercase tracking-widest text-white/40 block">
            Half
          </label>
          <div className="flex gap-2">
            {(['A', 'B'] as const).map((half) => (
              <button
                key={half}
                type="button"
                onClick={() => go({ period: buildPeriodId(parsed.year, parsed.month, half) })}
                className={`px-4 py-2.5 rounded-xl text-xs font-black border ${
                  parsed.half === half
                    ? 'bg-amber-500/20 border-amber-400/40 text-amber-300'
                    : 'bg-white/5 border-white/10 text-white/50'
                }`}
              >
                {half === 'A' ? '1–15' : '16–end'}
              </button>
            ))}
          </div>
        </div>

        {(role === 'county_admin' || role === 'bd' || role === 'agency') && (
          <label className="flex items-center gap-2 text-xs text-white/60 pb-1 cursor-pointer">
            <input
              type="checkbox"
              checked={activeOnly}
              onChange={(e) => go({ active: e.target.checked })}
              className="rounded border-white/20"
            />
            Active only
          </label>
        )}
      </div>
    </div>
  );
}
