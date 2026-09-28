"use client";
import { useState } from "react";
import { Check, X, Loader2, Target, Percent, Plus, Trash2, Save, RotateCcw } from "lucide-react";
import { useRouter } from "next/navigation";
import {
  updateCommission,
  addSalaryTier,
  deleteSalaryTier,
  updateSalaryTier,
  updateSalaryChainConfig,
  resetAllPeriodTargets,
  resetUserPeriodTargets,
} from "./actions";
interface TargetManagementProps {
  commission: any;
  salaryTiers: any[];
  salaryChain: any;
}
export function TargetManagement({ commission, salaryTiers, salaryChain }: TargetManagementProps) {
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<"tiers" | "commission" | "salaryChain" | "reset">(
    "tiers",
  );
  const [loading, setLoading] = useState(false);
  const [userQuery, setUserQuery] = useState("");
  const [resetMessage, setResetMessage] = useState<string | null>(null);
  const [chainData, setChainData] = useState(
    salaryChain || {
      agency_salary_pc: 10,
      bd_salary_pc: 5,
      bd_admin_salary_pc: 3,
      super_bd_salary_pc: 2,
      min_valid_day_seconds: 7200,
      on_mic_only: true,
      diamonds_per_dollar: 1000,
    },
  );
  const [commData, setCommData] = useState(
    commission || {
      host_pc: 40,
      agency_pc: 10,
      bd_pc: 5,
      bd_admin_pc: 3,
      super_bd_pc: 2,
      official_pc: 40,
      admin_pc: 40,
    },
  );
  const commissionSum =
    (commData.host_pc || 0) +
    (commData.agency_pc || 0) +
    (commData.bd_pc || 0) +
    (commData.bd_admin_pc || 0) +
    (commData.super_bd_pc || 0) +
    (commData.official_pc ?? commData.admin_pc ?? 0);
  const commissionFields = [
    { key: "host_pc", label: "Host Share (%)" },
    { key: "agency_pc", label: "Agency Share (%)" },
    { key: "bd_pc", label: "BD Share (%)" },
    { key: "bd_admin_pc", label: "BD Admin Share (%)" },
    { key: "super_bd_pc", label: "Super BD Share (%)" },
    { key: "official_pc", label: "Official / Platform Share (%)" },
  ] as const;
  async function handleUpdateCommission() {
    if (commissionSum !== 100) {
      alert(`Percentages must sum to 100 (current: ${commissionSum})`);
      return;
    }
    setLoading(true);
    const res = await updateCommission(commData);
    if (res.success) {
      router.refresh();
      alert("Commission updated successfully!");
    } else {
      alert(res.error);
    }
    setLoading(false);
  }
  async function handleDeleteTier(id: string) {
    if (!confirm("Are you sure you want to delete this tier?")) return;
    setLoading(true);
    const res = await deleteSalaryTier(id);
    if (res.success) router.refresh();
    else alert(res.error);
    setLoading(false);
  }
  async function handleUpdateSalaryChain() {
    setLoading(true);
    const res = await updateSalaryChainConfig(chainData);
    if (res.success) {
      router.refresh();
      alert("Salary chain settings saved!");
    } else {
      alert(res.error);
    }
    setLoading(false);
  }
  return (
    <div className="space-y-8">
      <div className="flex gap-4 bg-white/5 p-2 rounded-2xl w-fit border border-white/5">
        <button
          onClick={() => setActiveTab("tiers")}
          className={`px-8 py-3 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${activeTab === "tiers" ? "bg-purple-500 text-black shadow-lg shadow-purple-500/20" : "text-white/40 hover:text-white"}`}
        >
          Salary Tiers
        </button>
        <button
          onClick={() => setActiveTab("commission")}
          className={`px-8 py-3 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${activeTab === "commission" ? "bg-purple-500 text-black shadow-lg shadow-purple-500/20" : "text-white/40 hover:text-white"}`}
        >
          Commission Setup
        </button>
        <button
          onClick={() => setActiveTab("salaryChain")}
          className={`px-8 py-3 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${activeTab === "salaryChain" ? "bg-purple-500 text-black shadow-lg shadow-purple-500/20" : "text-white/40 hover:text-white"}`}
        >
          Salary Chain %
        </button>
        <button
          onClick={() => setActiveTab("reset")}
          className={`px-8 py-3 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${activeTab === "reset" ? "bg-amber-500 text-black shadow-lg shadow-amber-500/20" : "text-white/40 hover:text-white"}`}
        >
          Reset Progress
        </button>
      </div>

      {activeTab === "reset" ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <div className="glass-card p-10 space-y-6 border border-amber-500/20">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-2xl bg-amber-500/20 flex items-center justify-center">
                <RotateCcw className="text-amber-400" size={24} />
              </div>
              <div>
                <h3 className="text-xl font-black italic uppercase tracking-tight">Reset All</h3>
                <p className="text-xs text-white/40 font-bold uppercase tracking-widest mt-1">
                  Current period only — charm, diamonds, on-mic, valid days → 0
                </p>
              </div>
            </div>
            <p className="text-sm text-white/50 leading-relaxed">
              Har user ka current period (1–15 ya 16–month end) target progress zero ho jayega.
              Purane periods / paid settlements touch nahi hote.
            </p>
            <button
              disabled={loading}
              onClick={async () => {
                if (!confirm("Reset ALL users' current period targets to zero?")) return;
                setLoading(true);
                setResetMessage(null);
                const res = await resetAllPeriodTargets();
                setLoading(false);
                if (res.success) {
                  setResetMessage(res.data?.message || "All targets reset");
                  router.refresh();
                } else {
                  alert(res.error);
                }
              }}
              className="w-full py-5 bg-amber-500 hover:bg-amber-400 text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 disabled:opacity-50"
            >
              {loading ? <Loader2 className="animate-spin" /> : <RotateCcw size={18} />}
              Reset All Targets
            </button>
          </div>

          <div className="glass-card p-10 space-y-6 border border-violet-500/20">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-2xl bg-violet-500/20 flex items-center justify-center">
                <Target className="text-violet-300" size={24} />
              </div>
              <div>
                <h3 className="text-xl font-black italic uppercase tracking-tight">
                  Reset One User
                </h3>
                <p className="text-xs text-white/40 font-bold uppercase tracking-widest mt-1">
                  Short ID (e.g. 1001) ya user UUID
                </p>
              </div>
            </div>
            <input
              value={userQuery}
              onChange={(e) => setUserQuery(e.target.value)}
              placeholder="User short ID or UUID"
              className="w-full bg-white/5 border border-white/10 rounded-2xl p-5 text-lg font-bold focus:border-violet-500 transition-all outline-none"
            />
            <button
              disabled={loading || !userQuery.trim()}
              onClick={async () => {
                const q = userQuery.trim();
                if (!q) return;
                if (!confirm(`Reset current period targets for ${q}?`)) return;
                setLoading(true);
                setResetMessage(null);
                const isUuid =
                  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(q);
                const res = await resetUserPeriodTargets(isUuid ? { userId: q } : { shortId: q });
                setLoading(false);
                if (res.success) {
                  setResetMessage(res.data?.message || "User targets reset");
                  setUserQuery("");
                  router.refresh();
                } else {
                  alert(res.error);
                }
              }}
              className="w-full py-5 bg-violet-500 hover:bg-violet-400 text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 disabled:opacity-50"
            >
              {loading ? <Loader2 className="animate-spin" /> : <RotateCcw size={18} />}
              Reset This User
            </button>
          </div>

          {resetMessage && (
            <div className="lg:col-span-2 rounded-2xl border border-emerald-500/30 bg-emerald-500/10 px-6 py-4 text-emerald-300 text-sm font-bold">
              {resetMessage}
            </div>
          )}
        </div>
      ) : activeTab === "salaryChain" ? (
        <div className="glass-card p-10 max-w-2xl space-y-8">
          <div>
            <h3 className="text-xl font-black italic uppercase tracking-tight">
              Salary Chain Overrides
            </h3>
            <p className="text-xs text-white/40 font-bold uppercase tracking-widest mt-2">
              % of host tier reward when host qualifies (bi-monthly payout)
            </p>
          </div>
          <div className="space-y-6">
            {[
              { key: "agency_salary_pc", label: "Agency %" },
              { key: "bd_salary_pc", label: "BD %" },
              { key: "bd_admin_salary_pc", label: "BD Admin %" },
              { key: "super_bd_salary_pc", label: "Super BD %" },
            ].map((field) => (
              <div key={field.key} className="space-y-3">
                <label className="text-[10px] font-black uppercase tracking-widest text-white/30">
                  {field.label}
                </label>
                <input
                  type="number"
                  min={0}
                  max={100}
                  value={chainData[field.key] ?? 0}
                  onChange={(e) =>
                    setChainData({ ...chainData, [field.key]: parseInt(e.target.value) || 0 })
                  }
                  className="w-full bg-white/5 border border-white/10 rounded-2xl p-5 text-xl font-black focus:border-purple-500 transition-all outline-none"
                />
              </div>
            ))}
            <div className="space-y-3">
              <label className="text-[10px] font-black uppercase tracking-widest text-white/30">
                Diamonds per $ (tier reward)
              </label>
              <input
                type="number"
                min={1}
                value={chainData.diamonds_per_dollar ?? 1000}
                onChange={(e) =>
                  setChainData({
                    ...chainData,
                    diamonds_per_dollar: parseInt(e.target.value) || 1000,
                  })
                }
                className="w-full bg-white/5 border border-white/10 rounded-2xl p-5 text-xl font-black focus:border-purple-500 transition-all outline-none"
              />
              <p className="text-[10px] text-white/30">
                $3 tier = {3 * (chainData.diamonds_per_dollar ?? 1000)} diamonds
              </p>
            </div>
            <div className="space-y-3">
              <label className="text-[10px] font-black uppercase tracking-widest text-white/30">
                Valid day minimum (seconds on-mic)
              </label>
              <input
                type="number"
                min={60}
                value={chainData.min_valid_day_seconds ?? 7200}
                onChange={(e) =>
                  setChainData({
                    ...chainData,
                    min_valid_day_seconds: parseInt(e.target.value) || 7200,
                  })
                }
                className="w-full bg-white/5 border border-white/10 rounded-2xl p-5 text-xl font-black focus:border-purple-500 transition-all outline-none"
              />
            </div>
            <button
              onClick={handleUpdateSalaryChain}
              disabled={loading}
              className="w-full py-6 bg-emerald-500 hover:bg-emerald-400 text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 disabled:opacity-50"
            >
              {loading ? <Loader2 className="animate-spin" /> : <Save size={20} />}
              Save Salary Chain Settings
            </button>
          </div>
        </div>
      ) : activeTab === "commission" ? (
        <div className="glass-card p-10 max-w-2xl space-y-8">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-2xl bg-purple-500/20 flex items-center justify-center">
              <Percent className="text-purple-400" size={24} />
            </div>
            <div>
              <h3 className="text-xl font-black italic uppercase tracking-tight">
                Revenue Sharing
              </h3>
              <p className="text-xs text-white/40 font-bold uppercase tracking-widest">
                6-Tier Cascade Commission
              </p>
            </div>
          </div>

          <div
            className={`rounded-2xl border px-5 py-4 text-sm font-bold ${commissionSum === 100 ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-300" : "border-red-500/30 bg-red-500/10 text-red-300"}`}
          >
            Total: {commissionSum}% {commissionSum === 100 ? "(valid)" : "— must equal 100%"}
          </div>

          <div className="space-y-6">
            {commissionFields.map((field) => (
              <div key={field.key} className="space-y-3">
                <label className="text-[10px] font-black uppercase tracking-widest text-white/30">
                  {field.label}
                </label>
                <input
                  type="number"
                  min={0}
                  max={100}
                  value={commData[field.key] ?? 0}
                  onChange={(e) => {
                    const value = parseInt(e.target.value) || 0;
                    const next = { ...commData, [field.key]: value };
                    if (field.key === "official_pc") next.admin_pc = value;
                    setCommData(next);
                  }}
                  className="w-full bg-white/5 border border-white/10 rounded-2xl p-5 text-xl font-black focus:border-purple-500 transition-all outline-none"
                />
              </div>
            ))}

            <div className="pt-6">
              <button
                onClick={handleUpdateCommission}
                disabled={loading || commissionSum !== 100}
                className="w-full py-6 bg-purple-500 hover:bg-purple-400 text-black font-black rounded-2xl transition-all flex items-center justify-center gap-3 shadow-xl shadow-purple-500/10 active:scale-95 disabled:opacity-50"
              >
                {loading ? <Loader2 className="animate-spin" /> : <Save size={20} />}
                Save Commission Settings
              </button>
            </div>
          </div>
        </div>
      ) : (
        <div className="space-y-6">
          <p className="text-sm text-white/50 max-w-2xl">
            Host-only packages. When a host meets diamonds + hours + valid days in a period (1–15 or
            16–month end), they receive the highest matching tier on payout day.
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {salaryTiers.map((tier) => (
              <div key={tier.id} className="glass-card p-8 group relative overflow-hidden">
                <div className="flex justify-between items-start mb-6">
                  <div className="w-10 h-10 rounded-xl bg-emerald-500/20 flex items-center justify-center">
                    <Target className="text-emerald-400" size={20} />
                  </div>
                  <button
                    onClick={() => handleDeleteTier(tier.id)}
                    className="p-2 text-red-500/40 hover:text-red-500 hover:bg-red-500/10 rounded-lg transition-all"
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
                <div className="space-y-6">
                  {tier.tier_name && (
                    <p className="text-xs font-black uppercase tracking-widest text-emerald-400/80">
                      {tier.tier_name}
                    </p>
                  )}
                  <div>
                    <p className="text-[10px] font-black uppercase tracking-widest text-white/20">
                      Diamonds Target
                    </p>
                    <p className="text-3xl font-black tracking-tighter">
                      {tier.diamonds_target.toLocaleString()}
                    </p>
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <p className="text-[10px] font-black uppercase tracking-widest text-white/20">
                        Hours
                      </p>
                      <p className="text-lg font-bold">{tier.hours_target}h</p>
                    </div>
                    <div>
                      <p className="text-[10px] font-black uppercase tracking-widest text-white/20">
                        Days
                      </p>
                      <p className="text-lg font-bold">{tier.days_target}d</p>
                    </div>
                  </div>
                  <div className="pt-4 border-t border-white/5">
                    <p className="text-[10px] font-black uppercase tracking-widest text-white/20 mb-1">
                      Reward Amount
                    </p>
                    <p className="text-2xl font-black text-amber-500">${tier.reward_amount}</p>
                  </div>
                </div>
              </div>
            ))}

            <button
              onClick={() => {
                const name = prompt("Tier name (e.g. Bronze / $3)?");
                const diamonds = prompt("Diamonds Target?");
                const hours = prompt("Hours Target?");
                const days = prompt("Days Target?");
                const reward = prompt("Reward Amount ($)?");
                if (diamonds && hours && days && reward) {
                  addSalaryTier({
                    tier_name: name || undefined,
                    diamonds_target: parseInt(diamonds),
                    hours_target: parseInt(hours),
                    days_target: parseInt(days),
                    reward_amount: parseInt(reward),
                  }).then((res) => {
                    if (res.success) router.refresh();
                    else alert(res.error);
                  });
                }
              }}
              className="glass-card p-10 border-dashed border-white/10 hover:border-purple-500/30 bg-purple-500/5 hover:bg-purple-500/10 transition-all flex flex-col items-center justify-center gap-4 group"
            >
              <div className="w-16 h-16 rounded-full bg-purple-500/20 flex items-center justify-center group-hover:scale-110 transition-transform">
                <Plus className="text-purple-400" size={32} />
              </div>
              <p className="text-xs font-black uppercase tracking-[0.2em] text-white/40 group-hover:text-white">
                Add Salary Tier
              </p>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
