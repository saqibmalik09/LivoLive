import { supabaseAdmin } from '@/lib/supabase';
import Link from 'next/link';
import { ArrowLeft, Building2, Search } from 'lucide-react';

export default async function AgenciesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; sponsor_staff_id?: string }>;
}) {
  const sp = await searchParams;
  const q = sp.q?.trim() ?? '';
  const sponsorStaffId = sp.sponsor_staff_id?.trim() || null;

  let query = supabaseAdmin
    .from('agencies')
    .select(
      `
      id,
      name,
      agency_code,
      is_active,
      sponsor_staff_id,
      owner:owner_id(username, short_id),
      sponsor:business_staff!sponsor_staff_id(
        id,
        staff_code,
        role,
        users:user_id(username, short_id)
      )
    `,
    )
    .order('name', { ascending: true })
    .limit(200);

  if (sponsorStaffId) {
    query = query.eq('sponsor_staff_id', sponsorStaffId);
  }

  const { data: agencies, error } = await query;

  const filtered = (agencies || []).filter((a: any) => {
    if (!q) return true;
    const owner = Array.isArray(a.owner) ? a.owner[0] : a.owner;
    const sponsor = Array.isArray(a.sponsor) ? a.sponsor[0] : a.sponsor;
    const sponsorUser = Array.isArray(sponsor?.users) ? sponsor?.users[0] : sponsor?.users;
    const hay = [
      a.name,
      a.agency_code,
      owner?.username,
      owner?.short_id,
      sponsor?.staff_code,
      sponsorUser?.username,
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    return hay.includes(q.toLowerCase());
  });

  return (
    <div className="space-y-8 pb-32">
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group mb-2"
          >
            <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
            <span className="text-[10px] font-black uppercase tracking-widest">Dashboard</span>
          </Link>
          <h1 className="text-5xl font-black tracking-tighter italic flex items-center gap-3">
            <Building2 className="text-emerald-400" size={44} />
            Agencies
          </h1>
          <p className="text-white/40 mt-2">
            {filtered.length} shown
            {sponsorStaffId ? ` · filtered by sponsor ${sponsorStaffId.slice(0, 8)}…` : ''}
          </p>
        </div>

        <form className="relative w-full md:w-96" action="/agencies" method="get">
          {sponsorStaffId && (
            <input type="hidden" name="sponsor_staff_id" value={sponsorStaffId} />
          )}
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-white/30" size={18} />
          <input
            name="q"
            defaultValue={q}
            placeholder="Search name, code, owner, BD…"
            className="w-full bg-black/40 border border-white/10 rounded-2xl py-4 pl-12 pr-4 text-white placeholder:text-white/20 focus:outline-none focus:border-emerald-500/50"
          />
        </form>
      </div>

      {error && (
        <div className="rounded-2xl border border-red-500/30 bg-red-500/10 px-6 py-4 text-sm text-red-200">
          Failed to load agencies: {error.message}
        </div>
      )}

      <div className="grid gap-4 md:grid-cols-2">
        {filtered.map((a: any) => {
          const owner = Array.isArray(a.owner) ? a.owner[0] : a.owner;
          const sponsor = Array.isArray(a.sponsor) ? a.sponsor[0] : a.sponsor;
          const sponsorUser = Array.isArray(sponsor?.users) ? sponsor?.users[0] : sponsor?.users;
          return (
            <Link
              key={a.id}
              href={`/agencies/${a.id}`}
              className="glass-card p-6 hover:border-emerald-500/30 transition block"
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <h2 className="font-bold text-lg truncate">{a.name}</h2>
                  <p className="text-xs text-white/40 mt-1">Code {a.agency_code ?? '—'}</p>
                </div>
                {!a.is_active && (
                  <span className="text-[9px] uppercase font-black text-red-300">Off</span>
                )}
              </div>
              <p className="text-sm text-white/60 mt-3">
                Owner: {owner?.username ?? '—'}
                {owner?.short_id != null ? ` · UID ${owner.short_id}` : ''}
              </p>
              <p className="text-sm text-emerald-300/80 mt-1">
                Sponsor:{' '}
                {sponsor
                  ? `${sponsorUser?.username ?? 'Staff'} (${sponsor.staff_code}) · ${sponsor.role}`
                  : 'None'}
              </p>
            </Link>
          );
        })}
      </div>

      {filtered.length === 0 && (
        <div className="glass-card py-16 text-center text-white/40">No agencies found.</div>
      )}
    </div>
  );
}
