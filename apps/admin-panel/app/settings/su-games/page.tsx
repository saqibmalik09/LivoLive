import Link from "next/link";
import { ArrowLeft, Gamepad2 } from "lucide-react";
import {
  listGamesForSuHub,
  listSuGameCategories,
  listSuGameItems,
} from "@/app/settings/su-games/actions";
import { SuGamesManager } from "@/components/SuGamesManager";
export const dynamic = "force-dynamic";
export default async function SuGamesSettingsPage() {
  let categories: Awaited<ReturnType<typeof listSuGameCategories>> = [];
  let items: Awaited<ReturnType<typeof listSuGameItems>> = [];
  let error: string | null = null;
  try {
    [categories, items] = await Promise.all([listSuGameCategories(), listSuGameItems()]);
  } catch (e: unknown) {
    error = e instanceof Error ? e.message : "Failed to load";
  }
  const games = await listGamesForSuHub();
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
        <div className="w-20 h-20 rounded-3xl bg-fuchsia-500/20 border border-fuchsia-500/20 flex items-center justify-center text-fuchsia-300">
          <Gamepad2 size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">SU Game Hub</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Categories on the left of the SU / Game tab. Pick which games show in each category — H5
            games from Game Control, plus Lucky Offer.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error}</p>
          <p className="mt-3 text-white/50">
            Run <code className="text-amber-400">node scripts/apply-su-game-hub-migration.mjs</code>{" "}
            from sklive-admin.
          </p>
        </div>
      )}

      {!error && <SuGamesManager categories={categories} items={items} games={games} />}
    </div>
  );
}
