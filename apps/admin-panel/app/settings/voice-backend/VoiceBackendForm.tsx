"use client";
import { useState } from "react";
import { Loader2, Save, CheckCircle2, ShieldCheck } from "lucide-react";
import {
  saveVoiceBackendSettings,
  type VoiceBackendSettings,
  type VoiceBackendId,
} from "./actions";

// Orbit and Zego are retired. LiveKit is the only supported backend.
const OPTIONS: { id: VoiceBackendId; title: string; desc: string }[] = [
  { id: "livekit", title: "LiveKit (direct)", desc: "Tokens minted by our gateway" },
];

export function VoiceBackendForm({ initial }: { initial: VoiceBackendSettings }) {
  const [backend, setBackend] = useState<VoiceBackendId>(initial.voice_backend);
  const [livekitUrl, setLivekitUrl] = useState(initial.livekit_url);
  const [livekitKey, setLivekitKey] = useState(initial.livekit_api_key);
  const [livekitSecret, setLivekitSecret] = useState("");
  const [testIds, setTestIds] = useState(initial.livekit_test_user_ids);
  const [loading, setLoading] = useState(false);
  const [ok, setOk] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const secretStored = Boolean(initial.livekit_secret_set);

  async function onSave() {
    setLoading(true);
    setError(null);
    setOk(false);
    const res = await saveVoiceBackendSettings({
      voice_backend: backend,
      orbit_api_url: initial.orbit_api_url,
      orbit_livekit_url: initial.orbit_livekit_url,
      livekit_url: livekitUrl,
      livekit_api_key: livekitKey,
      livekit_api_secret: livekitSecret,
      livekit_test_user_ids: testIds,
    });
    setLoading(false);
    if (!res.success) {
      setError(res.error || "Save failed");
      return;
    }
    setLivekitSecret("");
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
          {OPTIONS.map((opt) => {
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

      {backend === "livekit" && (
        <div className="space-y-5 rounded-2xl border border-cyan-400/20 bg-cyan-500/5 p-6">
          <p className="text-xs text-white/50">
            Tokens are minted by our own gateway using this key pair. The secret is stored
            server-side and is never sent back to this page.
          </p>

          <div className="space-y-2">
            <label className="text-xs font-black uppercase tracking-widest text-white/50">
              LiveKit URL
            </label>
            <input
              value={livekitUrl}
              onChange={(e) => setLivekitUrl(e.target.value)}
              placeholder="wss://voice.skliveparty.online"
              className="w-full rounded-xl border border-white/10 bg-black/40 px-4 py-3 text-sm text-white outline-none focus:border-cyan-400/60"
            />
          </div>

          <div className="space-y-2">
            <label className="text-xs font-black uppercase tracking-widest text-white/50">
              API key
            </label>
            <input
              value={livekitKey}
              onChange={(e) => setLivekitKey(e.target.value)}
              placeholder="APIxxxxxxxxxxxx"
              className="w-full rounded-xl border border-white/10 bg-black/40 px-4 py-3 text-sm text-white outline-none focus:border-cyan-400/60"
            />
          </div>

          <div className="space-y-2">
            <label className="flex items-center gap-2 text-xs font-black uppercase tracking-widest text-white/50">
              API secret
              {secretStored && (
                <span className="inline-flex items-center gap-1 rounded-full bg-emerald-500/15 px-2 py-0.5 text-[10px] font-bold text-emerald-300">
                  <ShieldCheck size={11} /> stored
                </span>
              )}
            </label>
            <input
              type="password"
              value={livekitSecret}
              onChange={(e) => setLivekitSecret(e.target.value)}
              placeholder={secretStored ? "Leave blank to keep the stored secret" : "Paste the API secret"}
              className="w-full rounded-xl border border-white/10 bg-black/40 px-4 py-3 text-sm text-white outline-none focus:border-cyan-400/60"
            />
          </div>
        </div>
      )}

      <div className="space-y-2 rounded-2xl border border-amber-400/20 bg-amber-500/5 p-6">
        <label className="text-xs font-black uppercase tracking-widest text-white/50">
          LiveKit test accounts
        </label>
        <p className="text-xs text-white/50">
          These user ids always get LiveKit, whatever the active backend is. Use this to test a
          new build against production without moving everyone onto it. Comma-separated; leave
          blank for none.
        </p>
        <input
          value={testIds}
          onChange={(e) => setTestIds(e.target.value)}
          placeholder="11111111-2222-3333-4444-555555555555, ..."
          className="w-full rounded-xl border border-white/10 bg-black/40 px-4 py-3 text-sm text-white outline-none focus:border-amber-400/60"
        />
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
