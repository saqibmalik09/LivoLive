import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, Clock, User, Zap } from 'lucide-react';
import {
  fetchHierarchy,
  fetchHostPeriodStats,
} from '@/lib/auth/require-super-bd';
import type { HierarchyResponse, HostPeriodStat } from '@/lib/types';
import { PeriodBanner } from '@/components/PeriodBanner';
import { periodLabel, resolvePeriodId, withPeriod } from '@/lib/period';

export default async function HostDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string; hostId: string }>;
  searchParams: Promise<{ period?: string }>;
}) {
  const { id: agencyId, hostId } = await params;
  const sp = await searchParams;
  const period = resolvePeriodId(sp.period, null);
  const data = (await fetchHierarchy(period)) as HierarchyResponse;

  const agency = data.tree.agencies.find((a) => a.id === agencyId);
  const host = data.tree.hosts.find((h) => h.user_id === hostId && h.agency_id === agencyId);
  if (!agency || !host) notFound();

  let history: HostPeriodStat[] = [];
  try {
    history = await fetchHostPeriodStats(hostId);
  } catch {
    history = [];
  }

  const current =
    history.find((h) => h.period_id === data.period_id) ||
    ({
      period_id: data.period_id,
      total_diamonds: host.period_diamonds,
      charm_points: host.period_charm ?? host.period_diamonds,
      total_on_mic_seconds: host.period_on_mic_seconds,
      valid_days: host.period_valid_days,
    } satisfies HostPeriodStat);

  const totalDiamonds = history.reduce((a, h) => a + (h.total_diamonds || 0), 0);
  const totalHours = Math.floor(
    history.reduce((a, h) => a + (h.total_on_mic_seconds || 0), 0) / 3600,
  );

  return (
    <div className="space-y-8">
      <Link
        href={withPeriod(`/agencies/${agencyId}`, data.period_id)}
        className="inline-flex items-center gap-2 text-white/40 hover:text-white text-sm"
      >
        <ArrowLeft size={16} />
        Back to {agency.name}
      </Link>

      <PeriodBanner
        period={data.period_id}
        hubHref={`/network?role=host&period=${data.period_id}`}
      />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="glass-card p-8 text-center space-y-4">
          <div className="w-24 h-24 rounded-full mx-auto overflow-hidden bg-white/5 border border-white/10 flex items-center justify-center">
            {host.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={host.avatar_url} alt="" className="w-full h-full object-cover" />
            ) : (
              <User size={40} className="text-blue-300" />
            )}
          </div>
          <div>
            <h1 className="text-2xl font-black">@{host.username}</h1>
            <p className="text-sm text-white/40 mt-1">ID {host.short_id}</p>
            <p className="text-xs text-white/50 mt-2">{agency.name}</p>
          </div>
          <div className="grid grid-cols-2 gap-3 pt-2">
            <div className="rounded-xl bg-black/30 border border-white/5 p-3">
              <p className="text-[9px] uppercase tracking-widest text-white/30">History diamonds</p>
              <p className="font-black text-emerald-400">{totalDiamonds.toLocaleString()}</p>
            </div>
            <div className="rounded-xl bg-black/30 border border-white/5 p-3">
              <p className="text-[9px] uppercase tracking-widest text-white/30">Total hours</p>
              <p className="font-black text-blue-400">{totalHours}h</p>
            </div>
          </div>
        </div>

        <div className="lg:col-span-2 space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="glass-card p-6 border-amber-500/20 bg-amber-500/5">
              <div className="flex items-center justify-between mb-2">
                <Zap size={20} className="text-amber-400" />
                <span className="text-[10px] font-black uppercase text-amber-400/60">Charm</span>
              </div>
              <p className="text-2xl font-black text-amber-300">
                {(current.charm_points || 0).toLocaleString()}
              </p>
              <p className="text-[10px] text-white/30 mt-1">{periodLabel(data.period_id)}</p>
            </div>
            <div className="glass-card p-6 border-emerald-500/20 bg-emerald-500/5">
              <div className="flex items-center justify-between mb-2">
                <Zap size={20} className="text-emerald-400" />
                <span className="text-[10px] font-black uppercase text-emerald-400/60">Diamonds</span>
              </div>
              <p className="text-2xl font-black">
                {(current.total_diamonds || 0).toLocaleString()}
              </p>
            </div>
            <div className="glass-card p-6 border-blue-500/20 bg-blue-500/5">
              <div className="flex items-center justify-between mb-2">
                <Clock size={20} className="text-blue-400" />
                <span className="text-[10px] font-black uppercase text-blue-400/60">On-mic</span>
              </div>
              <p className="text-2xl font-black">
                {Math.floor((current.total_on_mic_seconds || 0) / 3600)}h
              </p>
              <p className="text-[10px] text-white/30 mt-1">{current.valid_days || 0} valid days</p>
            </div>
          </div>

          <section className="glass-card p-6 space-y-4">
            <h2 className="text-sm font-black uppercase tracking-widest text-white/50">
              Period history
            </h2>
            {history.length === 0 ? (
              <p className="text-sm text-white/40">No period history yet.</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-[10px] uppercase tracking-widest text-white/30 text-left">
                      <th className="pb-3 pr-4">Period</th>
                      <th className="pb-3 pr-4">Charm</th>
                      <th className="pb-3 pr-4">Diamonds</th>
                      <th className="pb-3 pr-4">On-mic</th>
                      <th className="pb-3">Valid</th>
                    </tr>
                  </thead>
                  <tbody>
                    {history.map((row) => (
                      <tr
                        key={row.period_id}
                        className={`border-t border-white/5 ${
                          row.period_id === data.period_id ? 'text-amber-200' : 'text-white/70'
                        }`}
                      >
                        <td className="py-3 pr-4 font-mono text-xs">{row.period_id}</td>
                        <td className="py-3 pr-4">{(row.charm_points || 0).toLocaleString()}</td>
                        <td className="py-3 pr-4">{(row.total_diamonds || 0).toLocaleString()}</td>
                        <td className="py-3 pr-4">
                          {Math.floor((row.total_on_mic_seconds || 0) / 3600)}h
                        </td>
                        <td className="py-3">{row.valid_days || 0}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
