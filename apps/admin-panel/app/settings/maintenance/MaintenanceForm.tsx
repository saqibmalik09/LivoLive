"use client";
import { useState } from "react";
import { Loader2, Save, CheckCircle2, AlertTriangle } from "lucide-react";
import { saveMaintenanceSettings, type MaintenanceSettings } from "./actions";
export function MaintenanceForm({ initial }: { initial: MaintenanceSettings }) {
  const [enabled, setEnabled] = useState(initial.enabled);
  const [message, setMessage] = useState(initial.message);
  const [confirming, setConfirming] = useState(false);
  const [loading, setLoading] = useState(false);
  const [ok, setOk] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const turningOn = enabled && !initial.enabled;
  async function persist() {
    setConfirming(false);
    setLoading(true);
    setError(null);
    setOk(false);
    const res = await saveMaintenanceSettings({ enabled, message });
    setLoading(false);
    if (!res.success) {
      setError(res.error || "Save failed");
      return;
    }
    setOk(true);
    setTimeout(() => setOk(false), 2000);
  }
  function onSave() {
    if (turningOn) {
      setConfirming(true);
      return;
    }
    void persist();
  }
  return (
    <div className="glass-card space-y-8 p-8">
      <div className="space-y-3">
        <label className="text-xs font-black uppercase tracking-widest text-white/50">
          Maintenance mode
        </label>
        <div className="flex flex-wrap gap-3">
          {(
            [
              {
                id: false,
                title: "Live",
                desc: "App and rooms work normally",
              },
              {
                id: true,
                title: "Maintenance",
                desc: "Everyone blocked and disconnected",
              },
            ] as const
          ).map((opt) => {
            const selected = enabled === opt.id;
            return (
              <button
                key={String(opt.id)}
                type="button"
                onClick={() => setEnabled(opt.id)}
                className={`min-w-[200px] rounded-2xl border px-5 py-4 text-left transition-all ${
                  selected
                    ? opt.id
                      ? "border-amber-400/60 bg-amber-500/15"
                      : "border-emerald-400/60 bg-emerald-500/15"
                    : "border-white/10 bg-black/30 hover:border-white/25"
                }`}
              >
                <div className="text-sm font-bold text-white">{opt.title}</div>
                <div className="mt-1 text-xs text-white/40">{opt.desc}</div>
              </button>
            );
          })}
        </div>
      </div>

      <div className="space-y-3">
        <label className="text-xs font-black uppercase tracking-widest text-white/50">
          Message shown to users
        </label>
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          rows={3}
          placeholder="We are performing scheduled maintenance. Please check back shortly."
          className="w-full rounded-2xl border border-white/10 bg-black/30 px-4 py-3 text-sm text-white outline-none transition-colors focus:border-white/30"
        />
        <p className="text-xs text-white/30">
          Leave empty to use the default text built into the app.
        </p>
      </div>

      {error && <p className="text-sm text-red-400">{error}</p>}

      {confirming ? (
        <div className="space-y-4 rounded-2xl border border-amber-400/40 bg-amber-500/10 p-5">
          <div className="flex items-start gap-3">
            <AlertTriangle size={20} className="mt-0.5 shrink-0 text-amber-300" />
            <div className="space-y-1">
              <p className="text-sm font-bold text-white">Turn on maintenance for everyone?</p>
              <p className="text-xs text-white/60">
                Every user is kicked out of their room within about 30 seconds and nobody can enter
                the app until you turn this back off.
              </p>
            </div>
          </div>
          <div className="flex gap-3">
            <button
              type="button"
              onClick={() => void persist()}
              className="rounded-xl bg-amber-400 px-5 py-3 text-sm font-bold text-black hover:bg-amber-300"
            >
              Yes, take the app down
            </button>
            <button
              type="button"
              onClick={() => setConfirming(false)}
              className="rounded-xl border border-white/10 bg-white/5 px-5 py-3 text-sm font-bold hover:bg-white/10"
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <button
          type="button"
          onClick={onSave}
          disabled={loading}
          className="inline-flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-5 py-3 text-sm font-bold hover:bg-cyan-500 hover:text-black disabled:opacity-40"
        >
          {loading ? (
            <Loader2 size={18} className="animate-spin" />
          ) : ok ? (
            <CheckCircle2 size={18} className="text-emerald-400" />
          ) : (
            <Save size={18} />
          )}
          Save maintenance settings
        </button>
      )}
    </div>
  );
}
