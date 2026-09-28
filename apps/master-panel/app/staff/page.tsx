import { supabaseAdmin } from '@/lib/supabase';
import Link from 'next/link';
import { ArrowLeft, Network, Plus, Users, Building2 } from 'lucide-react';
import { listStaffByRole, ROLE_LABELS, currentPeriodId } from '@/lib/salary-hub/queries';

const roleLabels: Record<string, string> = {
  ...ROLE_LABELS,
  county_admin: 'Admin',
  assistant: 'Assistant',
  customer_service: 'CS',
};

export default async function StaffPage({
  searchParams,
}: {
  searchParams: Promise<{ period?: string }>;
}) {
  const sp = await searchParams;
  const period = sp.period || currentPeriodId();

  const { data: staff } = await supabaseAdmin
    .from('business_staff')
    .select(
      `
      id,
      role,
      staff_code,
      is_active,
      created_at,
      parent_staff_id,
      users:user_id (id, username, short_id, avatar_url, diamonds)
    `,
    )
    .order('created_at', { ascending: false });

  // Enrich Super Admins / BDs with tree agency/host counts (salary hub helper)
  const [superList, bdList, countyList] = await Promise.all([
    listStaffByRole('super_bd'),
    listStaffByRole('bd'),
    listStaffByRole('bd_admin'),
  ]);
  const enrichMap = new Map(
    [...superList, ...bdList, ...countyList].map((s) => [s.id, s]),
  );

  const parentIds = Array.from(
    new Set((staff || []).map((s) => s.parent_staff_id).filter(Boolean)),
  ) as string[];

  const parentMap = new Map<string, { username: string; staff_code: string; role: string }>();
  if (parentIds.length > 0) {
    const { data: parents } = await supabaseAdmin
      .from('business_staff')
      .select('id, staff_code, role, users:user_id(username)')
      .in('id', parentIds);
    for (const p of parents || []) {
      const u = Array.isArray((p as any).users) ? (p as any).users[0] : (p as any).users;
      parentMap.set(String(p.id), {
        username: u?.username ? String(u.username) : 'Staff',
        staff_code: String(p.staff_code ?? ''),
        role: String(p.role ?? ''),
      });
    }
  }

  const childrenCount = (staff || []).reduce<Record<string, number>>((acc, row) => {
    if (row.parent_staff_id) {
      acc[row.parent_staff_id] = (acc[row.parent_staff_id] || 0) + 1;
    }
    return acc;
  }, {});

  return (
    <div className="space-y-10 pb-32">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group mb-2"
          >
            <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
            <span className="text-[10px] font-black uppercase tracking-widest">Dashboard</span>
          </Link>
          <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-4">
            <Network size={48} className="text-amber-400" />
            Staff
          </h1>
          <p className="text-white/40 font-medium max-w-xl">
            Open anyone to see full chain: team, agencies, hosts, period diamonds &amp; salary.
          </p>
        </div>
        <Link
          href="/staff/new"
          className="inline-flex items-center gap-2 px-6 py-4 bg-amber-500 hover:bg-amber-400 text-black font-black rounded-2xl transition-all"
        >
          <Plus size={18} />
          Create Staff
        </Link>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {(staff || []).map((row: any) => {
          const user = Array.isArray(row.users) ? row.users[0] : row.users;
          const parent = row.parent_staff_id ? parentMap.get(String(row.parent_staff_id)) : null;
          const enriched = enrichMap.get(row.id);
          const agencyCount = enriched?.agencyCount ?? 0;
          const hostCount = enriched?.hostCount ?? 0;
          return (
            <Link
              key={row.id}
              href={`/staff/${row.id}?period=${period}`}
              className="glass-card p-8 hover:border-amber-500/30 transition-all block"
            >
              <div className="flex items-start justify-between gap-4 mb-6">
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-amber-400/80">
                    {roleLabels[row.role] || row.role}
                  </p>
                  <h3 className="text-xl font-black mt-1">{user?.username || 'Unknown'}</h3>
                  <p className="text-xs text-white/40">ID: {user?.short_id ?? '—'}</p>
                </div>
                <span
                  className={`text-[10px] font-black uppercase px-3 py-1 rounded-full ${
                    row.is_active
                      ? 'bg-emerald-500/20 text-emerald-300'
                      : 'bg-red-500/20 text-red-300'
                  }`}
                >
                  {row.is_active ? 'Active' : 'Inactive'}
                </span>
              </div>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p className="text-white/30 text-[10px] font-black uppercase">Staff Code</p>
                  <p className="font-bold">{row.staff_code}</p>
                </div>
                <div>
                  <p className="text-white/30 text-[10px] font-black uppercase">Wallet dia</p>
                  <p className="font-bold tabular-nums">
                    {Number(user?.diamonds || 0).toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-white/30 text-[10px] font-black uppercase">Direct team</p>
                  <p className="font-bold flex items-center gap-1">
                    <Users size={14} />
                    {childrenCount[row.id] || 0}
                  </p>
                </div>
                <div>
                  <p className="text-white/30 text-[10px] font-black uppercase">Tree</p>
                  <p className="font-bold flex items-center gap-1 text-xs">
                    <Building2 size={14} />
                    {agencyCount} ag · {hostCount} hosts
                  </p>
                </div>
                <div className="col-span-2">
                  <p className="text-white/30 text-[10px] font-black uppercase">Parent</p>
                  <p className="font-bold text-sm">
                    {parent
                      ? `${parent.username} · ${roleLabels[parent.role] || parent.role} (${parent.staff_code})`
                      : '—'}
                  </p>
                </div>
              </div>
              <p className="text-[10px] font-black uppercase tracking-widest text-amber-400/60 mt-5">
                Open chain · diamonds · salary →
              </p>
            </Link>
          );
        })}
      </div>

      {(staff || []).length === 0 && (
        <div className="glass-card py-16 text-center text-white/40">No staff yet.</div>
      )}
    </div>
  );
}
