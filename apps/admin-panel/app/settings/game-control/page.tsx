import { ArrowLeft, Gamepad2 } from "lucide-react";
import Link from "next/link";
import { GameControlManager } from "@/components/GameControlManager";
import {
  getGameControlMode,
  getHouseEdgeSettings,
  getAutoSwitchSettings,
  getRtpEngineSettings,
  listGameConfigsForAdmin,
  listRoomGameCategories,
} from "@/app/settings/game-control/actions";
export default async function GameControlSettingsPage() {
  let games: Awaited<ReturnType<typeof listGameConfigsForAdmin>> = [];
  let mode = "random";
  let house: Awaited<ReturnType<typeof getHouseEdgeSettings>> = {
    target_edge: "0.10",
    max_round_rtp: "0.95",
    pay_to_bets_rate: "0.40",
    natural_win_rate: "0.90",
    soft_edge_rate: "0.08",
    big_hit_enabled: "false",
    big_hit_every_min: "80",
    big_hit_every_max: "120",
    big_hit_min_mult: "15",
    big_hit_rate: "0.05",
    daily_loss_breaker: "0",
    outcome_weights: '{"5":30,"10":12,"15":6,"25":2,"45":1}',
  };
  let auto: Awaited<ReturnType<typeof getAutoSwitchSettings>> = {
    enabled: false,
    loss_coins: "50000000",
    recover_coins: "100000000",
    max_loss_coins: "100000000",
    last: "",
  };
  let rtp: Awaited<ReturnType<typeof getRtpEngineSettings>> = {
    enabled: true,
    target_rtp: "0.90",
    bank_alpha: "0.30",
    bank_clamp_min: "0.7",
    bank_clamp_max: "1.4",
    max_round_exposure: "12.0",
    mercy_streak: "8",
    mercy_max_mult: "5",
  };
  let categories: Awaited<ReturnType<typeof listRoomGameCategories>> = [];
  let error: string | null = null;
  try {
    const [g, m, h, a, r, cats] = await Promise.all([
      listGameConfigsForAdmin(),
      getGameControlMode(),
      getHouseEdgeSettings(),
      getAutoSwitchSettings(),
      getRtpEngineSettings(),
      listRoomGameCategories().catch(() => []),
    ]);
    games = g;
    mode = m;
    house = h;
    auto = a;
    rtp = r;
    categories = cats;
  } catch (e: any) {
    error = e?.message || "Failed to load game configs";
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
        <div className="w-20 h-20 rounded-3xl bg-violet-500/20 border border-violet-500/20 flex items-center justify-center text-violet-300">
          <Gamepad2 size={40} />
        </div>
        <div>
          <h1 className="text-5xl font-black tracking-tighter">Game Control</h1>
          <p className="text-white/60 mt-2 font-medium max-w-xl">
            RTP wheel engine (90% target), per-game configs, maintenance, and multipliers.
          </p>
          <Link
            href="/settings/game-logs"
            className="inline-flex mt-4 text-sm font-bold text-violet-300 hover:underline"
          >
            Open Games Logs →
          </Link>
        </div>
      </header>

      {error ? (
        <div className="glass-card border border-red-500/30 p-6 text-red-300 text-sm">
          <p className="font-bold mb-2">Database error</p>
          <p>{error}</p>
        </div>
      ) : (
        <GameControlManager
          initialGames={games}
          initialMode={mode}
          initialHouse={house}
          initialAuto={auto}
          initialRtp={rtp}
          categories={categories}
        />
      )}
    </div>
  );
}
