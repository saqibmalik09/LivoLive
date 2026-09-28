import Link from 'next/link';
import { Building2, Network, Users } from 'lucide-react';
import { fetchHierarchy } from '@/lib/auth/require-super-bd';
import { HierarchyTree } from '@/components/HierarchyTree';
import { staffRoleLabel, normalizePortalRole } from '@/lib/permissions';
import type { HierarchyResponse, StaffNode } from '@/lib/types';
import { matchesSearch } from '@/lib/network';
import { TeamListFilters } from '@/components/TeamListFilters';

export default async function TeamPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; role?: string }>;
}) {
  const sp = await searchParams;
  const data = (await fetchHierarchy()) as HierarchyResponse;
  const search = sp.q?.trim() ?? '';
  const roleFilter = sp.role?.trim() ?? 'all';

  let staff = data.tree.staff.filter((s) => s.depth > 0);
  if (roleFilter !== 'all') {
    staff = staff.filter((s) => normalizePortalRole(s.role) === roleFilter);
  }
  staff = staff.filter((s) =>
    matchesSearch(search, s.username, s.short_id, s.staff_code, s.role),
  );

  return (
    <div className="space-y-8">
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black italic flex items-center gap-3">
            <Network size={32} className="text-amber-400" />
            Team
          </h1>
          <p className="text-sm text-white/50 mt-2">
            Super Admin → Country Admin / BD → Agency → Hosts
          </p>
        </div>
        <Link href="/network?role=bd" className="text-xs text-amber-400 hover:underline font-bold">
          Open Network Hub →
        </Link>
      </div>

      <TeamListFilters search={search} role={roleFilter} />

      <section className="space-y-4">
        <p className="text-[10px] font-black uppercase tracking-widest text-white/30">
          Staff · {staff.length}
        </p>
        {staff.length === 0 ? (
          <div className="glass-card p-10 text-center text-white/40">No matching staff.</div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            {staff.map((row) => (
              <StaffCard key={row.id} row={row} />
            ))}
          </div>
        )}
      </section>

      <section className="glass-card p-5 md:p-8">
        <h2 className="text-sm font-black uppercase tracking-widest text-white/50 mb-6">
          Org chart
        </h2>
        <HierarchyTree
          staff={data.tree.staff}
          agencies={data.tree.agencies}
          hosts={data.tree.hosts}
          rootStaffId={data.me.staff_id}
        />
      </section>
    </div>
  );
}

function StaffCard({ row }: { row: StaffNode }) {
  return (
    <Link
      href={`/team/${row.id}`}
      className="glass-card p-6 hover:border-amber-500/30 transition-all block"
    >
      <div className="flex items-start justify-between gap-4 mb-5">
        <div>
          <p className="text-[10px] font-black uppercase tracking-widest text-amber-400/80">
            {staffRoleLabel(row.role)}
          </p>
          <h3 className="text-xl font-black mt-1">{row.username}</h3>
          <p className="text-xs text-white/40">ID: {row.short_id}</p>
        </div>
        <span
          className={`text-[10px] font-black uppercase px-3 py-1 rounded-full ${
            row.is_active ? 'bg-emerald-500/20 text-emerald-300' : 'bg-red-500/20 text-red-300'
          }`}
        >
          {row.is_active ? 'Active' : 'Inactive'}
        </span>
      </div>
      <div className="grid grid-cols-2 gap-4 text-sm">
        <div>
          <p className="text-white/30 text-[10px] font-black uppercase">Staff Code</p>
          <p className="font-bold font-mono text-xs">{row.staff_code}</p>
        </div>
        <div>
          <p className="text-white/30 text-[10px] font-black uppercase">Team</p>
          <p className="font-bold flex items-center gap-1">
            <Users size={14} />
            {row.direct_team_count}
          </p>
        </div>
        <div>
          <p className="text-white/30 text-[10px] font-black uppercase">Agencies</p>
          <p className="font-bold flex items-center gap-1">
            <Building2 size={14} />
            {row.direct_agency_count}
          </p>
        </div>
        <div>
          <p className="text-white/30 text-[10px] font-black uppercase">Depth</p>
          <p className="font-bold">{row.depth}</p>
        </div>
      </div>
    </Link>
  );
}
