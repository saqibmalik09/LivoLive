import { ArrowLeft, Home, LayoutGrid } from "lucide-react";
import Link from "next/link";
export default function HotCardsSettingsPage() {
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
          <LayoutGrid size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Hot Tab Cards</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            The old carousel / Party / Music media cards are retired. The Hot tab now shows Room
            Daily Top 1–3 with frames from Room Card Frames.
          </p>
        </div>
      </header>

      <div className="glass-card border border-emerald-500/20 p-8 rounded-2xl space-y-4 max-w-xl">
        <p className="text-white/80 font-medium">Upload TOP 1, TOP 2, and TOP 3 frames here:</p>
        <Link
          href="/settings/room-card-frames"
          className="inline-flex items-center gap-3 px-5 py-3 rounded-xl bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 font-bold transition-colors"
        >
          <Home size={18} />
          Open Room Card Frames
        </Link>
      </div>
    </div>
  );
}
