import Link from "next/link";
import { ArrowLeft, Mic2 } from "lucide-react";
import { loadVoiceBackendSettings } from "./actions";
import { VoiceBackendForm } from "./VoiceBackendForm";
export default async function VoiceBackendSettingsPage() {
  const settings = await loadVoiceBackendSettings();
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 transition-colors hover:text-white group"
      >
        <ArrowLeft size={18} className="transition-transform group-hover:-translate-x-1" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Settings</span>
      </Link>

      <header className="space-y-2">
        <div className="flex items-center gap-3">
          <Mic2 className="text-cyan-300" size={28} />
          <h1 className="bg-gradient-to-r from-cyan-300 to-sky-400 bg-clip-text text-5xl font-black tracking-tighter text-transparent">
            Voice Backend
          </h1>
        </div>
        <p className="max-w-2xl text-white/55">
          Selects which stack rooms use. <strong className="text-white/80">Orbit Voice</strong>
          reaches LiveKit through the Orbit API; <strong className="text-white/80">LiveKit
          (direct)</strong> mints tokens in our own gateway with no middleman.
          <strong className="text-white/80">Zego</strong> is the legacy engine. Switching takes
          effect on the next room join — no app release needed.
        </p>
      </header>

      <VoiceBackendForm initial={settings} />
    </div>
  );
}
