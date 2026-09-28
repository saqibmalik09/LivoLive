import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, User } from 'lucide-react';
import { fetchHierarchy, requireStaff } from '@/lib/auth/require-super-bd';
import { getPortalPermissions } from '@/lib/permissions';
import type { HierarchyResponse } from '@/lib/types';
import { DeactivateAgencyButton } from '@/components/DeactivateAgencyButton';
import { PeriodBanner } from '@/components/PeriodBanner';
import { resolvePeriodId, withPeriod } from '@/lib/period';

export default async function AgencyDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ period?: string }>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const period = resolvePeriodId(sp.period, null);
  const { staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);
  const data = (await fetchHierarchy(period)) as HierarchyResponse;
  const agency = data.tree.agencies.find((a) => a.id === id);
  if (!agency) notFound();

  const hosts = data.tree.hosts.filter((h) => h.agency_id === id);
  const canDeactivate = permissions.canDeactivateAgency && agency.is_active;
          const totalCharm = hosts.reduce(
    (acc, h) => acc + ((h.period_charm ?? h.period_diamonds) || 0),
    0,
  );
  const totalMic = hosts.reduce((acc, h) => acc + (h.period_on_mic_seconds || 0), 0);
  const totalValid = hosts.reduce((acc, h) => acc + (h.period_valid_days || 0), 0);

  return (
    <div className="space-y-8">
      <Link
        href={withPeriod('/agencies', data.period_id)}
        className="inline-flex items-center gap-2 text-white/40 hover:text-white text-sm"
      >
        <ArrowLeft size={16} />
        All agencies
      </Link>

      <PeriodBanner
        period={data.period_id}
        hubHref={`/network?role=agency&period=${data.period_id}`}
      />

      <div className="glass-card p-6 md:p-8 space-y-3">
        <h1 className="text-3xl font-black">{agency.name}</h1>
        <p className="text-white/50 text-sm">
          Code <span className="font-mono text-emerald-300">{agency.agency_code}</span>
          {!agency.is_active ? ' · Inactive' : ''}
        </p>
        <p className="text-sm text-white/60">
          Owner: {agency.owner_username} (ID {agency.owner_short_id})
        </p>
        <p className="text-sm text-white/60">
          Sponsor: {agency.sponsor_username} · {agency.sponsor_role}
        </p>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 pt-4">
          <div className="rounded-xl bg-black/30 border border-white/5 p-4">
            <p className="text-[9px] uppercase tracking-widest text-white/30">Hosts</p>
            <p className="text-2xl font-black">{hosts.length}</p>
          </div>
          <div className="rounded-xl bg-black/30 border border-white/5 p-4">
            <p className="text-[9px] uppercase tracking-widest text-white/30">Charm</p>
            <p className="text-2xl font-black text-amber-300">{totalCharm.toLocaleString()}</p>
          </div>
          <div className="rounded-xl bg-black/30 border border-white/5 p-4">
            <p className="text-[9px] uppercase tracking-widest text-white/30">On-mic</p>
            <p className="text-2xl font-black">{Math.floor(totalMic / 3600)}h</p>
          </div>
          <div className="rounded-xl bg-black/30 border border-white/5 p-4">
            <p className="text-[9px] uppercase tracking-widest text-white/30">Valid days Σ</p>
            <p className="text-2xl font-black">{totalValid}</p>
          </div>
        </div>

        {canDeactivate && <DeactivateAgencyButton agencyId={agency.id} name={agency.name} />}
      </div>

      <section className="space-y-4">
        <h2 className="text-sm font-black uppercase tracking-widest text-white/50">
          Hosts ({hosts.length})
        </h2>
        {hosts.length === 0 ? (
          <div className="glass-card p-8 text-center text-white/40 text-sm">No hosts in this agency.</div>
        ) : (
          <div className="space-y-3">
            {hosts.map((host) => (
              <Link
                key={host.member_id}
                href={withPeriod(`/agencies/${id}/hosts/${host.user_id}`, data.period_id)}
                className="glass-card p-4 md:p-5 flex flex-col sm:flex-row sm:items-center gap-4 hover:border-blue-500/30 transition"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <User size={18} className="text-blue-300 shrink-0" />
                  <div>
                    <p className="font-semibold">{host.username}</p>
                    <p className="text-xs text-white/40">ID {host.short_id}</p>
                  </div>
                </div>
                <div className="flex flex-wrap gap-4 text-xs text-white/50 sm:ml-auto">
                  <span>
                    {(host.period_charm ?? host.period_diamonds).toLocaleString()} period charm
                  </span>
                  <span>{Math.floor(host.period_on_mic_seconds / 3600)}h on-mic</span>
                  <span>{host.period_valid_days} valid days</span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
