import { supabaseAdmin } from "@/lib/supabase";
import { ArrowLeft, ArrowRightLeft, Settings2 } from "lucide-react";
import Link from "next/link";
export default async function ExchangePage() {
  const { data: configs } = await supabaseAdmin
    .from("exchange_configs")
    .select("*")
    .order("from_currency", { ascending: true });
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
        <h1 className="text-5xl font-black bg-clip-text text-transparent bg-gradient-to-r from-emerald-400 to-teal-400 tracking-tighter">
          Exchange Rates
        </h1>
        <p className="text-white/60 mt-2 font-medium">
          Configure conversion math for in-app currencies
        </p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {configs?.map((config) => (
          <div
            key={config.id}
            className="glass-card hover:border-emerald-500/30 transition-all relative group overflow-hidden"
          >
            <div className="absolute top-0 right-0 p-8 opacity-5 group-hover:opacity-10 transition-opacity">
              <ArrowRightLeft size={100} />
            </div>

            <div className="flex items-center gap-4 mb-8">
              <div className="bg-emerald-500/10 p-3 rounded-xl border border-emerald-500/20 text-emerald-400">
                <ArrowRightLeft size={24} />
              </div>
              <div className="flex items-center gap-3 font-black text-xl uppercase tracking-tighter">
                <span
                  className={
                    config.from_currency === "diamonds" ? "text-purple-400" : "text-amber-400"
                  }
                >
                  {config.from_currency}
                </span>
                <span className="text-white/20">to</span>
                <span
                  className={
                    config.to_currency === "diamonds" ? "text-purple-400" : "text-amber-400"
                  }
                >
                  {config.to_currency}
                </span>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-8">
              <div>
                <p className="text-[10px] font-bold text-white/30 uppercase tracking-widest mb-1">
                  Exchange Rate
                </p>
                <p className="text-3xl font-black tracking-tight text-white/90">
                  1 : {config.rate}
                </p>
              </div>
              <div>
                <p className="text-[10px] font-bold text-white/30 uppercase tracking-widest mb-1">
                  Min. Amount
                </p>
                <p className="text-3xl font-black tracking-tight text-white/90">
                  {config.min_amount.toLocaleString()}
                </p>
              </div>
            </div>

            <div className="mt-8 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div
                  className={`w-2 h-2 rounded-full ${config.is_active ? "bg-emerald-500 animate-pulse" : "bg-red-500"}`}
                />
                <span className="text-[10px] font-black uppercase tracking-widest text-white/40">
                  {config.is_active ? "Active" : "Disabled"}
                </span>
              </div>
              <Link
                href={`/settings/exchange/${config.id}`}
                className="flex items-center gap-2 bg-white/5 border border-white/10 px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest hover:bg-emerald-500 hover:text-black hover:border-transparent transition-all"
              >
                Edit Rate <Settings2 size={12} />
              </Link>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
