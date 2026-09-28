"use client";
import { useState } from "react";
import { Loader2, Save, CheckCircle2 } from "lucide-react";
import { saveVoiceBackendSettings, type VoiceBackendSettings } from "./actions";
export function VoiceBackendForm({ initial }: { initial: VoiceBackendSettings }) {
  const [backend, setBackend] = useState<"zego" | "orbit">(initial.voice_backend);
  const [loading, setLoading] = useState(false);
  const [ok, setOk] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function onSave() {
    setLoading(true);
    setError(null);
    setOk(false);
    const res = await saveVoiceBackendSettings({
      voice_backend: backend,
      orbit_api_url: initial.orbit_api_url,
      orbit_livekit_url: initial.orbit_livekit_url,
    });
    setLoading(false);
    if (!res.success) {
      setError(res.error || "Save failed");
      return;
    }
    setOk(true);
    setTimeout(() => setOk(false), 2000);
  }
  return (
    <div className="glass-card space-y-8 p-8">
      <div className="space-y-3">
        <label className="text-xs font-black uppercase tracking-widest text-white/50">
          Active voice backend
        </label>
        <div className="flex flex-wrap gap-3">
          {(
            [
              { id: "zego" as const, title: "Zego", desc: "Production voice engine" },
              { id: "orbit" as const, title: "Orbit Voice", desc: "Powered by Almohsin Dev" },
            ] as const
          ).map((opt) => {
            const selected = backend === opt.id;
            return (
              <button
                key={opt.id}
                type="button"
                onClick={() => setBackend(opt.id)}
                className={`min-w-[160px] rounded-2xl border px-5 py-4 text-left transition-all ${
                  selected
                    ? "border-cyan-400/60 bg-cyan-500/15"
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

      {error && <p className="text-sm text-red-400">{error}</p>}

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
        Save voice backend
      </button>
    </div>
  );
}
