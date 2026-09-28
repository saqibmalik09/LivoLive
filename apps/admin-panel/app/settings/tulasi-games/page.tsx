import Link from "next/link";
import { ArrowLeft, Gamepad2 } from "lucide-react";
import { listTulasiGames, listTulasiTransactions } from "@/app/settings/tulasi-games/actions";
import { listRoomGameCategories } from "@/app/settings/game-control/actions";
import { TulasiGamesManager } from "@/components/TulasiGamesManager";
export const dynamic = "force-dynamic";
export default async function TulasiGamesSettingsPage() {
  let games: Awaited<ReturnType<typeof listTulasiGames>> = [];
  let transactions: Awaited<ReturnType<typeof listTulasiTransactions>> = [];
  let categories: Awaited<ReturnType<typeof listRoomGameCategories>> = [];
  let error: string | null = null;
  try {
    [games, transactions, categories] = await Promise.all([
      listTulasiGames(),
      listTulasiTransactions(50),
      listRoomGameCategories().catch(() => []),
    ]);
  } catch (e: unknown) {
    error = e instanceof Error ? e.message : "Failed to load";
  }
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
        <div className="w-20 h-20 rounded-3xl bg-cyan-500/20 border border-cyan-500/20 flex items-center justify-center text-cyan-300">
          <Gamepad2 size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Tulasi Games</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Merchant H5 games synced from Tulasi. Toggle active, LAND/PORT, edit URLs, and review
            balance callbacks.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error}</p>
          <p className="mt-3 text-white/50">
            Ensure Tulasi merchant migration is applied and Edge function is deployed.
          </p>
        </div>
      )}

      {!error && (
        <TulasiGamesManager games={games} transactions={transactions} categories={categories} />
      )}
    </div>
  );
}
