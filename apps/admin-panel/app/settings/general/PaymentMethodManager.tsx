"use client";
import { useState } from "react";
import { Plus, Trash2, Wallet, Save, Loader2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { updateSystemSetting } from "./actions";
interface PaymentMethodManagerProps {
  initialMethods: string[];
}
export function PaymentMethodManager({ initialMethods }: PaymentMethodManagerProps) {
  const router = useRouter();
  const [methods, setMethods] = useState<string[]>(initialMethods);
  const [newMethod, setNewMethod] = useState("");
  const [loading, setLoading] = useState(false);
  async function handleSave() {
    setLoading(true);
    const res = await updateSystemSetting("payment_methods", JSON.stringify(methods));
    if (res.success) {
      router.refresh();
      alert("Payment methods updated!");
    } else {
      alert("Error: " + res.error);
    }
    setLoading(false);
  }
  const addMethod = () => {
    if (!newMethod.trim()) return;
    if (methods.includes(newMethod.trim())) return;
    setMethods([...methods, newMethod.trim()]);
    setNewMethod("");
  };
  const removeMethod = (name: string) => {
    setMethods(methods.filter((m) => m !== name));
  };
  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3 px-2">
        <Wallet size={20} className="text-emerald-400" />
        <h2 className="text-sm font-black uppercase tracking-widest text-white/80">
          Payment Methods Configuration
        </h2>
      </div>

      <div className="glass-card p-10 space-y-8">
        <div className="flex gap-4">
          <input
            type="text"
            value={newMethod}
            onChange={(e) => setNewMethod(e.target.value)}
            placeholder="Method Name (e.g. Binance)"
            className="flex-1 bg-white/5 border border-white/10 rounded-2xl p-4 text-sm font-bold outline-none focus:border-emerald-500 transition-all"
          />
          <button
            onClick={addMethod}
            className="px-8 bg-emerald-500 hover:bg-emerald-400 text-black font-black rounded-2xl transition-all flex items-center gap-2 text-xs uppercase tracking-widest"
          >
            <Plus size={18} />
            Add
          </button>
        </div>

        <div className="flex flex-wrap gap-3">
          {methods.map((method) => (
            <div
              key={method}
              className="flex items-center gap-3 bg-white/5 border border-white/10 px-6 py-3 rounded-2xl group"
            >
              <span className="font-bold text-sm">{method}</span>
              <button
                onClick={() => removeMethod(method)}
                className="text-white/20 hover:text-red-500 transition-colors"
              >
                <Trash2 size={16} />
              </button>
            </div>
          ))}
        </div>

        <div className="pt-6 border-t border-white/5">
          <button
            onClick={handleSave}
            disabled={loading}
            className="w-full py-5 bg-white text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 active:scale-95 disabled:opacity-50"
          >
            {loading ? <Loader2 className="animate-spin" /> : <Save size={18} />}
            Update Available Methods
          </button>
        </div>
      </div>
    </div>
  );
}
