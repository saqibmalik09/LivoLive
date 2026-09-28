"use client";
import { useState } from "react";
import { updateCustomBackgroundPrice } from "@/app/settings/room-decorations/actions";
import { Save, Loader2, CheckCircle2, Coins } from "lucide-react";
export function CustomBackgroundPriceForm({ initialPrice }: { initialPrice: number }) {
  const [price, setPrice] = useState(String(initialPrice));
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  async function handleSave() {
    setLoading(true);
    setSuccess(false);
    const res = await updateCustomBackgroundPrice(parseInt(price, 10) || 0);
    if (res.success) {
      setSuccess(true);
      setTimeout(() => setSuccess(false), 2000);
    } else {
      alert("Error: " + res.error);
    }
    setLoading(false);
  }
  return (
    <div className="glass-card p-8 flex flex-col md:flex-row md:items-center justify-between gap-6">
      <div className="space-y-2">
        <div className="flex items-center gap-2 text-indigo-400">
          <Coins size={20} />
          <h3 className="text-lg font-black">Custom user background price</h3>
        </div>
        <p className="text-sm text-white/40 max-w-lg">
          Coins deducted when a host uploads their own photo or SVGA as room background in the app.
          Set to 0 for free.
        </p>
      </div>
      <div className="flex items-center gap-3">
        <input
          type="number"
          min={0}
          value={price}
          onChange={(e) => setPrice(e.target.value)}
          className="bg-black/40 border border-white/10 rounded-xl px-4 py-3 text-sm font-mono w-32"
        />
        <span className="text-xs text-white/40 font-bold uppercase">coins</span>
        <button
          type="button"
          onClick={handleSave}
          disabled={loading}
          className="p-3 rounded-xl bg-white/5 border border-white/10 hover:bg-indigo-500 hover:text-black transition-all disabled:opacity-30"
        >
          {loading ? (
            <Loader2 size={18} className="animate-spin" />
          ) : success ? (
            <CheckCircle2 size={18} className="text-emerald-400" />
          ) : (
            <Save size={18} />
          )}
        </button>
      </div>
    </div>
  );
}
