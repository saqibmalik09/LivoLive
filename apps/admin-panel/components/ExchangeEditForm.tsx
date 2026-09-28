"use client";
import { useState } from "react";
import { updateExchangeConfig } from "@/app/settings/exchange/actions";
import { Save, Loader2, CheckCircle2, ArrowRightLeft } from "lucide-react";
interface ExchangeEditFormProps {
  config: any;
}
export function ExchangeEditForm({ config }: ExchangeEditFormProps) {
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setSuccess(false);
    const formData = new FormData(e.currentTarget);
    const data = {
      rate: parseFloat(formData.get("rate") as string),
      min_amount: parseInt(formData.get("min_amount") as string),
      is_active: formData.get("is_active") === "on",
    };
    const res = await updateExchangeConfig(config.id, data);
    if (res.success) {
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } else {
      alert("Error: " + res.error);
    }
    setLoading(false);
  }
  return (
    <form onSubmit={handleSubmit} className="space-y-12">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-12">
        <div className="lg:col-span-1 space-y-8">
          <div className="glass-card bg-emerald-500/5 border-emerald-500/20 text-center py-12">
            <div className="flex items-center justify-center gap-6 mb-8">
              <div
                className={`w-16 h-16 rounded-2xl flex items-center justify-center border border-white/10 ${config.from_currency === "diamonds" ? "bg-purple-500/20 text-purple-400" : "bg-amber-500/20 text-amber-400"}`}
              >
                <span className="font-black">1</span>
              </div>
              <ArrowRightLeft className="text-white/20" />
              <div
                className={`w-16 h-16 rounded-2xl flex items-center justify-center border border-white/10 ${config.to_currency === "diamonds" ? "bg-purple-500/20 text-purple-400" : "bg-amber-500/20 text-amber-400"}`}
              >
                <span className="font-black text-2xl">?</span>
              </div>
            </div>
            <h4 className="text-sm font-black uppercase tracking-widest opacity-40">
              Conversion logic
            </h4>
          </div>

          <button
            disabled={loading}
            className="w-full py-5 bg-emerald-500 hover:bg-emerald-400 text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 disabled:opacity-50"
          >
            {loading ? (
              <Loader2 size={24} className="animate-spin" />
            ) : success ? (
              <CheckCircle2 size={24} />
            ) : (
              <Save size={24} />
            )}
            {success ? "Rate Updated!" : "Save Exchange Rate"}
          </button>
        </div>

        <div className="lg:col-span-2 space-y-8">
          <div className="glass-card space-y-8">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div className="space-y-2">
                <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                  Multiplier Rate
                </label>
                <input
                  required
                  type="number"
                  step="0.0001"
                  name="rate"
                  defaultValue={config.rate}
                  className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-emerald-500/50 transition-all font-mono text-xl"
                />
                <p className="text-[10px] text-white/20 px-1 mt-1 italic">
                  Example: 0.5 means 100 Diamonds = 50 Beans
                </p>
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                  Minimum Transaction
                </label>
                <input
                  required
                  type="number"
                  name="min_amount"
                  defaultValue={config.min_amount}
                  className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-emerald-500/50 transition-all font-mono text-xl"
                />
              </div>
            </div>

            <div className="flex items-center justify-between p-6 rounded-2xl bg-white/5 border border-white/5">
              <div className="space-y-1">
                <h4 className="text-sm font-bold">Enabled for users</h4>
                <p className="text-xs text-white/30">
                  If disabled, this conversion pair will disappear from the wallet.
                </p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  name="is_active"
                  defaultChecked={config.is_active}
                  className="sr-only peer"
                />
                <div className="w-14 h-7 bg-white/10 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white/40 after:border-white/10 after:border after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:bg-emerald-600 peer-checked:after:bg-white peer-checked:after:border-transparent"></div>
              </label>
            </div>
          </div>
        </div>
      </div>
    </form>
  );
}
