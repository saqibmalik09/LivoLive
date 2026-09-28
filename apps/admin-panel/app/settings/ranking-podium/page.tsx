import { supabaseAdmin } from "@/lib/supabase";
import { RankingPodiumForm } from "@/components/RankingPodiumForm";
import { ArrowLeft, Trophy } from "lucide-react";
import Link from "next/link";
export default async function RankingPodiumSettingsPage() {
  const { data: config, error } = await supabaseAdmin
    .from("home_ranking_podium_config")
    .select("*")
    .eq("id", 1)
    .maybeSingle();
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
        <div className="w-20 h-20 rounded-3xl bg-violet-500/20 border border-violet-500/20 flex items-center justify-center text-violet-400">
          <Trophy size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Ranking Podium Cards</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Background scenes for Room, Agency, Charm, and Wealth podium previews on the Hot tab.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          {error.message}
        </div>
      )}

      <RankingPodiumForm config={config ?? {}} />
    </div>
  );
}
