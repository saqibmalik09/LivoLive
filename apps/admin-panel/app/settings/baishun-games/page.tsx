import Link from "next/link";
import { ArrowLeft, Dices } from "lucide-react";
import { listBaishunGames } from "@/app/settings/baishun-games/actions";
import { listRoomGameCategories } from "@/app/settings/game-control/actions";
import { BaishunGamesManager } from "@/components/BaishunGamesManager";
export const dynamic = "force-dynamic";
export default async function BaishunGamesSettingsPage() {
  let games: Awaited<ReturnType<typeof listBaishunGames>> = [];
  let categories: Awaited<ReturnType<typeof listRoomGameCategories>> = [];
  let error: string | null = null;
  try {
    [games, categories] = await Promise.all([
      listBaishunGames(),
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
        <div className="w-20 h-20 rounded-3xl bg-orange-500/20 border border-orange-500/20 flex items-center justify-center text-orange-300">
          <Dices size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Baishun Games</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Sync or add Baishun room games, upload Coolify icons, activate for the room games sheet.
          </p>
        </div>
      </header>

      {error && (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error}</p>
        </div>
      )}

      {!error && <BaishunGamesManager games={games} categories={categories} />}
    </div>
  );
}
