import { RoomCardFramesForm } from "@/components/RoomCardFramesForm";
import { ArrowLeft, Home } from "lucide-react";
import Link from "next/link";
export default function RoomCardFramesSettingsPage() {
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
        <div className="w-20 h-20 rounded-3xl bg-emerald-500/20 border border-emerald-500/20 flex items-center justify-center text-emerald-400">
          <Home size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Room Card Frames</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Daily TOP 1–3 frames for Hot tab Room Top-3 cards and Popular / New room grid cards (not
            ranking podium).
          </p>
        </div>
      </header>

      <RoomCardFramesForm />
    </div>
  );
}
