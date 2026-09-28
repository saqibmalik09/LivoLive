import { RankingAssetsForm } from "@/components/RankingAssetsForm";
import { ArrowLeft, Frame } from "lucide-react";
import Link from "next/link";
export default function RankingAssetsSettingsPage() {
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={18} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-xs font-bold uppercase tracking-widest">Back to Settings</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-amber-500/20 border border-amber-500/20 flex items-center justify-center text-amber-400">
          <Frame size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Home Podium Frames</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            TOP 1 / 2 / 3 wing frames, plus optional Room / Agency / Charm / Wealth overrides. Empty
            slide seats fall back to Default.
          </p>
        </div>
      </header>

      <RankingAssetsForm />
    </div>
  );
}
