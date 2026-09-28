import { AgencyRankingAssetsForm } from "@/components/AgencyRankingAssetsForm";
import { ArrowLeft, Building2 } from "lucide-react";
import Link from "next/link";
export default function AgencyRankingAssetsPage() {
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
        <div className="w-20 h-20 rounded-3xl bg-orange-500/20 border border-orange-500/20 flex items-center justify-center text-orange-400">
          <Building2 size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Agency Ranking Assets</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Daily, weekly, and monthly TOP 1 / 2 / 3 frames and badges for the Gift Center Agency
            ranking tab.
          </p>
        </div>
      </header>

      <AgencyRankingAssetsForm />
    </div>
  );
}
