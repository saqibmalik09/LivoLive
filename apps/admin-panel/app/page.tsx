import { supabaseAdmin } from "@/lib/supabase";
import {
  Users,
  Home,
  Wallet,
  MessageSquare,
  TrendingUp,
  Sparkles,
  Settings,
  Crown,
  Gamepad2,
  ShoppingBag,
  Target,
  Coins,
  Heart,
  Network,
  Banknote,
  Store,
} from "lucide-react";
import Link from "next/link";
async function getStats() {
  const { count: userCount } = await supabaseAdmin
    .from("users")
    .select("*", { count: "exact", head: true });
  const { data: wealthData } = await supabaseAdmin.from("users").select("wealth_value");
  const totalWealth =
    wealthData?.reduce((acc, curr) => acc + (Number(curr.wealth_value) || 0), 0) || 0;
  const tenDaysAgo = new Date();
  tenDaysAgo.setDate(tenDaysAgo.getDate() - 10);
  const { data: growthData } = await supabaseAdmin
    .from("users")
    .select("created_at")
    .gte("created_at", tenDaysAgo.toISOString());
  const growthByDay: Record<string, number> = {};
  for (let i = 0; i < 10; i++) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    growthByDay[d.toISOString().split("T")[0]] = 0;
  }
  growthData?.forEach((u) => {
    const day = u.created_at.split("T")[0];
    if (growthByDay[day] !== undefined) {
      growthByDay[day]++;
    }
  });
  const chartData = Object.entries(growthByDay)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([_, count]) => count);
  return {
    userCount: userCount || 0,
    totalWealth: totalWealth,
    chartData: chartData.length > 0 ? chartData : [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  };
}
export default async function Dashboard() {
  const stats = await getStats();
  const maxGrowth = Math.max(...stats.chartData, 1);
  return (
    <div className="space-y-12">
      <header>
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-purple-400 to-blue-400 tracking-tighter">
          SK Live Dashboard
        </h1>
        <p className="text-white/60 mt-2 font-medium">Real-time system overview and statistics</p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <StatsCard
          title="Total Users"
          value={stats.userCount.toLocaleString()}
          icon={Users}
          trend="Active registered accounts"
          color="from-purple-500/25 to-transparent"
          iconColor="text-purple-400"
        />
        <StatsCard
          title="Wealth Flux"
          value={stats.totalWealth.toLocaleString()}
          icon={Wallet}
          trend="Total circulating wealth"
          color="from-pink-500/25 to-transparent"
          iconColor="text-pink-400"
        />
      </div>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="glass-card">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-xl font-bold flex items-center gap-2">
              <TrendingUp className="text-purple-400" />
              User Registration Growth
            </h3>
            <span className="text-xs font-bold text-purple-400 uppercase tracking-widest px-3 py-1 bg-purple-400/10 rounded-full">
              Real-time
            </span>
          </div>
          <div className="h-64 flex items-end gap-3 px-2">
            {stats.chartData.map((count, i) => (
              <div
                key={i}
                className="flex-1 bg-gradient-to-t from-purple-500/40 to-purple-400 rounded-t-lg transition-all duration-500 hover:to-white relative group"
                style={{ height: `${(count / maxGrowth) * 90 + 10}%` }}
              >
                <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-white text-black text-[10px] font-bold px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity">
                  {count}
                </div>
              </div>
            ))}
          </div>
          <div className="flex justify-between mt-4 text-[10px] font-bold text-white/20 uppercase tracking-tighter">
            <span>10 Days Ago</span>
            <span>Today</span>
          </div>
        </div>

        <div className="glass-card">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-xl font-bold flex items-center gap-2">
              <Sparkles className="text-blue-400" />
              Quick Actions
            </h3>
          </div>
          <div className="grid grid-cols-3 gap-4">
            <ActionButton
              label="Merchants"
              icon={Store}
              href="/merchants"
              color="text-emerald-400"
            />
            <ActionButton
              label="Messages"
              icon={MessageSquare}
              href="/messages"
              color="text-blue-400"
            />
            <ActionButton label="CP Nest" icon={Heart} href="/cp-nest" color="text-pink-400" />
            <ActionButton
              label="Salary Hub"
              icon={Banknote}
              href="/salary-hub"
              color="text-emerald-400"
            />
            <ActionButton
              label="Salary Audit"
              icon={Banknote}
              href="/salary-audit"
              color="text-amber-400"
            />
            <ActionButton label="BD Staff" icon={Network} href="/staff" color="text-amber-400" />
            <ActionButton label="Recharge" icon={Coins} href="/recharge" color="text-amber-400" />
            <ActionButton label="VIP Plans" icon={Crown} href="/vip" color="text-amber-400" />
            <ActionButton label="Targets" icon={Target} href="/targets" color="text-orange-400" />
            <ActionButton
              label="Salary Runs"
              icon={Wallet}
              href="/salary-runs"
              color="text-emerald-400"
            />
            <ActionButton
              label="Wallet Control"
              icon={Wallet}
              href="/settings/wallet"
              color="text-violet-300"
            />
            <ActionButton
              label="Withdrawals"
              icon={Banknote}
              href="/withdrawals"
              color="text-violet-400"
            />
            <ActionButton label="Settings" icon={Settings} href="/settings" color="text-white/60" />
          </div>
        </div>
      </section>
    </div>
  );
}
function StatsCard({ title, value, icon: Icon, trend, color, iconColor }: any) {
  return (
    <div
      className={`glass-card bg-gradient-to-br ${color} hover:border-white/20 hover:shadow-purple-500/10 transition-all cursor-pointer group relative overflow-hidden`}
    >
      <div className="absolute top-0 right-0 w-32 h-32 bg-white/5 blur-3xl -mr-16 -mt-16 rounded-full" />
      <div className="flex items-start justify-between relative z-10">
        <div>
          <p className="text-white/50 text-[10px] font-bold uppercase tracking-[0.2em] mb-2">
            {title}
          </p>
          <h2 className="text-4xl font-black tracking-tight">{value}</h2>
        </div>
        <div
          className={cn(
            "p-4 rounded-2xl bg-black/40 border border-white/5 group-hover:scale-110 transition-transform duration-500",
            iconColor,
          )}
        >
          <Icon size={28} strokeWidth={1.5} />
        </div>
      </div>
      <div className="mt-8 flex items-center gap-2 relative z-10">
        <div className="h-1 w-12 bg-white/10 rounded-full overflow-hidden">
          <div className="h-full bg-current w-2/3" />
        </div>
        <p className="text-[10px] font-bold text-white/40 uppercase tracking-wider">{trend}</p>
      </div>
    </div>
  );
}
function cn(...inputs: any[]) {
  return inputs.filter(Boolean).join(" ");
}
function ActionButton({ label, icon: Icon, color = "text-white", href = "#" }: any) {
  return (
    <Link
      href={href}
      className="glass flex flex-col items-center justify-center p-6 rounded-[2rem] gap-3 hover:bg-white/5 transition-all group border border-white/5 hover:border-white/10 active:scale-95"
    >
      <div
        className={cn("p-3 rounded-xl bg-white/5 group-hover:bg-white/10 transition-colors", color)}
      >
        <Icon size={22} />
      </div>
      <span className="text-[10px] font-bold uppercase tracking-[0.15em] text-white/60 group-hover:text-white transition-colors">
        {label}
      </span>
    </Link>
  );
}
