import { supabaseAdmin } from "@/lib/supabase";
import { ArrowLeft, User, BarChart3, Clock, Calendar, Zap } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { AmountValue } from "@/components/AmountValue";
import { HubPeriodBanner } from "@/components/HubPeriodBanner";
import { withPeriod } from "@/lib/salary-hub/constants";
import { getHubPeriod } from "@/lib/salary-hub/period";
import { estimateHostUsd, formatUsd, loadSalarySettings } from "@/lib/salary-hub/salary-calc";
interface HostDetailPageProps {
  params: Promise<{
    id: string;
    hostId: string;
  }>;
  searchParams: Promise<{
    period?: string;
  }>;
}
export default async function HostDetailPage({ params, searchParams }: HostDetailPageProps) {
  const { id: agencyId, hostId } = await params;
  const sp = await searchParams;
  const periodId = await getHubPeriod(sp.period);
  const settings = await loadSalarySettings();
  const { data: host, error: hostError } = await supabaseAdmin
    .from("users")
    .select("*")
    .eq("id", hostId)
    .single();
  if (hostError || !host) notFound();
  const { data: agency } = await supabaseAdmin
    .from("agencies")
    .select("name")
    .eq("id", agencyId)
    .single();
  const { data: periodStats } = await supabaseAdmin
    .from("host_period_stats")
    .select("*")
    .eq("user_id", hostId)
    .order("period_id", { ascending: false });
  const currentStats = periodStats?.find((s) => s.period_id === periodId);
  const currentUsd = estimateHostUsd(settings, currentStats || null);
  const totalDiamonds =
    periodStats?.reduce((acc, curr) => acc + (curr.total_diamonds || 0), 0) || 0;
  const totalHours = Math.floor(
    (periodStats?.reduce((acc, curr) => acc + (curr.total_on_mic_seconds || 0), 0) || 0) / 3600,
  );
  return (
    <div className="space-y-10 pb-32">
      <Link
        href={withPeriod(`/agencies/${agencyId}`, periodId)}
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">
          Back to {agency?.name || "Agency"}
        </span>
      </Link>

      <HubPeriodBanner period={periodId} hubHref={`/salary-hub?role=host&period=${periodId}`} />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-12">
        <div className="lg:col-span-1 space-y-8">
          <div className="glass-card p-10 text-center relative overflow-hidden">
            <div className="absolute top-0 left-0 w-full h-24 bg-gradient-to-b from-purple-500/20 to-transparent" />
            <div className="w-32 h-32 rounded-full border-4 border-purple-500/30 p-1 mx-auto mb-6 relative z-10">
              <div className="w-full h-full rounded-full overflow-hidden bg-white/5 border border-white/10">
                {host.avatar_url ? (
                  <img src={host.avatar_url} className="w-full h-full object-cover" alt="" />
                ) : (
                  <div className="w-full h-full flex items-center justify-center text-purple-400">
                    <User size={48} />
                  </div>
                )}
              </div>
            </div>

            <h2 className="text-3xl font-black tracking-tight relative z-10">@{host.username}</h2>
            <div className="flex items-center justify-center gap-2 mt-2 relative z-10">
              <span className="px-3 py-1 bg-purple-500/10 text-purple-400 text-[10px] font-black uppercase tracking-widest rounded-full border border-purple-500/20">
                Host Level {host.user_level}
              </span>
            </div>

            <div className="grid grid-cols-2 gap-4 mt-10 relative z-10">
              <div className="bg-white/5 rounded-2xl p-4 border border-white/5 min-w-0 overflow-hidden">
                <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                  Period Diamonds
                </p>
                <AmountValue value={totalDiamonds} size="sm" className="text-emerald-500" />
              </div>
              <div className="bg-white/5 rounded-2xl p-4 border border-white/5 min-w-0 overflow-hidden">
                <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                  Total Hours
                </p>
                <p className="font-bold text-blue-500 tabular-nums">{totalHours}h</p>
              </div>
            </div>
          </div>

          <div className="glass-card p-10 space-y-6">
            <h3 className="text-xs font-black uppercase tracking-[0.3em] text-white/20 border-b border-white/5 pb-4">
              Host Stats
            </h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <p className="text-xs text-white/40 font-bold uppercase tracking-widest">
                  Charm Value
                </p>
                <p className="text-sm font-black">{host.charm_value?.toLocaleString() || 0}</p>
              </div>
              <div className="flex items-center justify-between">
                <p className="text-xs text-white/40 font-bold uppercase tracking-widest">
                  Wealth Value
                </p>
                <p className="text-sm font-black">{host.wealth_value?.toLocaleString() || 0}</p>
              </div>
              <div className="flex items-center justify-between">
                <p className="text-xs text-white/40 font-bold uppercase tracking-widest">
                  Followers
                </p>
                <p className="text-sm font-black">{host.followers_count || 0}</p>
              </div>
              <div className="flex items-center justify-between">
                <p className="text-xs text-white/40 font-bold uppercase tracking-widest">
                  Following
                </p>
                <p className="text-sm font-black">{host.following_count || 0}</p>
              </div>
            </div>
          </div>
        </div>

        <div className="lg:col-span-2 space-y-8">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="glass-card p-8 bg-gradient-to-br from-emerald-500/10 to-transparent border-emerald-500/20 min-w-0 overflow-hidden">
              <div className="flex items-center justify-between mb-4 gap-2">
                <Zap className="text-emerald-500 shrink-0" size={24} />
                <span className="text-[10px] font-black uppercase tracking-widest text-emerald-500/60 truncate">
                  Host salary
                </span>
              </div>
              <AmountValue
                value={formatUsd(currentUsd.hostTierUsd)}
                size="xl"
                className="text-emerald-300"
              />
              <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mt-2">
                {currentUsd.hostTierName || "No tier met"} · Targets settings
              </p>
            </div>
            <div className="glass-card p-8 bg-gradient-to-br from-amber-500/10 to-transparent border-amber-500/20 min-w-0 overflow-hidden">
              <div className="flex items-center justify-between mb-4 gap-2">
                <Zap className="text-amber-400 shrink-0" size={24} />
                <span className="text-[10px] font-black uppercase tracking-widest text-amber-400/60">
                  Charm salary
                </span>
              </div>
              <AmountValue
                value={formatUsd(currentUsd.charmSalaryUsd)}
                size="xl"
                className="text-amber-300"
              />
              <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mt-2">
                Agency LV {currentUsd.charmLevel} · BD center levels
              </p>
            </div>
            <div className="glass-card p-8 bg-gradient-to-br from-blue-500/10 to-transparent border-blue-500/20 min-w-0 overflow-hidden">
              <div className="flex items-center justify-between mb-4 gap-2">
                <Clock className="text-blue-500 shrink-0" size={24} />
                <span className="text-[10px] font-black uppercase tracking-widest text-blue-500/60">
                  {periodId}
                </span>
              </div>
              <AmountValue
                value={currentStats?.total_diamonds || 0}
                size="xl"
                className="text-white"
              />
              <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mt-2">
                Diamonds · 15-day
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="glass-card p-8 bg-gradient-to-br from-blue-500/10 to-transparent border-blue-500/20 min-w-0 overflow-hidden">
              <div className="flex items-center justify-between mb-4 gap-2">
                <Clock className="text-blue-500 shrink-0" size={24} />
                <span className="text-[10px] font-black uppercase tracking-widest text-blue-500/60">
                  Live Duration
                </span>
              </div>
              <AmountValue
                value={`${Math.floor((currentStats?.total_on_mic_seconds || 0) / 3600)}h ${Math.floor(((currentStats?.total_on_mic_seconds || 0) % 3600) / 60)}m`}
                size="xl"
                className="text-white"
              />
              <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mt-2">
                Time on Seat
              </p>
            </div>
            <div className="glass-card p-8 bg-gradient-to-br from-purple-500/10 to-transparent border-purple-500/20 min-w-0 overflow-hidden">
              <div className="flex items-center justify-between mb-4 gap-2">
                <Calendar className="text-purple-500 shrink-0" size={24} />
                <span className="text-[10px] font-black uppercase tracking-widest text-purple-500/60">
                  Valid Days
                </span>
              </div>
              <p className="text-4xl font-black tracking-tighter tabular-nums">
                {currentStats?.valid_days || 0}
                <span className="text-xl text-white/20">/15</span>
              </p>
              <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mt-2">
                Activity · period
              </p>
            </div>
          </div>

          <div className="glass-card p-10 space-y-8">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-black flex items-center gap-3">
                <BarChart3 className="text-white/40" size={24} />
                Period History (15-day A/B)
              </h3>
            </div>

            {periodStats && periodStats.length > 0 ? (
              <div className="space-y-4">
                <div className="grid grid-cols-2 sm:grid-cols-6 gap-3 sm:gap-4 px-6 text-[10px] font-black uppercase tracking-widest text-white/20">
                  <span>Period</span>
                  <span className="text-right">Host $</span>
                  <span className="text-right">Charm $</span>
                  <span className="text-right">Diamonds</span>
                  <span className="text-right">Live Time</span>
                  <span className="text-right">Valid Days</span>
                </div>
                {periodStats.map((stat) => {
                  const usd = estimateHostUsd(settings, stat);
                  return (
                    <div
                      key={stat.period_id}
                      className={`grid grid-cols-2 sm:grid-cols-6 gap-3 sm:gap-4 p-4 sm:p-6 bg-white/5 border rounded-2xl items-start sm:items-center transition-all min-w-0 ${
                        stat.period_id === periodId
                          ? "border-emerald-500/30"
                          : "border-white/5 hover:border-white/10"
                      }`}
                    >
                      <span className="font-bold text-sm">{stat.period_id}</span>
                      <span className="text-right font-black text-emerald-400 tabular-nums break-all min-w-0">
                        {formatUsd(usd.hostTierUsd)}
                      </span>
                      <span className="text-right font-bold text-amber-400/80 text-sm tabular-nums break-all min-w-0">
                        {formatUsd(usd.charmSalaryUsd)}
                      </span>
                      <span className="text-right font-black text-white/70 tabular-nums break-all min-w-0">
                        {stat.total_diamonds?.toLocaleString()}
                      </span>
                      <span className="text-right font-bold text-white/60 text-xs">
                        {Math.floor((stat.total_on_mic_seconds || 0) / 3600)}h{" "}
                        {Math.floor(((stat.total_on_mic_seconds || 0) % 3600) / 60)}m
                      </span>
                      <span className="text-right font-black text-purple-400">
                        {stat.valid_days || 0}/15
                      </span>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="py-20 text-center space-y-4 bg-white/5 rounded-3xl border border-dashed border-white/10">
                <BarChart3 className="mx-auto text-white/10" size={48} />
                <p className="text-white/40 font-medium">
                  No 15-day period data for this host yet.
                </p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
