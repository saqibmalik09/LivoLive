import Link from "next/link";
import { ArrowLeft, Gamepad2 } from "lucide-react";
import { listGamesForHomeRow, listHomeGamesRowItems } from "@/app/settings/home-games/actions";
import { HomeGamesRowManager } from "@/components/HomeGamesRowManager";
export const dynamic = "force-dynamic";
export default async function HomeGamesSettingsPage() {
  let items: Awaited<ReturnType<typeof listHomeGamesRowItems>> = [];
  let error: string | null = null;
  try {
    items = await listHomeGamesRowItems();
  } catch (e: unknown) {
    error = e instanceof Error ? e.message : "Failed to load";
  }
  const games = await listGamesForHomeRow();
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
        <div className="w-20 h-20 rounded-3xl bg-sky-500/20 border border-sky-500/20 flex items-center justify-center text-sky-300">
          <Gamepad2 size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Home Games Row</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Icons shown on Home Hot between Ranking Podium and Hot Cards. Set order, toggle
            visibility, optional custom icon.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error}</p>
          <p className="mt-3 text-white/50">
            Run migration{" "}
            <code className="text-amber-400">20260801200000_home_games_row_items.sql</code>
          </p>
        </div>
      )}

      {!error && <HomeGamesRowManager items={items} games={games} />}
    </div>
  );
}
