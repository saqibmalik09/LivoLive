import Link from "next/link";
import { ArrowLeft, ScrollText } from "lucide-react";
import { GameLogsClient } from "./GameLogsClient";
import { loadGameLogsPage, type GameLogFilters } from "@/app/settings/game-logs/actions";
import { getAutoSwitchSettings, getGameControlMode } from "@/app/settings/game-control/actions";
function parseFilters(sp: Record<string, string | undefined>): GameLogFilters {
  const rangeRaw = sp.range || "7d";
  const range =
    rangeRaw === "today" ||
    rangeRaw === "7d" ||
    rangeRaw === "30d" ||
    rangeRaw === "all" ||
    rangeRaw === "custom"
      ? rangeRaw
      : "7d";
  const outcome =
    sp.outcome === "win" || sp.outcome === "loss" || sp.outcome === "all" ? sp.outcome : "all";
  const minStake = sp.minStake ? Number(sp.minStake) : null;
  const roundNumber = sp.round ? Number(sp.round) : null;
  return {
    gameSlug: sp.game || "all",
    outcome,
    userQ: sp.q || "",
    range,
    from: sp.from || null,
    to: sp.to || null,
    minStake: minStake && Number.isFinite(minStake) ? minStake : null,
    roundNumber: roundNumber && Number.isFinite(roundNumber) ? roundNumber : null,
  };
}
export default async function GameLogsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | undefined>>;
}) {
  const sp = await searchParams;
  const filters = parseFilters(sp);
  let games: Awaited<ReturnType<typeof loadGameLogsPage>>["games"] = [];
  let summary: Awaited<ReturnType<typeof loadGameLogsPage>>["summary"] | null = null;
  let rows: Awaited<ReturnType<typeof loadGameLogsPage>>["rows"] = [];
  let hasMore = false;
  let error: string | null = null;
  let engineMode = "random";
  let autoEnabled = false;
  let autoLast = "";
  let autoLoss = "50000000";
  let autoRecover = "100000000";
  let autoMaxLoss = "100000000";
  try {
    const data = await loadGameLogsPage(filters, 40);
    games = data.games;
    summary = data.summary;
    rows = data.rows;
    hasMore = data.hasMore;
  } catch (e: any) {
    error = e?.message || "Failed to load game logs";
  }
  try {
    const [mode, auto] = await Promise.all([getGameControlMode(), getAutoSwitchSettings()]);
    engineMode = mode === "house_optimized" ? "house_optimized" : "random";
    autoEnabled = auto.enabled;
    autoLast = auto.last;
    autoLoss = auto.loss_coins;
    autoRecover = auto.recover_coins;
    autoMaxLoss = auto.max_loss_coins;
  } catch {
    engineMode = "random";
  }
  return (
    <div className="space-y-10 pb-32">
      <Link
        href="/settings/game-control"
        className="inline-flex items-center gap-2 text-white/40 hover:text-white transition-colors group"
      >
        <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
        <span className="text-[10px] font-black uppercase tracking-widest">Game Control</span>
      </Link>

      <header className="flex items-center gap-6">
        <div className="w-20 h-20 rounded-3xl bg-violet-500/20 border border-violet-500/20 flex items-center justify-center text-violet-300">
          <ScrollText size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter italic">Games Logs</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            Who won or lost how much on each H5 game — filters, lazy load, payout credited, and
            balance after that bet settled (saved on the bet).
          </p>
        </div>
      </header>

      {error || !summary ? (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Failed to load</p>
          <p>{error || "Unknown error"}</p>
          <p className="mt-3 text-white/50">
            Ensure migration{" "}
            <code className="text-violet-300">20260725110000_admin_game_bet_logs.sql</code> is
            applied.
          </p>
        </div>
      ) : (
        <GameLogsClient
          games={games}
          summary={summary}
          initialRows={rows}
          initialHasMore={hasMore}
          filters={filters}
          initialEngineMode={engineMode}
          initialAutoEnabled={autoEnabled}
          initialAutoLast={autoLast}
          initialAutoLossCoins={autoLoss}
          initialAutoRecoverCoins={autoRecover}
          initialAutoMaxLossCoins={autoMaxLoss}
        />
      )}
    </div>
  );
}
