import Link from 'next/link';
import { cookies } from 'next/headers';
import { Building2 } from 'lucide-react';
import { fetchHierarchy } from '@/lib/auth/require-super-bd';
import type { HierarchyResponse } from '@/lib/types';
import { CreateAgencyForUserPanel } from '@/components/CreateAgencyForUserPanel';
import { AgencyListFilters } from '@/components/AgencyListFilters';
import { matchesSearch } from '@/lib/network';
import {
  NETWORK_PERIOD_COOKIE,
  periodLabel,
  resolvePeriodId,
  withPeriod,
} from '@/lib/period';

export default async function AgenciesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; active?: string; sort?: string; period?: string }>;
}) {
  const sp = await searchParams;
  const jar = await cookies();
  const period = resolvePeriodId(sp.period, jar.get(NETWORK_PERIOD_COOKIE)?.value ?? null);
  const data = (await fetchHierarchy(period)) as HierarchyResponse;
  const search = sp.q?.trim() ?? '';
  const activeOnly = sp.active !== '0' && sp.active !== 'false';
  const sort = sp.sort === 'hosts' ? 'hosts' : 'name';

  let agencies = [...data.tree.agencies];
  if (activeOnly) agencies = agencies.filter((a) => a.is_active);
  agencies = agencies.filter((a) =>
    matchesSearch(
      search,
      a.name,
      a.agency_code,
      a.owner_username,
      a.owner_short_id,
      a.sponsor_username,
    ),
  );
  agencies.sort((a, b) => {
    if (sort === 'hosts') return (b.host_count || 0) - (a.host_count || 0);
    return a.name.localeCompare(b.name);
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black italic">Agencies</h1>
          <p className="text-sm text-white/50 mt-2">
            {agencies.length} agencies · period {periodLabel(period)}
          </p>
        </div>
        <Link
          href={`/network?role=agency&period=${period}`}
          className="text-xs text-amber-400 hover:underline font-bold"
        >
          Network Hub →
        </Link>
      </div>

      <CreateAgencyForUserPanel />

      <AgencyListFilters
        search={search}
        activeOnly={activeOnly}
        sort={sort}
        period={period}
      />

      {agencies.length === 0 ? (
        <div className="glass-card p-10 text-center text-white/40">No agencies yet.</div>
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          {agencies.map((a) => (
            <Link
              key={a.id}
              href={withPeriod(`/agencies/${a.id}`, period)}
              className="glass-card p-6 hover:border-emerald-500/30 transition"
            >
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-xl bg-emerald-500/20 flex items-center justify-center shrink-0">
                  <Building2 className="text-emerald-400" size={20} />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-start justify-between gap-2">
                    <h2 className="font-bold text-lg truncate">{a.name}</h2>
                    {!a.is_active && (
                      <span className="text-[9px] uppercase font-black text-red-300">Off</span>
                    )}
                  </div>
                  <p className="text-xs text-white/40 mt-1">Code {a.agency_code}</p>
                  <p className="text-sm text-white/60 mt-2">
                    Owner: {a.owner_username} · Sponsor: {a.sponsor_username} ({a.sponsor_role})
                  </p>
                  <div className="flex flex-wrap gap-3 mt-2 text-xs text-amber-400/80">
                    <span>{a.host_count} hosts</span>
                    <span>{(a.period_charm ?? 0).toLocaleString()} charm</span>
                    <span>{Math.floor((a.period_on_mic_seconds ?? 0) / 3600)}h on-mic</span>
                  </div>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
