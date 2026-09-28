import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, Building2, Mic, Users } from 'lucide-react';
import { fetchHierarchy, requireStaff } from '@/lib/auth/require-super-bd';
import { getPortalPermissions, staffRoleLabel, normalizePortalRole } from '@/lib/permissions';
import type { HierarchyResponse } from '@/lib/types';
import { DeactivateStaffButton } from '@/components/DeactivateStaffButton';
import { PeriodBanner } from '@/components/PeriodBanner';
import { hostCountUnderStaff } from '@/lib/network';

export default async function StaffDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ staffId: string }>;
  searchParams: Promise<{ period?: string }>;
}) {
  const { staffId } = await params;
  const sp = await searchParams;
  const { staff } = await requireStaff();
  const permissions = getPortalPermissions(staff.role);
  const data = (await fetchHierarchy(sp.period)) as HierarchyResponse;
  const member = data.tree.staff.find((s) => s.id === staffId);
  if (!member) notFound();

  const team = data.tree.staff.filter((s) => s.parent_staff_id === staffId);
  const agencies = data.tree.agencies.filter((a) => a.sponsor_staff_id === staffId);
  const hostCount = hostCountUnderStaff(
    staffId,
    data.tree.agencies,
    data.tree.hosts,
    data.tree.staff,
  );
  const normalized = normalizePortalRole(member.role);
  const canRemove =
    permissions.canDeactivateStaff &&
    member.is_active &&
    (normalized === 'bd' || normalized === 'county_admin');

  return (
    <div className="space-y-8">
      <Link href="/team" className="inline-flex items-center gap-2 text-white/40 hover:text-white text-sm">
        <ArrowLeft size={16} />
        Back to team
      </Link>

      <PeriodBanner
        period={data.period_id}
        hubHref={`/network?role=${normalized === 'bd' ? 'bd' : 'county_admin'}&period=${data.period_id}`}
      />

      <div className="glass-card p-6 md:p-8 space-y-4">
        <p className="text-[10px] font-black uppercase tracking-widest text-amber-400">
          {staffRoleLabel(member.role)}
        </p>
        <h1 className="text-3xl font-black">{member.username}</h1>
        <p className="text-white/50 text-sm">
          ID {member.short_id} · Code {member.staff_code}
          {!member.is_active ? ' · Inactive' : ''}
        </p>

        <div className="grid grid-cols-3 gap-3 max-w-md pt-2">
          <div className="rounded-xl bg-black/30 border border-white/5 p-4 text-center">
            <Users size={16} className="mx-auto text-amber-400/70 mb-1" />
            <p className="text-xl font-black">{member.direct_team_count}</p>
            <p className="text-[9px] uppercase tracking-widest text-white/30">Team</p>
          </div>
          <div className="rounded-xl bg-black/30 border border-white/5 p-4 text-center">
            <Building2 size={16} className="mx-auto text-pink-400/70 mb-1" />
            <p className="text-xl font-black">{member.direct_agency_count}</p>
            <p className="text-[9px] uppercase tracking-widest text-white/30">Agencies</p>
          </div>
          <div className="rounded-xl bg-black/30 border border-white/5 p-4 text-center">
            <Mic size={16} className="mx-auto text-blue-400/70 mb-1" />
            <p className="text-xl font-black">{hostCount}</p>
            <p className="text-[9px] uppercase tracking-widest text-white/30">Hosts</p>
          </div>
        </div>

        {canRemove && (
          <DeactivateStaffButton
            staffId={member.id}
            label={`${staffRoleLabel(member.role)} ${member.username}`}
          />
        )}
      </div>

      {team.length > 0 && (
        <section className="space-y-4">
          <h2 className="text-sm font-black uppercase tracking-widest text-white/50">Direct team</h2>
          <div className="grid gap-3 md:grid-cols-2">
            {team.map((t) => (
              <Link key={t.id} href={`/team/${t.id}`} className="glass-card p-5 hover:border-amber-500/30">
                <p className="text-[10px] uppercase text-amber-400/70">{staffRoleLabel(t.role)}</p>
                <p className="font-bold text-lg">{t.username}</p>
                <p className="text-xs text-white/40">
                  {t.staff_code} · {t.direct_agency_count} agencies
                </p>
              </Link>
            ))}
          </div>
        </section>
      )}

      {agencies.length > 0 && (
        <section className="space-y-4">
          <h2 className="text-sm font-black uppercase tracking-widest text-white/50">
            Sponsored agencies
          </h2>
          <div className="grid gap-3 md:grid-cols-2">
            {agencies.map((a) => (
              <Link
                key={a.id}
                href={`/agencies/${a.id}?period=${data.period_id}`}
                className="glass-card p-5 hover:border-emerald-500/30"
              >
                <div className="flex items-center gap-2 text-emerald-400 mb-2">
                  <Building2 size={16} />
                  <span className="text-[10px] font-black uppercase">Agency</span>
                </div>
                <p className="font-bold text-lg">{a.name}</p>
                <p className="text-xs text-white/40">
                  {a.agency_code} · {a.host_count} hosts · {(a.period_charm ?? 0).toLocaleString()} charm
                </p>
              </Link>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
