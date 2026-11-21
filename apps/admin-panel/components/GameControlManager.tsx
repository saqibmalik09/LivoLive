"use client";
import { CdnImg } from "@/components/CdnImg";
import { useRef, useState, type ReactNode } from "react";
import {
  saveGameControlMode,
  saveHouseEdgeSettings,
  saveAutoSwitchSettings,
  saveRtpEngineSettings,
  toggleGameActive,
  toggleGameMaintenance,
  uploadGameIcon,
  upsertGameConfig,
  type AutoSwitchSettings,
  type GameConfigRow,
  type HouseEdgeSettings,
  type RoomGameCategoryRow,
  type RtpEngineSettings,
} from "@/app/settings/game-control/actions";
import { GameAudienceButton } from "@/components/GameAudiencePanel";
import { CheckCircle2, ExternalLink, Gamepad2, Loader2, Save, Upload, Wrench } from "lucide-react";
interface GameControlManagerProps {
  initialGames: GameConfigRow[];
  initialMode: string;
  initialHouse: HouseEdgeSettings;
  initialAuto: AutoSwitchSettings;
  initialRtp: RtpEngineSettings;
  categories?: RoomGameCategoryRow[];
}
type Draft = GameConfigRow & {
  config_data_json: string;
};
type ProviderFilter = "all" | "native" | "tulasi" | "baishun";
function toDraft(g: GameConfigRow): Draft {
  return {
    ...g,
    config_data_json: JSON.stringify(g.config_data ?? {}, null, 2),
  };
}
function isTulasiGame(game: GameConfigRow | Draft): boolean {
  return game.config_data?.provider === "tulasi";
}
function isBaishunGame(game: GameConfigRow | Draft): boolean {
  return game.config_data?.provider === "baishun";
}
function truthyLandscape(v: unknown): boolean {
  return v === true || v === "true" || v === 1 || v === "1";
}
function readLandscape(game: Draft): boolean {
  const cfg = game.config_data ?? {};
  try {
    const parsed = JSON.parse(game.config_data_json || "{}") as Record<string, unknown>;
    return truthyLandscape(parsed.isLandscape ?? parsed.is_landscape);
  } catch {
    return truthyLandscape(cfg.isLandscape ?? cfg.is_landscape);
  }
}
function setLandscapeOnDraft(game: Draft, on: boolean): Partial<Draft> {
  let parsed: Record<string, unknown> = { ...(game.config_data ?? {}) };
  try {
    const j = JSON.parse(game.config_data_json || "{}");
    if (j && typeof j === "object" && !Array.isArray(j)) {
      parsed = j as Record<string, unknown>;
    }
  } catch {}
  parsed.isLandscape = on;
  return {
    config_data: parsed,
    config_data_json: JSON.stringify(parsed, null, 2),
  };
}
export function GameControlManager({
  initialGames,
  initialMode,
  initialHouse,
  initialAuto,
  initialRtp,
  categories = [],
}: GameControlManagerProps) {
  const [mode, setMode] = useState(
    initialMode === "house_optimized" ? "house_optimized" : "random",
  );
  const [house, setHouse] = useState<HouseEdgeSettings>(initialHouse);
  const [auto, setAuto] = useState<AutoSwitchSettings>(initialAuto);
  const [rtp, setRtp] = useState<RtpEngineSettings>(initialRtp);
  const [savingMode, setSavingMode] = useState(false);
  const [savingHouse, setSavingHouse] = useState(false);
  const [savingAuto, setSavingAuto] = useState(false);
  const [savingRtp, setSavingRtp] = useState(false);
  const [games, setGames] = useState<Draft[]>(initialGames.map(toDraft));
  const [providerFilter, setProviderFilter] = useState<ProviderFilter>("all");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [uploadingId, setUploadingId] = useState<string | null>(null);
  const [message, setMessage] = useState<string>("");
  const fileRefs = useRef<Record<string, HTMLInputElement | null>>({});
  function patchGame(id: string, patch: Partial<Draft>) {
    setGames((prev) => prev.map((g) => (g.id === id ? { ...g, ...patch } : g)));
  }
  function patchHouse(patch: Partial<HouseEdgeSettings>) {
    setHouse((prev) => ({ ...prev, ...patch }));
  }
  function patchAuto(patch: Partial<AutoSwitchSettings>) {
    setAuto((prev) => ({ ...prev, ...patch }));
  }
  function patchRtp(patch: Partial<RtpEngineSettings>) {
    setRtp((prev) => ({ ...prev, ...patch }));
  }
  async function handleSaveRtp() {
    setSavingRtp(true);
    setMessage("");
    const res = await saveRtpEngineSettings(rtp);
    setSavingRtp(false);
    setMessage(res.success ? "RTP engine settings saved." : `RTP error: ${res.error}`);
  }
  async function handleSaveMode() {
    setSavingMode(true);
    setMessage("");
    const res = await saveGameControlMode(mode);
    setSavingMode(false);
    setMessage(res.success ? "Engine mode saved." : `Mode error: ${res.error}`);
  }
  async function handleSaveAuto() {
    setSavingAuto(true);
    setMessage("");
    const res = await saveAutoSwitchSettings({
      enabled: auto.enabled,
      loss_coins: auto.loss_coins,
      recover_coins: auto.recover_coins,
      max_loss_coins: auto.max_loss_coins,
    });
    setSavingAuto(false);
    setMessage(res.success ? "Auto switch settings saved." : `Auto error: ${res.error}`);
  }
  async function handleSaveHouse() {
    setSavingHouse(true);
    setMessage("");
    const res = await saveHouseEdgeSettings(house);
    setSavingHouse(false);
    setMessage(res.success ? "House edge settings saved." : `House edge error: ${res.error}`);
  }
  async function handleToggleActive(game: Draft) {
    const next = !game.is_active;
    patchGame(game.id, { is_active: next });
    const res = await toggleGameActive(game.id, next);
    if (!res.success) {
      patchGame(game.id, { is_active: !next });
      setMessage(`Toggle failed: ${res.error}`);
    }
  }
  async function handleToggleMaintenance(game: Draft) {
    const next = !game.maintenance_mode;
    patchGame(game.id, { maintenance_mode: next });
    const res = await toggleGameMaintenance(game.id, next);
    if (!res.success) {
      patchGame(game.id, { maintenance_mode: !next });
      setMessage(`Maintenance toggle failed: ${res.error}`);
    }
  }
  async function handleUploadIcon(gameId: string, file: File) {
    setUploadingId(gameId);
    const fd = new FormData();
    fd.append("file", file);
    const res = await uploadGameIcon(fd);
    setUploadingId(null);
    if (res.success && res.url) {
      patchGame(gameId, { icon_url: res.url });
    } else {
      setMessage(`Icon upload failed: ${res.error}`);
    }
  }
  async function handleSaveGame(game: Draft) {
    setSavingId(game.id);
    setMessage("");
    const res = await upsertGameConfig({
      id: game.id,
      name: game.name,
      is_active: game.is_active,
      maintenance_mode: game.maintenance_mode,
      maintenance_message: game.maintenance_message,
      min_bet: game.min_bet,
      max_bet: game.max_bet,
      betting_duration_sec: game.betting_duration_sec,
      spinning_duration_sec: game.spinning_duration_sec,
      result_duration_sec: game.result_duration_sec,
      icon_url: game.icon_url,
      game_url: game.game_url,
      sort_order: game.sort_order,
      webview_height_percent: game.webview_height_percent,
      config_data_json: game.config_data_json,
      category_id: game.category_id,
    });
    setSavingId(null);
    if (res.success) {
      setMessage(`Saved ${game.name}.`);
      try {
        const parsed = JSON.parse(game.config_data_json || "{}");
        patchGame(game.id, { config_data: parsed });
      } catch {}
    } else {
      setMessage(`Save failed: ${res.error}`);
    }
  }
  return (
    <div className="space-y-8">
      {message && (
        <div className="glass-card border border-emerald-500/30 px-6 py-4 text-sm text-emerald-200 flex items-center gap-3">
          <CheckCircle2 size={18} />
          {message}
        </div>
      )}

      <section className="glass-card p-8 space-y-6 border-emerald-500/25">
        <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-2xl bg-emerald-500/20 border border-emerald-500/20 flex items-center justify-center text-emerald-300">
              <Gamepad2 size={22} />
            </div>
            <div>
              <h2 className="text-2xl font-black tracking-tight">RTP Wheel Engine</h2>
              <p className="text-white/50 text-sm mt-1 max-w-2xl">
                Inverse-multiplier probabilities, rolling bank smoothing, solvency exposure, and
                soft mercy. ON = v2 wheel. OFF = real legacy v1 (Random/House) kill-switch.
              </p>
            </div>
          </div>
          <div className="inline-flex rounded-xl border border-white/10 bg-black/40 p-1 shrink-0">
            <button
              type="button"
              onClick={() => patchRtp({ enabled: true })}
              className={`px-4 py-2 rounded-lg text-xs font-black uppercase tracking-wider transition ${rtp.enabled ? "bg-emerald-400 text-black" : "text-white/50 hover:text-white"}`}
            >
              ON (v2)
            </button>
            <button
              type="button"
              onClick={() => patchRtp({ enabled: false })}
              className={`px-4 py-2 rounded-lg text-xs font-black uppercase tracking-wider transition ${!rtp.enabled ? "bg-white text-black" : "text-white/50 hover:text-white"}`}
            >
              OFF (legacy v1)
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <Field label="Target RTP (e.g. 0.90 = 10% edge)">
            <input
              value={rtp.target_rtp}
              onChange={(e) => patchRtp({ target_rtp: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-emerald-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Bank alpha (0.30 gentle)">
            <input
              value={rtp.bank_alpha}
              onChange={(e) => patchRtp({ bank_alpha: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-emerald-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Exposure (default 12; pool×N + 20% bank)">
            <input
              value={rtp.max_round_exposure}
              onChange={(e) => patchRtp({ max_round_exposure: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-emerald-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Bank clamp min (k)">
            <input
              value={rtp.bank_clamp_min}
              onChange={(e) => patchRtp({ bank_clamp_min: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-emerald-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Bank clamp max (k)">
            <input
              value={rtp.bank_clamp_max}
              onChange={(e) => patchRtp({ bank_clamp_max: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-emerald-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Mercy streak (losses)">
            <input
              value={rtp.mercy_streak}
              onChange={(e) => patchRtp({ mercy_streak: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-emerald-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Mercy max multiplier">
            <input
              value={rtp.mercy_max_mult}
              onChange={(e) => patchRtp({ mercy_max_mult: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-emerald-400/50 font-mono text-sm"
            />
          </Field>
        </div>

        <p className="text-white/40 text-xs leading-relaxed max-w-3xl">
          Per-game override: set{" "}
          <code className="text-white/60">config_data.max_round_exposure</code> on a game (e.g.
          Lucky 777 = 3) to tighten solvency without changing the global default of 12. Kill-switch
          OFF routes to legacy <code className="text-white/60">resolve_game_winner_v1</code>.
        </p>

        <button
          type="button"
          onClick={handleSaveRtp}
          disabled={savingRtp}
          className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-black font-black disabled:opacity-50"
        >
          {savingRtp ? <Loader2 className="animate-spin" size={18} /> : <Save size={18} />}
          Save RTP engine
        </button>
      </section>

      <section className="glass-card p-8 space-y-6 opacity-60">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-violet-500/20 border border-violet-500/20 flex items-center justify-center text-violet-300">
            <Gamepad2 size={22} />
          </div>
          <div>
            <h2 className="text-2xl font-black tracking-tight">Legacy Engine Mode</h2>
            <p className="text-white/50 text-sm mt-1">
              Deprecated while RTP Wheel is ON. Kept only for emergency rollback.
            </p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <label
            className={`rounded-2xl border p-5 cursor-pointer transition-all ${
              mode === "random"
                ? "border-violet-400/60 bg-violet-500/10"
                : "border-white/10 bg-black/30"
            } ${auto.enabled ? "opacity-50 pointer-events-none" : ""}`}
          >
            <div className="flex items-center gap-3">
              <input
                type="radio"
                name="game_control_mode"
                checked={mode === "random"}
                onChange={() => setMode("random")}
              />
              <span className="font-bold">Random</span>
            </div>
            <p className="text-xs text-white/40 mt-2 pl-7">
              Fair-style weighted random outcomes based on config multipliers.
            </p>
          </label>

          <label
            className={`rounded-2xl border p-5 cursor-pointer transition-all ${
              mode === "house_optimized"
                ? "border-amber-400/60 bg-amber-500/10"
                : "border-white/10 bg-black/30"
            } ${auto.enabled ? "opacity-50 pointer-events-none" : ""}`}
          >
            <div className="flex items-center gap-3">
              <input
                type="radio"
                name="game_control_mode"
                checked={mode === "house_optimized"}
                onChange={() => setMode("house_optimized")}
              />
              <span className="font-bold">House Optimized</span>
            </div>
            <p className="text-xs text-white/40 mt-2 pl-7">
              Engine prefers outcomes that reduce platform payout risk.
            </p>
          </label>
        </div>

        <button
          type="button"
          onClick={handleSaveMode}
          disabled={savingMode || auto.enabled}
          className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-violet-500 hover:bg-violet-400 text-black font-black disabled:opacity-50"
        >
          {savingMode ? <Loader2 className="animate-spin" size={18} /> : <Save size={18} />}
          Save engine mode
        </button>
        {auto.enabled ? (
          <p className="text-xs text-amber-300/80">
            Auto is ON — manual Random/House is overridden each round from today&apos;s P&amp;L.
          </p>
        ) : null}
      </section>

      <section className="glass-card p-8 space-y-6 border-sky-500/20">
        <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
          <div>
            <h2 className="text-2xl font-black tracking-tight">Auto mode switch</h2>
            <p className="text-white/50 text-sm mt-1 max-w-2xl">
              When ON: today net &lt; −50M → House. Today net ≥ +100M profit → Random. Hard cap
              always blocks any outcome that would push today loss past 100M (even in Random).
            </p>
            {auto.last ? (
              <p className="text-[11px] text-white/35 mt-2 font-mono break-all">
                Last: {auto.last}
              </p>
            ) : null}
          </div>
          <div className="inline-flex rounded-xl border border-white/10 bg-black/40 p-1 shrink-0">
            <button
              type="button"
              onClick={() => patchAuto({ enabled: false })}
              className={`px-4 py-2 rounded-lg text-xs font-black uppercase tracking-wider transition ${!auto.enabled ? "bg-white text-black" : "text-white/50 hover:text-white"}`}
            >
              Manual
            </button>
            <button
              type="button"
              onClick={() => patchAuto({ enabled: true })}
              className={`px-4 py-2 rounded-lg text-xs font-black uppercase tracking-wider transition ${auto.enabled ? "bg-sky-400 text-black" : "text-white/50 hover:text-white"}`}
            >
              Auto
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <Field label="Loss → House (coins) — e.g. 50000000 = 50M">
            <input
              value={auto.loss_coins}
              onChange={(e) => patchAuto({ loss_coins: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-sky-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Profit → Random (coins) — e.g. 100000000 = 100M">
            <input
              value={auto.recover_coins}
              onChange={(e) => patchAuto({ recover_coins: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-sky-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Hard max loss (coins) — never cross — e.g. 100000000">
            <input
              value={auto.max_loss_coins}
              onChange={(e) => patchAuto({ max_loss_coins: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-sky-400/50 font-mono text-sm"
            />
          </Field>
        </div>

        <button
          type="button"
          onClick={handleSaveAuto}
          disabled={savingAuto}
          className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-sky-400 hover:bg-sky-300 text-black font-black disabled:opacity-50"
        >
          {savingAuto ? <Loader2 className="animate-spin" size={18} /> : <Save size={18} />}
          Save auto switch
        </button>
      </section>

      <section className="glass-card p-8 space-y-6 border-amber-500/20">
        <div>
          <h2 className="text-2xl font-black tracking-tight">House edge &amp; RTP cap</h2>
          <p className="text-white/50 text-sm mt-1 max-w-2xl">
            Platform loss only happens when a round pays more than the stake pool. These knobs keep
            payouts under the pool (max round RTP) while still giving players occasional safe wins.
            Forced jackpots are off by default.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <Field label="Target house edge (0.10 = 10%)">
            <input
              value={house.target_edge}
              onChange={(e) => patchHouse({ target_edge: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Max round RTP (hard cap, e.g. 0.95)">
            <input
              value={house.max_round_rtp}
              onChange={(e) => patchHouse({ max_round_rtp: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Pay-to-bets rate (0.40 ≈ 40% rounds pay someone)">
            <input
              value={house.pay_to_bets_rate}
              onChange={(e) => patchHouse({ pay_to_bets_rate: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Natural win rate (legacy fallback)">
            <input
              value={house.natural_win_rate}
              onChange={(e) => patchHouse({ natural_win_rate: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Soft edge rate">
            <input
              value={house.soft_edge_rate}
              onChange={(e) => patchHouse({ soft_edge_rate: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Daily loss breaker (coins, 0=off)">
            <input
              value={house.daily_loss_breaker}
              onChange={(e) => patchHouse({ daily_loss_breaker: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-sm"
            />
          </Field>
          <div className="rounded-xl border border-white/10 bg-black/30 px-4 py-3 flex items-center justify-between gap-3">
            <div>
              <p className="text-[10px] font-bold uppercase tracking-widest text-white/30">
                Big hit enabled
              </p>
              <p className="text-xs text-white/40 mt-1">Only if under RTP cap</p>
            </div>
            <Toggle
              label="Big hit"
              on={["1", "true", "yes", "on"].includes(house.big_hit_enabled.toLowerCase())}
              onClick={() =>
                patchHouse({
                  big_hit_enabled: ["1", "true", "yes", "on"].includes(
                    house.big_hit_enabled.toLowerCase(),
                  )
                    ? "false"
                    : "true",
                })
              }
              warn
            />
          </div>
          <Field label="Big hit every min rounds">
            <input
              value={house.big_hit_every_min}
              onChange={(e) => patchHouse({ big_hit_every_min: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Big hit every max rounds">
            <input
              value={house.big_hit_every_max}
              onChange={(e) => patchHouse({ big_hit_every_max: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Big hit min multiplier">
            <input
              value={house.big_hit_min_mult}
              onChange={(e) => patchHouse({ big_hit_min_mult: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-sm"
            />
          </Field>
          <Field label="Big hit attempt rate (when window open)">
            <input
              value={house.big_hit_rate}
              onChange={(e) => patchHouse({ big_hit_rate: e.target.value })}
              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-sm"
            />
          </Field>
        </div>

        <Field label="Outcome weights JSON (5x common → 45x rare)">
          <textarea
            value={house.outcome_weights}
            onChange={(e) => patchHouse({ outcome_weights: e.target.value })}
            rows={3}
            className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-amber-400/50 font-mono text-xs"
            spellCheck={false}
          />
          <p className="text-[10px] text-white/35 mt-2">
            Default {"{"}
            &quot;5&quot;:30,&quot;10&quot;:12,&quot;15&quot;:6,&quot;25&quot;:2,&quot;45&quot;:1
            {"}"} ≈ 85% / 8.5% / 4.3% / 1.4% / 0.7%. Only safe options (under max round RTP) are
            eligible.
          </p>
        </Field>

        <button
          type="button"
          onClick={handleSaveHouse}
          disabled={savingHouse}
          className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-amber-400 hover:bg-amber-300 text-black font-black disabled:opacity-50"
        >
          {savingHouse ? <Loader2 className="animate-spin" size={18} /> : <Save size={18} />}
          Save house edge settings
        </button>
      </section>

      <section className="space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-3 px-1">
          <h2 className="text-xl font-black tracking-tight">
            Games (
            {
              games.filter((g) => {
                if (providerFilter === "tulasi") return isTulasiGame(g);
                if (providerFilter === "baishun") return isBaishunGame(g);
                if (providerFilter === "native") return !isTulasiGame(g) && !isBaishunGame(g);
                return true;
              }).length
            }
            )
          </h2>
          <div className="flex gap-2">
            {(["all", "native", "baishun", "tulasi"] as ProviderFilter[]).map((f) => (
              <button
                key={f}
                type="button"
                onClick={() => setProviderFilter(f)}
                className={`px-3 py-1.5 rounded-lg text-[10px] font-black uppercase tracking-widest border ${
                  providerFilter === f
                    ? "bg-cyan-400/20 border-cyan-400/40 text-cyan-200"
                    : "bg-white/5 border-white/10 text-white/50 hover:bg-white/10"
                }`}
              >
                {f}
              </button>
            ))}
          </div>
        </div>

        {games
          .filter((g) => {
            if (providerFilter === "tulasi") return isTulasiGame(g);
            if (providerFilter === "baishun") return isBaishunGame(g);
            if (providerFilter === "native") return !isTulasiGame(g) && !isBaishunGame(g);
            return true;
          })
          .map((game) => {
            const open = expandedId === game.id;
            const tulasi = isTulasiGame(game);
            const baishun = isBaishunGame(game);
            return (
              <div key={game.id} className="glass-card overflow-hidden">
                <div className="p-5 flex flex-col lg:flex-row lg:items-center gap-4">
                  <div className="flex items-center gap-4 flex-1 min-w-0">
                    <div className="w-14 h-14 rounded-2xl bg-black/50 border border-white/10 overflow-hidden flex items-center justify-center shrink-0">
                      {game.icon_url ? (
                        <CdnImg
                          src={game.icon_url}
                          alt={game.name}
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        <Gamepad2 className="text-white/30" size={24} />
                      )}
                    </div>
                    <div className="min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <h3 className="font-black text-lg truncate">{game.name}</h3>
                        <span className="text-[10px] font-mono uppercase tracking-widest text-white/30">
                          {game.slug}
                        </span>
                        {tulasi && (
                          <span className="inline-flex items-center text-[10px] font-black uppercase tracking-widest text-cyan-300 bg-cyan-500/15 border border-cyan-500/30 px-2 py-0.5 rounded">
                            Tulasi
                          </span>
                        )}
                        {baishun && (
                          <span className="inline-flex items-center text-[10px] font-black uppercase tracking-widest text-orange-300 bg-orange-500/15 border border-orange-500/30 px-2 py-0.5 rounded">
                            Baishun
                          </span>
                        )}
                        {game.maintenance_mode && (
                          <span className="inline-flex items-center gap-1 text-[10px] font-black uppercase tracking-widest text-amber-300 bg-amber-500/15 border border-amber-500/30 px-2 py-0.5 rounded">
                            <Wrench size={10} /> Maintenance
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-white/40 truncate mt-1">
                        Order {game.sort_order}
                        {tulasi || baishun
                          ? ` · Sheet ${game.webview_height_percent ?? 70}%`
                          : ` · Bet ${game.min_bet}–${game.max_bet} · Sheet ${game.webview_height_percent ?? 70}%`}
                        {" · "}
                        {game.game_url || "no url"}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-3 flex-wrap">
                    <Toggle
                      label="Active"
                      on={game.is_active}
                      onClick={() => handleToggleActive(game)}
                    />
                    <Toggle
                      label="Maintenance"
                      on={game.maintenance_mode}
                      onClick={() => handleToggleMaintenance(game)}
                      warn
                    />
                    <GameAudienceButton
                      scope="game_config"
                      targetId={game.id}
                      label={`${game.name} (${game.slug})`}
                    />
                    <button
                      type="button"
                      onClick={() => setExpandedId(open ? null : game.id)}
                      className="px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-xs font-black uppercase tracking-widest hover:bg-white/10"
                    >
                      {open ? "Close" : "Edit"}
                    </button>
                  </div>
                </div>

                {open && (
                  <div className="border-t border-white/10 p-6 space-y-6 bg-black/20">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                      <Field label="Display name">
                        <input
                          value={game.name}
                          onChange={(e) => patchGame(game.id, { name: e.target.value })}
                          className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50"
                        />
                      </Field>
                      <Field label="Sort order">
                        <input
                          type="number"
                          value={game.sort_order}
                          onChange={(e) =>
                            patchGame(game.id, {
                              sort_order: parseInt(e.target.value || "0", 10),
                            })
                          }
                          className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50"
                        />
                      </Field>
                      <Field label="Room sheet category">
                        <select
                          value={game.category_id ?? ""}
                          onChange={(e) =>
                            patchGame(game.id, {
                              category_id: e.target.value || null,
                            })
                          }
                          className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50"
                        >
                          <option value="">Uncategorized</option>
                          {categories.map((c) => (
                            <option key={c.id} value={c.id}>
                              {c.name}
                            </option>
                          ))}
                        </select>
                      </Field>
                      {!tulasi && (
                        <>
                          <Field label="Min bet">
                            <input
                              type="number"
                              value={game.min_bet}
                              onChange={(e) =>
                                patchGame(game.id, {
                                  min_bet: parseInt(e.target.value || "0", 10),
                                })
                              }
                              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50"
                            />
                          </Field>
                          <Field label="Max bet">
                            <input
                              type="number"
                              value={game.max_bet}
                              onChange={(e) =>
                                patchGame(game.id, {
                                  max_bet: parseInt(e.target.value || "0", 10),
                                })
                              }
                              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50"
                            />
                          </Field>
                          <Field label="Betting duration (sec)">
                            <input
                              type="number"
                              value={game.betting_duration_sec}
                              onChange={(e) =>
                                patchGame(game.id, {
                                  betting_duration_sec: parseInt(e.target.value || "0", 10),
                                })
                              }
                              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50"
                            />
                          </Field>
                          <Field label="Spinning duration (sec)">
                            <input
                              type="number"
                              value={game.spinning_duration_sec}
                              onChange={(e) =>
                                patchGame(game.id, {
                                  spinning_duration_sec: parseInt(e.target.value || "0", 10),
                                })
                              }
                              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50"
                            />
                          </Field>
                          <Field label="Result duration (sec)">
                            <input
                              type="number"
                              value={game.result_duration_sec}
                              onChange={(e) =>
                                patchGame(game.id, {
                                  result_duration_sec: parseInt(e.target.value || "0", 10),
                                })
                              }
                              className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50"
                            />
                          </Field>
                        </>
                      )}
                      {tulasi && (
                        <Field label="Orientation (Tulasi WebView)">
                          <div className="pt-2">
                            <button
                              type="button"
                              onClick={() =>
                                patchGame(game.id, setLandscapeOnDraft(game, !readLandscape(game)))
                              }
                              className={`px-3 py-1 rounded-full text-xs font-black ${
                                readLandscape(game)
                                  ? "bg-amber-500/20 text-amber-300"
                                  : "bg-sky-500/20 text-sky-300"
                              }`}
                            >
                              {readLandscape(game) ? "LAND" : "PORT"}
                            </button>
                          </div>
                        </Field>
                      )}
                      <Field label="Maintenance message">
                        <input
                          value={game.maintenance_message}
                          onChange={(e) =>
                            patchGame(game.id, { maintenance_message: e.target.value })
                          }
                          className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50"
                        />
                      </Field>
                    </div>

                    <Field label="Game URL">
                      <div className="flex gap-2">
                        <input
                          value={game.game_url ?? ""}
                          onChange={(e) => patchGame(game.id, { game_url: e.target.value })}
                          className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50 font-mono text-xs"
                          placeholder="https://sk-live-games.vercel.app/..."
                        />
                        {game.game_url && (
                          <a
                            href={game.game_url}
                            target="_blank"
                            rel="noreferrer"
                            className="px-3 py-3 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10"
                          >
                            <ExternalLink size={16} />
                          </a>
                        )}
                      </div>
                    </Field>

                    <Field
                      label={`Room WebView height (${game.webview_height_percent ?? 70}% of screen)`}
                    >
                      <div className="space-y-2">
                        <input
                          type="range"
                          min={40}
                          max={95}
                          step={1}
                          value={game.webview_height_percent ?? 70}
                          onChange={(e) =>
                            patchGame(game.id, {
                              webview_height_percent: parseInt(e.target.value || "70", 10),
                            })
                          }
                          className="w-full accent-violet-400"
                        />
                        <div className="flex items-center gap-3">
                          <input
                            type="number"
                            min={40}
                            max={95}
                            value={game.webview_height_percent ?? 70}
                            onChange={(e) =>
                              patchGame(game.id, {
                                webview_height_percent: Math.min(
                                  95,
                                  Math.max(40, parseInt(e.target.value || "70", 10) || 70),
                                ),
                              })
                            }
                            className="w-24 bg-black/40 border border-white/10 rounded-xl px-3 py-2 focus:outline-none focus:border-violet-400/50"
                          />
                          <p className="text-[11px] text-white/40">
                            Short games ~55–65%. Tall / full cabinet ~75–90%. Default 70.
                          </p>
                        </div>
                      </div>
                    </Field>

                    <Field label="Icon URL">
                      <div className="flex gap-2">
                        <input
                          value={game.icon_url ?? ""}
                          onChange={(e) => patchGame(game.id, { icon_url: e.target.value })}
                          className="flex-1 bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50 font-mono text-xs"
                        />
                        <button
                          type="button"
                          disabled={uploadingId === game.id}
                          onClick={() => fileRefs.current[game.id]?.click()}
                          className="px-3 py-3 rounded-xl bg-white/5 border border-white/10 hover:bg-white/10"
                        >
                          {uploadingId === game.id ? (
                            <Loader2 size={16} className="animate-spin" />
                          ) : (
                            <Upload size={16} />
                          )}
                        </button>
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          ref={(el) => {
                            fileRefs.current[game.id] = el;
                          }}
                          onChange={(e) => {
                            const f = e.target.files?.[0];
                            if (f) void handleUploadIcon(game.id, f);
                            e.target.value = "";
                          }}
                        />
                      </div>
                    </Field>

                    <Field label="Advanced config_data (JSON)">
                      <textarea
                        value={game.config_data_json}
                        onChange={(e) => patchGame(game.id, { config_data_json: e.target.value })}
                        rows={12}
                        className="w-full bg-black/40 border border-white/10 rounded-xl px-4 py-3 focus:outline-none focus:border-violet-400/50 font-mono text-xs leading-relaxed"
                        spellCheck={false}
                      />
                      <p className="text-[10px] text-white/30 mt-2">
                        Edit multipliers / options / teen_patti boots carefully. Invalid JSON blocks
                        save.
                      </p>
                    </Field>

                    <button
                      type="button"
                      onClick={() => handleSaveGame(game)}
                      disabled={savingId === game.id}
                      className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-amber-400 hover:bg-amber-300 text-black font-black disabled:opacity-50"
                    >
                      {savingId === game.id ? (
                        <Loader2 className="animate-spin" size={18} />
                      ) : (
                        <Save size={18} />
                      )}
                      Save {game.name}
                    </button>
                  </div>
                )}
              </div>
            );
          })}
      </section>
    </div>
  );
}
function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="space-y-2">
      <label className="text-[10px] font-bold uppercase tracking-widest text-white/30 px-1">
        {label}
      </label>
      {children}
    </div>
  );
}
function Toggle({
  label,
  on,
  onClick,
  warn,
}: {
  label: string;
  on: boolean;
  onClick: () => void;
  warn?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`px-3 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest border transition-all ${
        on
          ? warn
            ? "bg-amber-500/20 border-amber-400/40 text-amber-200"
            : "bg-emerald-500/20 border-emerald-400/40 text-emerald-200"
          : "bg-white/5 border-white/10 text-white/40"
      }`}
    >
      {label}: {on ? "ON" : "OFF"}
    </button>
  );
}
