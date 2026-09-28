import { supabaseAdmin } from '@/lib/supabase';
import { ArrowLeft, Building2, User, Banknote, Wallet } from 'lucide-react';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { AgencyTransferControls } from './AgencyTransferControls';
import { getHubPeriod } from '@/lib/salary-hub/period';
import { withPeriod, periodOptions } from '@/lib/salary-hub/constants';
import {
  estimateAgencyUsd,
  estimateHostUsd,
  formatUsd,
  loadSalarySettings,
} from '@/lib/salary-hub/salary-calc';

interface AgencyDetailProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ period?: string }>;
}

export default async function AgencyDetailPage({
  params,
  searchParams,
}: AgencyDetailProps) {
  const { id } = await params;
  const sp = await searchParams;
  const periodId = await getHubPeriod(sp.period);

  const { data: agency, error } = await supabaseAdmin
    .from('agencies')
    .select(
      '*, users:owner_id(username, avatar_url, short_id), sponsor:business_staff!sponsor_staff_id(id, staff_code, role, users:user_id(username, short_id))',
    )
    .eq('id', id)
    .single();

  if (error || !agency) notFound();

  const { data: members } = await supabaseAdmin
    .from('agency_members')
    .select('*, users(username, avatar_url, short_id, user_level, diamonds)')
    .eq('agency_id', id);

  const [{ data: bdRows }, { data: otherAgencyRows }] = await Promise.all([
    supabaseAdmin
      .from('business_staff')
      .select('id, staff_code, user:user_id(username, short_id)')
      .eq('role', 'bd')
      .eq('is_active', true)
      .order('created_at', { ascending: false }),
    supabaseAdmin
      .from('agencies')
      .select('id, name, agency_code, is_active')
      .eq('is_active', true)
      .neq('id', id)
      .order('name', { ascending: true }),
  ]);

  const bdOptions = (bdRows ?? []).map((row: any) => {
    const u = Array.isArray(row.user) ? row.user[0] : row.user;
    return {
      id: String(row.id),
      staffCode: String(row.staff_code ?? ''),
      username: u?.username ? String(u.username) : 'BD',
      shortId: u?.short_id != null ? String(u.short_id) : null,
    };
  });

  const otherAgencies = (otherAgencyRows ?? []).map((a: any) => ({
    id: String(a.id),
    name: String(a.name ?? 'Agency'),
    agencyCode: a.agency_code != null ? String(a.agency_code) : null,
  }));

  const memberOptions = (members ?? []).map((m: any) => ({
    userId: String(m.user_id),
    username: m.users?.username ? String(m.users.username) : 'host',
  }));

  const owner = Array.isArray(agency.users) ? agency.users[0] : agency.users;
  const sponsor = Array.isArray(agency.sponsor) ? agency.sponsor[0] : agency.sponsor;
  const sponsorUser = Array.isArray(sponsor?.users) ? sponsor?.users[0] : sponsor?.users;

  const memberIds = (members ?? []).map((m: any) => m.user_id as string);
  const settings = await loadSalarySettings();

  const { data: periodStats } = memberIds.length
    ? await supabaseAdmin
        .from('host_period_stats')
        .select(
          'user_id, period_id, charm_points, total_diamonds, total_on_mic_seconds, valid_days',
        )
        .eq('period_id', periodId)
        .in('user_id', memberIds)
    : { data: [] as any[] };

  const statsByUser = new Map(
    (periodStats || []).map((s: any) => [s.user_id as string, s]),
  );

  let periodDiamonds = 0;
  let periodCharm = 0;
  let hostSalaryUsd = 0;
  const hostCharms: number[] = [];
  const hostRows = (members ?? []).map((m: any) => {
    const stat = statsByUser.get(m.user_id);
    const diamonds = Number(stat?.total_diamonds || 0) || 0;
    const charm = Number(stat?.charm_points || 0) || 0;
    periodDiamonds += diamonds;
    periodCharm += charm;
    hostCharms.push(charm);
    const est = estimateHostUsd(settings, {
      charm_points: charm,
      total_diamonds: diamonds,
      total_on_mic_seconds: Number(stat?.total_on_mic_seconds || 0) || 0,
      valid_days: Number(stat?.valid_days || 0) || 0,
    });
    hostSalaryUsd += est.estimatedUsd;
    return {
      ...m,
      periodDiamonds: diamonds,
      periodCharm: charm,
      estimatedUsd: est.estimatedUsd,
      charmSalaryUsd: est.charmSalaryUsd,
    };
  });

  const agencyEst = estimateAgencyUsd(settings, hostCharms);
  const periods = periodOptions().slice(0, 6);

  return (
    <div className="space-y-8 pb-32">
      <Link
        href="/agencies"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Agencies</span>
      </Link>

      <div className="glass-card p-4 flex flex-wrap gap-2 items-center">
        <p className="text-[10px] font-black uppercase tracking-widest text-white/40 mr-2">
          Period
        </p>
        {periods.map((p) => (
          <Link
            key={p}
            href={withPeriod(`/agencies/${id}`, p)}
            className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest ${
              p === periodId
                ? 'bg-amber-500 text-black'
                : 'bg-white/5 text-white/50 hover:bg-white/10'
            }`}
          >
            {p}
          </Link>
        ))}
      </div>

      <div className="glass-card p-8 space-y-4">
        <div className="flex items-start gap-4">
          <div className="w-14 h-14 rounded-2xl bg-emerald-500/20 flex items-center justify-center">
            <Building2 className="text-emerald-400" size={28} />
          </div>
          <div>
            <h1 className="text-4xl font-black tracking-tight">{agency.name}</h1>
            <p className="text-white/40 mt-1 text-sm">
              Code {agency.agency_code ?? '—'} ·{' '}
              {agency.is_active ? 'Active' : 'Inactive'}
            </p>
            <p className="text-sm text-white/60 mt-3">
              Owner: {owner?.username ?? '—'}
              {owner?.short_id != null ? ` · UID ${owner.short_id}` : ''}
            </p>
            <p className="text-sm text-emerald-300/80 mt-1">
              Sponsor:{' '}
              {sponsor
                ? `${sponsorUser?.username ?? 'Staff'} (${sponsor.staff_code}) · ${sponsor.role}`
                : 'None'}
              {sponsor?.id ? (
                <>
                  {' · '}
                  <Link
                    href={`/staff/${sponsor.id}?period=${periodId}`}
                    className="underline hover:text-emerald-200"
                  >
                    Open chain
                  </Link>
                </>
              ) : null}
            </p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="glass-card !p-4 text-center">
          <Banknote size={16} className="mx-auto text-emerald-400 mb-2" />
          <p className="text-xl font-black tabular-nums text-emerald-400">
            {periodDiamonds.toLocaleString()}
          </p>
          <p className="text-[9px] font-black uppercase tracking-widest text-white/30 mt-1">
            Diamonds
          </p>
        </div>
        <div className="glass-card !p-4 text-center">
          <Banknote size={16} className="mx-auto text-amber-400 mb-2" />
          <p className="text-xl font-black tabular-nums text-amber-400">
            {periodCharm.toLocaleString()}
          </p>
          <p className="text-[9px] font-black uppercase tracking-widest text-white/30 mt-1">
            Charm
          </p>
        </div>
        <div className="glass-card !p-4 text-center">
          <Wallet size={16} className="mx-auto text-emerald-300 mb-2" />
          <p className="text-xl font-black tabular-nums text-emerald-300">
            {formatUsd(hostSalaryUsd)}
          </p>
          <p className="text-[9px] font-black uppercase tracking-widest text-white/30 mt-1">
            Host salary
          </p>
        </div>
        <div className="glass-card !p-4 text-center">
          <Wallet size={16} className="mx-auto text-pink-300 mb-2" />
          <p className="text-xl font-black tabular-nums text-pink-300">
            {formatUsd(agencyEst.totalUsd)}
          </p>
          <p className="text-[9px] font-black uppercase tracking-widest text-white/30 mt-1">
            Agency salary LV{agencyEst.level}
          </p>
        </div>
      </div>

      <AgencyTransferControls
        agencyId={agency.id}
        agencyName={String(agency.name ?? 'Agency')}
        currentSponsorStaffId={agency.sponsor_staff_id ? String(agency.sponsor_staff_id) : null}
        bdOptions={bdOptions}
        otherAgencies={otherAgencies}
        members={memberOptions}
      />

      <div className="glass-card p-8">
        <h2 className="text-xl font-black mb-6">
          Members ({hostRows.length}) · {periodId}
        </h2>
        <div className="space-y-3">
          {hostRows.map((m: any) => (
            <Link
              key={m.id}
              href={`/users/${m.user_id}`}
              className="flex items-center gap-4 p-4 rounded-2xl bg-white/5 border border-white/5 hover:border-white/15 transition"
            >
              <div className="w-10 h-10 rounded-xl bg-purple-500/20 overflow-hidden flex items-center justify-center">
                {m.users?.avatar_url ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={m.users.avatar_url}
                    alt=""
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <User size={18} className="text-purple-400" />
                )}
              </div>
              <div className="min-w-0 flex-1">
                <p className="font-bold truncate">{m.users?.username ?? 'Host'}</p>
                <p className="text-xs text-white/40">
                  UID {m.users?.short_id ?? '—'} · Lvl {m.users?.user_level ?? 0} · {m.role}
                </p>
                <p className="text-xs mt-1 space-x-2">
                  <span className="text-emerald-400 font-bold">
                    {m.periodDiamonds.toLocaleString()} dia
                  </span>
                  <span className="text-amber-400 font-bold">
                    {m.periodCharm.toLocaleString()} charm
                  </span>
                  <span className="text-white/70 font-bold">
                    {formatUsd(m.estimatedUsd)}
                  </span>
                </p>
              </div>
            </Link>
          ))}
          {hostRows.length === 0 && (
            <p className="text-white/40 text-sm py-8 text-center">No members.</p>
          )}
        </div>
      </div>
    </div>
  );
}
