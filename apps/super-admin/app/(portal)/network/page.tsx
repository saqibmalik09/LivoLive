import Link from 'next/link';
import { cookies } from 'next/headers';
import { Building2, Mic, Network, Users } from 'lucide-react';
import { fetchHierarchy } from '@/lib/auth/require-super-bd';
import { NetworkFilters } from '@/components/NetworkFilters';
import {
  agencyNameById,
  filterHierarchy,
  hostCountUnderStaff,
  parseNetworkRole,
} from '@/lib/network';
import {
  NETWORK_PERIOD_COOKIE,
  periodLabel,
  resolvePeriodId,
  withPeriod,
} from '@/lib/period';
import { staffRoleLabel as roleLabel } from '@/lib/permissions';
import type { HierarchyResponse } from '@/lib/types';

export default async function NetworkPage({
  searchParams,
}: {
  searchParams: Promise<{ role?: string; period?: string; q?: string; active?: string }>;
}) {
  const sp = await searchParams;
  const jar = await cookies();
  const role = parseNetworkRole(sp.role);
  const period = resolvePeriodId(sp.period, jar.get(NETWORK_PERIOD_COOKIE)?.value ?? null);
  const search = sp.q?.trim() ?? '';
  // Default: show active only when checkbox is on; URL active=0 shows all
  const activeOnly = sp.active !== '0' && sp.active !== 'false';

  const data = (await fetchHierarchy(period)) as HierarchyResponse;
  const filtered = filterHierarchy(data, role, search, activeOnly);
  const agencyNames = agencyNameById(data.tree.agencies);

  return (
    <div className="space-y-8">
      <header className="space-y-2">
        <p className="text-[10px] font-black uppercase tracking-[0.2em] text-amber-400/80">
          Hierarchy · Network
        </p>
        <h1 className="text-3xl md:text-4xl font-black italic tracking-tight flex items-center gap-3">
          <Network size={36} className="text-amber-400" />
          Network Hub
        </h1>
        <p className="text-sm text-white/50">
          Browse your downline by role · period{' '}
          <span className="text-amber-300 font-semibold">{periodLabel(period)}</span>
        </p>
      </header>

      <NetworkFilters role={role} period={period} search={search} activeOnly={activeOnly} />

      {(role === 'county_admin' || role === 'bd') && (
        <section className="space-y-4">
          <p className="text-[10px] font-black uppercase tracking-widest text-white/30">
            {roleLabel(role)} · {filtered.staff.length}
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {filtered.staff.map((s) => {
              const hosts = hostCountUnderStaff(
                s.id,
                data.tree.agencies,
                data.tree.hosts,
                data.tree.staff,
              );
              return (
                <Link
                  key={s.id}
                  href={withPeriod(`/team/${s.id}`, period)}
                  className="glass-card p-6 hover:border-amber-500/30 transition-colors group"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <p className="text-[10px] font-black uppercase tracking-widest text-amber-400/70">
                        {roleLabel(s.role)}
                      </p>
                      <h2 className="text-xl font-black group-hover:text-amber-200">{s.username}</h2>
                      <p className="text-xs text-white/40 mt-1">
                        Code {s.staff_code} · ID {s.short_id}
                      </p>
                    </div>
                    <span
                      className={`text-[9px] font-black uppercase tracking-widest px-2 py-1 rounded-lg ${
                        s.is_active
                          ? 'bg-emerald-500/15 text-emerald-300'
                          : 'bg-white/5 text-white/30'
                      }`}
                    >
                      {s.is_active ? 'Active' : 'Off'}
                    </span>
                  </div>
                  <div className="mt-5 grid grid-cols-3 gap-3 text-center">
                    <div className="rounded-xl bg-black/30 border border-white/5 py-3">
                      <Users size={14} className="mx-auto text-amber-400/70 mb-1" />
                      <p className="text-lg font-black">{s.direct_team_count}</p>
                      <p className="text-[9px] uppercase tracking-widest text-white/30">Team</p>
                    </div>
                    <div className="rounded-xl bg-black/30 border border-white/5 py-3">
                      <Building2 size={14} className="mx-auto text-pink-400/70 mb-1" />
                      <p className="text-lg font-black">{s.direct_agency_count}</p>
                      <p className="text-[9px] uppercase tracking-widest text-white/30">Agencies</p>
                    </div>
                    <div className="rounded-xl bg-black/30 border border-white/5 py-3">
                      <Mic size={14} className="mx-auto text-blue-400/70 mb-1" />
                      <p className="text-lg font-black">{hosts}</p>
                      <p className="text-[9px] uppercase tracking-widest text-white/30">Hosts</p>
                    </div>
                  </div>
                </Link>
              );
            })}
            {filtered.staff.length === 0 && (
              <p className="text-white/30 text-sm">No staff in this role.</p>
            )}
          </div>
        </section>
      )}

      {role === 'agency' && (
        <section className="space-y-4">
          <p className="text-[10px] font-black uppercase tracking-widest text-white/30">
            Agencies · {filtered.agencies.length}
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {filtered.agencies.map((a) => (
              <Link
                key={a.id}
                href={withPeriod(`/agencies/${a.id}`, period)}
                className="glass-card p-6 hover:border-emerald-500/30 transition-colors"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-[10px] font-black uppercase tracking-widest text-emerald-400/70">
                      Agency
                    </p>
                    <h2 className="text-xl font-black truncate">{a.name}</h2>
                    <p className="text-xs text-white/40 mt-1">
                      Code {a.agency_code} · Owner {a.owner_username}
                    </p>
                    <p className="text-xs text-white/35 mt-1">
                      Sponsor {a.sponsor_username || '—'} ({a.sponsor_role || '—'})
                    </p>
                  </div>
                  <div className="text-right shrink-0">
                    <p className="text-lg font-black">{a.host_count}</p>
                    <p className="text-[9px] uppercase tracking-widest text-white/30">Hosts</p>
                    <p className="text-xs text-amber-400/80 mt-2">
                      {(a.period_charm ?? 0).toLocaleString()} charm
                    </p>
                  </div>
                </div>
              </Link>
            ))}
            {filtered.agencies.length === 0 && (
              <p className="text-white/30 text-sm">No agencies found.</p>
            )}
          </div>
        </section>
      )}

      {role === 'host' && (
        <section className="space-y-4">
          <p className="text-[10px] font-black uppercase tracking-widest text-white/30">
            Hosts · {filtered.hosts.length} · {period}
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {filtered.hosts.map((h) => (
              <Link
                key={h.member_id}
                href={withPeriod(`/agencies/${h.agency_id}/hosts/${h.user_id}`, period)}
                className="glass-card p-6 hover:border-blue-500/30 transition-colors"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-[10px] font-black uppercase tracking-widest text-blue-400/70">
                      Host
                    </p>
                    <h2 className="text-xl font-black truncate">{h.username}</h2>
                    <p className="text-xs text-white/40 mt-1 truncate">
                      {agencyNames[h.agency_id] || 'Agency'} · ID {h.short_id}
                    </p>
                  </div>
                  <div className="text-right shrink-0 text-xs text-white/50 space-y-1">
                    <p className="text-amber-300 font-bold">
                      {(h.period_charm ?? h.period_diamonds).toLocaleString()} charm
                    </p>
                    <p>{Math.floor(h.period_on_mic_seconds / 3600)}h on-mic</p>
                    <p>{h.period_valid_days} valid days</p>
                  </div>
                </div>
              </Link>
            ))}
            {filtered.hosts.length === 0 && (
              <p className="text-white/30 text-sm">No hosts found.</p>
            )}
          </div>
        </section>
      )}
    </div>
  );
}
