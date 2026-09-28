"use client";
import { useState } from "react";
import { updateSystemSetting } from "./actions";
import { Save, Loader2, CheckCircle2 } from "lucide-react";
export function SettingRow({ setting }: { setting: any }) {
  const [value, setValue] = useState(setting.value);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const labelMap: Record<string, string> = {
    family_creation_cost: "Family Creation Cost (Coins)",
    invite_download_url: "Invite Friends Download Link",
    room_share_base_url: "Room Share Base URL",
    lucky_room_fanbi_svga_enabled: "Lucky Fanbi Animation (true/false)",
    lucky_room_multiplier_svga_enabled: "Lucky Multiplier Master (true/false)",
    lucky_room_win_svga_enabled: "Lucky Room Win Animation (deprecated)",
  };
  async function handleSave() {
    setLoading(true);
    setSuccess(false);
    const res = await updateSystemSetting(setting.key, value);
    if (res.success) {
      setSuccess(true);
      setTimeout(() => setSuccess(false), 2000);
    } else {
      alert("Error: " + res.error);
    }
    setLoading(false);
  }
  return (
    <div className="p-6 flex flex-col md:flex-row md:items-center justify-between gap-6 hover:bg-white/[0.02] transition-colors">
      <div className="space-y-1">
        <h4 className="text-sm font-bold text-white/90">{labelMap[setting.key] || setting.key}</h4>
        <p className="text-xs text-white/30 max-w-md">
          {setting.description || "No description provided for this system constant."}
        </p>
      </div>

      <div className="flex items-center gap-3">
        <input
          value={value}
          onChange={(e) => setValue(e.target.value)}
          className="bg-black/40 border border-white/10 rounded-xl px-4 py-2 text-sm focus:outline-none focus:border-indigo-500/50 transition-all font-mono min-w-[200px]"
        />
        <button
          onClick={handleSave}
          disabled={loading || value === setting.value}
          className="p-2.5 rounded-xl bg-white/5 border border-white/10 hover:bg-indigo-500 hover:text-black hover:border-transparent transition-all disabled:opacity-20"
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
