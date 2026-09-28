"use client";
import { useState } from "react";
import { updateVipPlan } from "@/app/settings/vip/actions";
import { Save, Loader2, CheckCircle2 } from "lucide-react";
interface VipEditFormProps {
  plan: any;
}
const FEATURE_LABELS: Record<string, string> = {
  has_vip_title: "VIP Title Display",
  has_exclusive_frame: "Exclusive Avatar Frame",
  has_chat_bubble: "Custom Chat Bubble",
  has_entrance_show: "Entrance Animation",
  has_distinguished_card: "Distinguished Profile Card",
  has_room_priority: "Room Entry Priority",
  has_free_family: "Free Family Creation",
  has_anti_blocking: "Anti-Blocking Shield",
  has_kicking_defence: "Kick Defence",
  has_refuse_strangers: "Refuse Stranger Messages",
};
const FORBIDDEN_FEATURES = [
  "has_rare_vehicle",
  "has_discount",
  "has_mic_emojis",
  "has_privilege_gift",
  "has_special_gift",
  "has_invisibility",
];
export function VipEditForm({ plan }: VipEditFormProps) {
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setLoading(true);
    setSuccess(false);
    const formData = new FormData(e.currentTarget);
    const data: any = {
      name: formData.get("name"),
      price_coins: parseInt(formData.get("price_coins") as string),
      duration_days: parseInt(formData.get("duration_days") as string),
    };
    Object.keys(FEATURE_LABELS).forEach((key) => {
      data[key] = formData.get(key) === "on";
    });
    const res = await updateVipPlan(plan.id, data);
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
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-1 space-y-8">
          <div className="glass-card space-y-6">
            <h3 className="text-sm font-black uppercase tracking-widest text-amber-500">
              Core Configuration
            </h3>

            <div className="space-y-4">
              <div className="space-y-2">
                <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                  Tier Name
                </label>
                <input
                  required
                  name="name"
                  defaultValue={plan.name}
                  className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50 transition-all"
                />
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                  Price (Coins)
                </label>
                <input
                  required
                  type="number"
                  name="price_coins"
                  defaultValue={plan.price_coins}
                  className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50 transition-all"
                />
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-bold uppercase text-white/30 tracking-widest px-1">
                  Duration (Days)
                </label>
                <input
                  required
                  type="number"
                  name="duration_days"
                  defaultValue={plan.duration_days}
                  className="w-full bg-black/40 border border-white/10 rounded-2xl px-5 py-4 focus:outline-none focus:border-amber-500/50 transition-all"
                />
              </div>
            </div>
          </div>

          <button
            disabled={loading}
            className="w-full py-5 bg-amber-500 hover:bg-amber-400 text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 disabled:opacity-50"
          >
            {loading ? (
              <Loader2 size={24} className="animate-spin" />
            ) : success ? (
              <CheckCircle2 size={24} />
            ) : (
              <Save size={24} />
            )}
            {success ? "Changes Saved!" : "Update Plan"}
          </button>
        </div>

        <div className="lg:col-span-2 space-y-8">
          <div className="glass-card">
            <h3 className="text-sm font-black uppercase tracking-widest text-blue-400 mb-8">
              Feature Entitlements
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {Object.entries(FEATURE_LABELS).map(([key, label]) => (
                <div
                  key={key}
                  className="flex items-center justify-between p-4 rounded-2xl bg-white/5 border border-white/5 hover:border-white/10 transition-colors"
                >
                  <span className="text-xs font-bold text-white/80">{label}</span>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      name={key}
                      defaultChecked={plan[key]}
                      className="sr-only peer"
                    />
                    <div className="w-11 h-6 bg-white/10 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white/40 after:border-white/10 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600 peer-checked:after:bg-white peer-checked:after:border-transparent"></div>
                  </label>
                </div>
              ))}
            </div>
          </div>

          <div className="glass-card bg-red-500/5 border-red-500/20">
            <p className="text-[10px] font-black uppercase text-red-400 tracking-widest mb-2">
              Notice
            </p>
            <p className="text-xs text-red-400/60 leading-relaxed">
              Certain features defined in the database (Rare Vehicle, Mic Emojis, etc.) have been
              hidden because they are currently disabled in the Flutter application.
            </p>
          </div>
        </div>
      </div>
    </form>
  );
}
