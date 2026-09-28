import { supabaseAdmin } from "@/lib/supabase";
import {
  ArrowLeft,
  User,
  Building2,
  ShieldCheck,
  Users,
  TrendingUp,
  BarChart3,
  ChevronRight,
  Wallet,
} from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { format } from "date-fns";
import { HostActions } from "./HostActions";
import { AgencyTransferControls } from "./AgencyTransferControls";
import { DeactivateAgencyPanel } from "./DeactivateAgencyPanel";
import { AmountValue } from "@/components/AmountValue";
import { HubPeriodBanner } from "@/components/HubPeriodBanner";
import { withPeriod } from "@/lib/salary-hub/constants";
import { getHubPeriod } from "@/lib/salary-hub/period";
import {
  estimateAgencyUsd,
  estimateHostUsd,
  formatUsd,
  loadSalarySettings,
} from "@/lib/salary-hub/salary-calc";
interface AgencyDetailProps {
  params: Promise<{
    id: string;
  }>;
  searchParams: Promise<{
    period?: string;
  }>;
}
export default async function AgencyDetailPage({ params, searchParams }: AgencyDetailProps) {
  const { id } = await params;
  const sp = await searchParams;
  const periodId = await getHubPeriod(sp.period);
  const { data: agency, error } = await supabaseAdmin
    .from("agencies")
    .select(
      "*, users:owner_id(username, avatar_url, coins, wealth_level), sponsor:business_staff!sponsor_staff_id(id, staff_code, role, users:user_id(username)), approved_by:business_staff!approved_by_staff_id(staff_code, role, users:user_id(username))",
    )
    .eq("id", id)
    .single();
  if (error || !agency) notFound();
  const { data: hostApps } = await supabaseAdmin
    .from("agency_applications")
    .select("*, users(username, avatar_url, coins, wealth_level, user_level, created_at)")
    .eq("agency_id", id)
    .order("created_at", { ascending: false });
  const { data: members } = await supabaseAdmin
    .from("agency_members")
    .select("*, users(username, avatar_url, coins, wealth_level, user_level)")
    .eq("agency_id", id);
  const [{ data: bdRows }, { data: otherAgencyRows }] = await Promise.all([
    supabaseAdmin
      .from("business_staff")
      .select("id, staff_code, user:user_id(username, short_id)")
      .eq("role", "bd")
      .eq("is_active", true)
      .order("created_at", { ascending: false }),
    supabaseAdmin
      .from("agencies")
      .select("id, name, agency_code, is_active")
      .eq("is_active", true)
      .neq("id", id)
      .order("name", { ascending: true }),
  ]);
  const bdOptions = (bdRows ?? []).map((row: any) => {
    const u = Array.isArray(row.user) ? row.user[0] : row.user;
    return {
      id: String(row.id),
      staffCode: String(row.staff_code ?? ""),
      username: u?.username ? String(u.username) : "BD",
      shortId: u?.short_id != null ? String(u.short_id) : null,
    };
  });
  const otherAgencies = (otherAgencyRows ?? []).map((a: any) => ({
    id: String(a.id),
    name: String(a.name ?? "Agency"),
    agencyCode: a.agency_code != null ? String(a.agency_code) : null,
  }));
  const memberOptions = (members ?? []).map((m: any) => ({
    userId: String(m.user_id),
    username: m.users?.username ? String(m.users.username) : "host",
  }));
  const pendingHosts = hostApps?.filter((h) => h.status === "pending") || [];
  const memberIds = members?.map((m) => m.user_id) || [];
  const settings = await loadSalarySettings();
  const { data: periodStats } = memberIds.length
    ? await supabaseAdmin
        .from("host_period_stats")
        .select("*")
        .in("user_id", memberIds)
        .order("period_id", { ascending: false })
    : { data: [] as any[] };
  const agencyPeriodProgress: Record<
    string,
    {
      diamonds: number;
      charm: number;
      hostCharms: number[];
      seconds: number;
      hosts: Set<string>;
      usd: number;
    }
  > = {};
  periodStats?.forEach((stat) => {
    if (!agencyPeriodProgress[stat.period_id]) {
      agencyPeriodProgress[stat.period_id] = {
        diamonds: 0,
        charm: 0,
        hostCharms: [],
        seconds: 0,
        hosts: new Set(),
        usd: 0,
      };
    }
    agencyPeriodProgress[stat.period_id].diamonds += stat.total_diamonds || 0;
    const hostCharm = Number(stat.charm_points || 0);
    agencyPeriodProgress[stat.period_id].charm += hostCharm;
    agencyPeriodProgress[stat.period_id].hostCharms.push(hostCharm);
    agencyPeriodProgress[stat.period_id].seconds += stat.total_on_mic_seconds || 0;
    agencyPeriodProgress[stat.period_id].hosts.add(stat.user_id);
  });
  for (const pid of Object.keys(agencyPeriodProgress)) {
    const est = estimateAgencyUsd(settings, agencyPeriodProgress[pid].hostCharms);
    agencyPeriodProgress[pid].usd = est.totalUsd;
  }
  const selectedAgencyUsd = estimateAgencyUsd(
    settings,
    agencyPeriodProgress[periodId]?.hostCharms || [],
  );
  const sortedPeriods = Object.entries(agencyPeriodProgress)
    .sort(([a], [b]) => b.localeCompare(a))
    .slice(0, 6);
  return (
    <div className="space-y-10 pb-32">
      <Link
        href={withPeriod("/salary-hub?role=agency", periodId)}
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Salary Hub</span>
      </Link>

      <HubPeriodBanner period={periodId} hubHref={`/salary-hub?role=agency&period=${periodId}`} />

      <div className="glass-card p-12 flex flex-col md:flex-row items-center gap-10 border-purple-500/20 bg-gradient-to-br from-purple-500/10 to-transparent relative overflow-hidden">
        <div className="absolute top-0 right-0 p-12 opacity-5">
          <Building2 size={200} />
        </div>
        <div className="w-28 h-28 rounded-3xl bg-purple-500/20 border-2 border-purple-500/30 flex items-center justify-center overflow-hidden relative z-10">
          {agency.logo_url ? (
            <img src={agency.logo_url} className="w-full h-full object-cover" />
          ) : (
            <Building2 size={48} className="text-purple-400" />
          )}
        </div>
        <div className="flex-1 relative z-10">
          <h1 className="text-5xl font-black tracking-tighter italic">{agency.name}</h1>
          <div className="flex items-center gap-6 mt-4 flex-wrap">
            <span className="text-xs text-white/40 flex items-center gap-2">
              <User size={14} /> Owner:{" "}
              <span className="text-purple-400 font-bold">@{agency.users?.username}</span>
            </span>
            <span className="text-xs font-mono text-purple-400/60 bg-purple-500/10 px-3 py-1 rounded-full border border-purple-500/20">
              Code: {agency.agency_code}
            </span>
            <span
              className={`px-4 py-1 rounded-full text-[10px] font-black uppercase tracking-widest border ${agency.is_active ? "bg-emerald-500/20 text-emerald-500 border-emerald-500/20" : "bg-red-500/20 text-red-500 border-red-500/20"}`}
            >
              {agency.is_active ? "Active" : "Inactive"}
            </span>
            {agency.sponsor?.staff_code && (
              <Link
                href={`/staff/${agency.sponsor.id}`}
                className="text-xs text-cyan-400/80 flex items-center gap-2 bg-cyan-500/10 px-3 py-1 rounded-full border border-cyan-500/20 hover:border-cyan-500/40 transition-colors"
              >
                <ShieldCheck size={14} />
                Sponsor BD: {agency.sponsor.role?.replace("_", " ")} · {agency.sponsor.staff_code}
                {agency.sponsor.users?.username ? ` (@${agency.sponsor.users.username})` : ""}
              </Link>
            )}
            {agency.approved_by?.staff_code && (
              <span className="text-xs text-white/40 flex items-center gap-2">
                Approved by: {agency.approved_by.role?.replace("_", " ")}{" "}
                {agency.approved_by.staff_code}
              </span>
            )}
          </div>
        </div>
        <div className="grid grid-cols-2 gap-4 relative z-10">
          <div className="bg-black/30 rounded-2xl p-5 border border-white/5 text-center min-w-[100px]">
            <p className="text-3xl font-black">{members?.length || 0}</p>
            <p className="text-[10px] font-black uppercase tracking-widest text-white/30 mt-1">
              Hosts
            </p>
          </div>
          <div className="bg-black/30 rounded-2xl p-5 border border-white/5 text-center min-w-[100px]">
            <p className="text-3xl font-black text-amber-500">{pendingHosts.length}</p>
            <p className="text-[10px] font-black uppercase tracking-widest text-white/30 mt-1">
              Pending
            </p>
          </div>
        </div>
      </div>

      <AgencyTransferControls
        key={`${id}-${agency.sponsor_staff_id ?? "none"}`}
        agencyId={id}
        agencyName={String(agency.name ?? "Agency")}
        currentSponsorStaffId={agency.sponsor_staff_id ? String(agency.sponsor_staff_id) : null}
        bdOptions={bdOptions}
        otherAgencies={otherAgencies}
        members={memberOptions}
      />

      <DeactivateAgencyPanel
        agencyId={id}
        agencyName={String(agency.name ?? "Agency")}
        agencyCode={String(agency.agency_code ?? "")}
        hostCount={members?.length || 0}
        isActive={agency.is_active !== false}
      />

      <div className="glass-card p-10 space-y-8">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <h3 className="text-xl font-black flex items-center gap-3">
            <TrendingUp className="text-emerald-400" size={24} />
            Period Agency Performance
          </h3>
          <span className="text-[10px] font-black uppercase tracking-widest text-emerald-400/60">
            15-day A/B · {periodId} · Est. {formatUsd(selectedAgencyUsd.totalUsd)} (LV{" "}
            {selectedAgencyUsd.level})
          </span>
        </div>

        {sortedPeriods.length > 0 ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {sortedPeriods.map(([pid, data]) => (
              <div
                key={pid}
                className={`bg-white/5 border rounded-3xl p-6 flex flex-col gap-3 group transition-all min-w-0 overflow-hidden ${pid === periodId ? "border-emerald-500/40" : "border-white/5 hover:border-emerald-500/30"}`}
              >
                <p className="text-[10px] font-black uppercase tracking-widest text-white/20">
                  {pid}
                </p>
                <div className="space-y-1 min-w-0">
                  <AmountValue value={formatUsd(data.usd)} size="lg" className="text-emerald-400" />
                  <p className="text-[10px] font-bold text-white/40 uppercase tracking-tighter">
                    Est. agency USD
                  </p>
                </div>
                <AmountValue value={data.diamonds} size="sm" className="text-white/70" />
                <p className="text-[10px] font-bold text-white/30 uppercase -mt-2">Diamonds</p>
                <AmountValue
                  value={`${data.charm.toLocaleString()} charm`}
                  size="sm"
                  className="text-amber-400/80"
                />
                <div className="h-1 w-full bg-white/5 rounded-full overflow-hidden mt-1">
                  <div
                    className="h-full bg-emerald-500 transition-all duration-1000"
                    style={{ width: `${Math.min((data.diamonds / 100000) * 100, 100)}%` }}
                  />
                </div>
                <div className="flex justify-between items-center gap-2 text-[10px] font-bold text-white/20 uppercase">
                  <span className="shrink-0">{data.hosts.size} Hosts</span>
                  <span className="shrink-0">{Math.floor(data.seconds / 3600)}h Live</span>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="py-20 text-center space-y-4 bg-white/5 rounded-3xl border border-dashed border-white/10">
            <BarChart3 className="mx-auto text-white/10" size={48} />
            <p className="text-white/40 font-medium">No 15-day period data for this agency yet.</p>
          </div>
        )}
      </div>

      {pendingHosts.length > 0 && (
        <div className="glass-card p-10 space-y-6 border-amber-500/20 bg-amber-500/5">
          <h3 className="text-lg font-black flex items-center gap-3 uppercase tracking-tight">
            <ShieldCheck className="text-amber-500" size={22} />
            Pending Host Requests
            <span className="text-[10px] font-black bg-amber-500 text-black px-3 py-1 rounded-full">
              {pendingHosts.length}
            </span>
          </h3>
          <div className="space-y-4">
            {pendingHosts.map((host) => (
              <div
                key={host.id}
                className="p-6 bg-black/30 border border-white/5 rounded-2xl flex items-center justify-between"
              >
                <div className="flex items-center gap-5">
                  <div className="w-12 h-12 rounded-full bg-white/5 overflow-hidden border border-white/10">
                    {host.users?.avatar_url ? (
                      <img src={host.users.avatar_url} className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-amber-400">
                        <User size={20} />
                      </div>
                    )}
                  </div>
                  <div>
                    <h4 className="font-bold text-lg">@{host.users?.username}</h4>
                    <div className="flex items-center gap-3 mt-1">
                      <span className="text-[10px] font-black uppercase tracking-widest text-white/20">
                        Lv.{host.users?.user_level}
                      </span>
                      <span className="text-white/10">•</span>
                      <span className="text-[10px] text-amber-500/60 font-bold">
                        {format(new Date(host.created_at), "MMM dd, yyyy")}
                      </span>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <div className="text-right hidden md:block">
                    <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                      Coins
                    </p>
                    <p className="text-sm font-bold text-amber-500">
                      {host.users?.coins?.toLocaleString()}
                    </p>
                  </div>
                  <HostActions id={host.id} />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="glass-card p-10 space-y-6 border-blue-500/20 bg-blue-500/5">
        <h3 className="text-lg font-black flex items-center gap-3 uppercase tracking-tight">
          <Wallet className="text-blue-400" size={22} />
          Agency Payment Details
        </h3>
        {agency.payment_details && agency.payment_details.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {agency.payment_details.map((p: any, idx: number) => (
              <div
                key={idx}
                className="p-6 bg-black/30 border border-white/5 rounded-2xl flex items-start gap-4"
              >
                <div className="w-12 h-12 rounded-xl bg-blue-500/10 flex items-center justify-center shrink-0">
                  <Wallet className="text-blue-400" size={24} />
                </div>
                <div className="space-y-1">
                  <p className="text-[10px] font-black uppercase tracking-widest text-blue-400/60">
                    {p.method}
                  </p>
                  <p className="text-lg font-black tracking-tight">{p.name}</p>
                  <p className="text-sm font-mono text-white/40 break-all">{p.address}</p>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="py-12 text-center space-y-3 bg-white/5 rounded-2xl border border-dashed border-white/10">
            <Wallet className="mx-auto text-white/10" size={36} />
            <p className="text-white/30 text-sm font-medium">
              No payment methods added by this agency.
            </p>
          </div>
        )}
      </div>

      <div className="glass-card p-10 space-y-6">
        <h3 className="text-lg font-black flex items-center gap-3 uppercase tracking-tight">
          <Users className="text-purple-400" size={22} />
          Agency Members & Progress
          <span className="text-[10px] font-black bg-white/10 text-white/60 px-3 py-1 rounded-full">
            {members?.length || 0}
          </span>
        </h3>
        {members && members.length > 0 ? (
          <div className="space-y-3">
            {members.map((member) => {
              const hostStats = periodStats?.find(
                (s) => s.user_id === member.user_id && s.period_id === periodId,
              );
              const hostUsd = hostStats ? estimateHostUsd(settings, hostStats) : null;
              return (
                <Link
                  key={member.id}
                  href={withPeriod(`/agencies/${id}/hosts/${member.user_id}`, periodId)}
                  className="p-5 bg-white/5 border border-white/5 rounded-3xl flex items-center justify-between hover:border-purple-500/40 transition-all group"
                >
                  <div className="flex items-center gap-4 min-w-0">
                    <div className="w-12 h-12 rounded-2xl bg-white/5 overflow-hidden border border-white/10 shrink-0">
                      {member.users?.avatar_url ? (
                        <img src={member.users.avatar_url} className="w-full h-full object-cover" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-purple-400">
                          <User size={18} />
                        </div>
                      )}
                    </div>
                    <div className="min-w-0">
                      <h4 className="font-bold group-hover:text-purple-400 transition-colors text-lg">
                        @{member.users?.username}
                      </h4>
                      <div className="flex items-center gap-2 mt-1 flex-wrap">
                        <span className="text-[10px] text-white/20 font-black uppercase tracking-widest">
                          Lv.{member.users?.user_level} Host
                        </span>
                        {hostUsd && (
                          <>
                            <span className="text-white/10">•</span>
                            <span className="text-[10px] text-emerald-500 font-bold uppercase tracking-widest flex items-center gap-1 min-w-0">
                              <TrendingUp size={10} className="shrink-0" />
                              <span className="tabular-nums break-all">
                                {formatUsd(hostUsd.hostTierUsd)} host ·{" "}
                                {formatUsd(hostUsd.charmSalaryUsd)} charm · {periodId}
                              </span>
                            </span>
                          </>
                        )}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-10 shrink-0">
                    {hostStats && (
                      <div className="hidden lg:flex items-center gap-6">
                        <div className="text-right">
                          <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                            Diamonds
                          </p>
                          <p className="text-sm font-bold text-emerald-400 tabular-nums">
                            {(hostStats.total_diamonds || 0).toLocaleString()}
                          </p>
                        </div>
                        <div className="text-right">
                          <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                            Live Time
                          </p>
                          <p className="text-sm font-bold text-blue-400">
                            {Math.floor((hostStats.total_on_mic_seconds || 0) / 3600)}h{" "}
                            {Math.floor(((hostStats.total_on_mic_seconds || 0) % 3600) / 60)}m
                          </p>
                        </div>
                        <div className="text-right">
                          <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                            Valid Days
                          </p>
                          <p className="text-sm font-bold text-purple-400">
                            {hostStats.valid_days || 0}/15
                          </p>
                        </div>
                      </div>
                    )}
                    <div className="flex items-center gap-3">
                      <span className="text-[10px] font-black uppercase tracking-widest text-white/20 group-hover:text-white transition-colors">
                        Details
                      </span>
                      <ChevronRight
                        className="text-white/10 group-hover:text-white transition-colors"
                        size={18}
                      />
                    </div>
                  </div>
                </Link>
              );
            })}
          </div>
        ) : (
          <div className="py-12 text-center space-y-3 bg-white/5 rounded-2xl border border-dashed border-white/10">
            <Users className="mx-auto text-white/10" size={36} />
            <p className="text-white/30 text-sm font-medium">No hosts in this agency yet.</p>
          </div>
        )}
      </div>
    </div>
  );
}
