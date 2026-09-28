import { supabaseAdmin } from "@/lib/supabase";
import { Crown, ChevronRight, ArrowLeft } from "lucide-react";
import Link from "next/link";
export default async function VipListPage() {
  const { data: plans } = await supabaseAdmin
    .from("vip_plans")
    .select("*")
    .order("level", { ascending: true });
  return (
    <div className="space-y-12 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Settings</span>
      </Link>

      <header>
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-amber-400 to-yellow-400 tracking-tighter">
          VIP Tiers
        </h1>
        <p className="text-white/60 mt-2 font-medium">
          Manage naming, pricing, and benefits for each VIP level
        </p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        {plans?.map((plan) => (
          <Link key={plan.id} href={`/settings/vip/${plan.id}`}>
            <div className="glass-card hover:border-amber-500/50 transition-all group cursor-pointer relative overflow-hidden">
              <div className="absolute top-0 right-0 p-6 opacity-10 group-hover:opacity-20 transition-opacity">
                <Crown size={80} />
              </div>

              <div className="flex items-center justify-between mb-8">
                <span className="text-[10px] font-black uppercase tracking-[0.3em] text-amber-500 bg-amber-500/10 px-3 py-1 rounded-full border border-amber-500/20">
                  Level {plan.level}
                </span>
                <ChevronRight
                  size={18}
                  className="text-white/20 group-hover:text-white group-hover:translate-x-1 transition-all"
                />
              </div>

              <h3 className="text-3xl font-black tracking-tight mb-2">{plan.name}</h3>

              <div className="flex items-end justify-between mt-8">
                <div>
                  <p className="text-[10px] font-bold text-white/30 uppercase tracking-widest mb-1">
                    Price (Coins)
                  </p>
                  <p className="text-2xl font-black text-amber-400 tracking-tighter">
                    {plan.price_coins.toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-[10px] font-bold text-white/30 uppercase tracking-widest mb-1">
                    Duration
                  </p>
                  <p className="text-sm font-bold text-white/60">{plan.duration_days} Days</p>
                </div>
              </div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
