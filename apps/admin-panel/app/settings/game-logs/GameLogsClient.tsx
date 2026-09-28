"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, useTransition } from "react";
import { AmountValue } from "@/components/AmountValue";
import {
  listGameBetLogs,
  type GameBetLogRow,
  type GameLogFilters,
  type GameLogOption,
  type GameLogsSummary,
} from "@/app/settings/game-logs/actions";
import { saveAutoSwitchSettings, saveGameControlMode } from "@/app/settings/game-control/actions";
function buildHref(base: GameLogFilters, patch: Partial<GameLogFilters>) {
  const next = { ...base, ...patch };
  const params = new URLSearchParams();
  if (next.gameSlug && next.gameSlug !== "all") params.set("game", next.gameSlug);
  if (next.outcome && next.outcome !== "all") params.set("outcome", next.outcome);
  if (next.userQ?.trim()) params.set("q", next.userQ.trim());
  if (next.range && next.range !== "7d") params.set("range", next.range);
  if (next.range === "custom") {
    if (next.from) params.set("from", next.from);
    if (next.to) params.set("to", next.to);
  }
  if (next.minStake && next.minStake > 0) params.set("minStake", String(next.minStake));
  if (next.roundNumber) params.set("round", String(next.roundNumber));
  const qs = params.toString();
  return qs ? `/settings/game-logs?${qs}` : "/settings/game-logs";
}
export function GameLogsClient({
  games,
  summary,
  initialRows,
  initialHasMore,
  filters,
  initialEngineMode,
  initialAutoEnabled,
  initialAutoLast,
  initialAutoLossCoins,
  initialAutoRecoverCoins,
  initialAutoMaxLossCoins,
}: {
  games: GameLogOption[];
  summary: GameLogsSummary;
  initialRows: GameBetLogRow[];
  initialHasMore: boolean;
  filters: GameLogFilters;
  initialEngineMode: string;
  initialAutoEnabled: boolean;
  initialAutoLast: string;
  initialAutoLossCoins: string;
  initialAutoRecoverCoins: string;
  initialAutoMaxLossCoins: string;
}) {
  const router = useRouter();
  const [rows, setRows] = useState(initialRows);
  const [hasMore, setHasMore] = useState(initialHasMore);
  const [pending, startTransition] = useTransition();
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState("");
  const [engineMode, setEngineMode] = useState(
    initialEngineMode === "house_optimized" ? "house_optimized" : "random",
  );
  const [autoEnabled, setAutoEnabled] = useState(initialAutoEnabled);
  const [autoLast, setAutoLast] = useState(initialAutoLast);
  const [autoLossCoins, setAutoLossCoins] = useState(initialAutoLossCoins);
  const [autoRecoverCoins, setAutoRecoverCoins] = useState(initialAutoRecoverCoins);
  const [autoMaxLossCoins, setAutoMaxLossCoins] = useState(initialAutoMaxLossCoins);
  const [savingMode, setSavingMode] = useState(false);
  const [savingAuto, setSavingAuto] = useState(false);
  const [modeMessage, setModeMessage] = useState("");
  useEffect(() => {
    setRows(initialRows);
    setHasMore(initialHasMore);
  }, [initialRows, initialHasMore]);
  useEffect(() => {
    setEngineMode(initialEngineMode === "house_optimized" ? "house_optimized" : "random");
  }, [initialEngineMode]);
  useEffect(() => {
    setAutoEnabled(initialAutoEnabled);
    setAutoLast(initialAutoLast);
    setAutoLossCoins(initialAutoLossCoins);
    setAutoRecoverCoins(initialAutoRecoverCoins);
    setAutoMaxLossCoins(initialAutoMaxLossCoins);
  }, [
    initialAutoEnabled,
    initialAutoLast,
    initialAutoLossCoins,
    initialAutoRecoverCoins,
    initialAutoMaxLossCoins,
  ]);
  async function onToggleEngineMode(next: "random" | "house_optimized") {
    if (autoEnabled || next === engineMode || savingMode) return;
    const prev = engineMode;
    setEngineMode(next);
    setSavingMode(true);
    setModeMessage("");
    const res = await saveGameControlMode(next);
    setSavingMode(false);
    if (!res.success) {
      setEngineMode(prev);
      setModeMessage(res.error || "Failed to save mode");
      return;
    }
    setModeMessage(next === "house_optimized" ? "House mode ON" : "Random mode ON");
    router.refresh();
  }
  async function onToggleAuto(next: boolean) {
    if (next === autoEnabled || savingAuto) return;
    const prev = autoEnabled;
    setAutoEnabled(next);
    setSavingAuto(true);
    setModeMessage("");
    const res = await saveAutoSwitchSettings({
      enabled: next,
      loss_coins: autoLossCoins,
      recover_coins: autoRecoverCoins,
      max_loss_coins: autoMaxLossCoins,
    });
    setSavingAuto(false);
    if (!res.success) {
      setAutoEnabled(prev);
      setModeMessage(res.error || "Failed to save auto");
      return;
    }
    setModeMessage(next ? "Auto switch ON" : "Manual mode ON");
    router.refresh();
  }
  function go(patch: Partial<GameLogFilters>) {
    startTransition(() => {
      router.push(buildHref(filters, patch));
    });
  }
  async function onLoadMore() {
    if (!hasMore || loadingMore || rows.length === 0) return;
    const last = rows[rows.length - 1];
    setLoadingMore(true);
    setError("");
    try {
      const page = await listGameBetLogs(
        filters,
        { created_at: last.created_at, id: last.id },
        40,
        summary.wins_by_user,
      );
      setRows((prev) => [...prev, ...page.rows]);
      setHasMore(page.hasMore);
    } catch (e: any) {
      setError(e?.message || "Failed to load more");
    } finally {
      setLoadingMore(false);
    }
  }
  const range = filters.range || "7d";
  const selectedUser = filters.userQ?.trim() ? summary.by_user[0] : null;
  const selectedUserNet = selectedUser
    ? Number(selectedUser.payout) - Number(selectedUser.stake)
    : 0;
  const stake = Number(summary.total_stake) || 0;
  const payout = Number(summary.total_payout) || 0;
  const bets = (summary.win_count || 0) + (summary.loss_count || 0);
  const houseProfit = Math.max(0, stake - payout);
  const platformLoss = Math.max(0, payout - stake);
  const playerPool = Math.min(stake, payout);
  const houseEdgePct = stake > 0 ? ((stake - payout) / stake) * 100 : 0;
  const rtpPct = stake > 0 ? (payout / stake) * 100 : 0;
  const winRatePct = bets > 0 ? (summary.win_count / bets) * 100 : 0;
  return (
    <div className={`space-y-8 ${pending ? "opacity-70" : ""}`}>
      <div className="glass-card p-5 border-violet-500/20 space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-white/40">
              Engine mode
            </p>
            <p className="text-sm text-white/55 mt-1 max-w-xl">
              Manual: pick Random/House here. Auto: loss → House, recover → Random (today P&amp;L).
            </p>
            {autoLast ? (
              <p className="text-[10px] text-white/30 mt-1 font-mono break-all">
                Last auto: {autoLast}
              </p>
            ) : null}
            {modeMessage ? (
              <p className="text-xs text-violet-300 mt-2 font-medium">{modeMessage}</p>
            ) : null}
          </div>
          <div className="flex flex-col items-stretch sm:items-end gap-2 shrink-0">
            <div className="inline-flex rounded-xl border border-white/10 bg-black/40 p-1">
              <button
                type="button"
                disabled={savingAuto}
                onClick={() => onToggleAuto(false)}
                className={`px-4 py-2 rounded-lg text-xs font-black uppercase tracking-wider transition ${!autoEnabled ? "bg-white text-black" : "text-white/50 hover:text-white"} disabled:opacity-50`}
              >
                Manual
              </button>
              <button
                type="button"
                disabled={savingAuto}
                onClick={() => onToggleAuto(true)}
                className={`px-4 py-2 rounded-lg text-xs font-black uppercase tracking-wider transition ${autoEnabled ? "bg-sky-400 text-black" : "text-white/50 hover:text-white"} disabled:opacity-50`}
              >
                Auto
              </button>
            </div>
            <div className="inline-flex rounded-xl border border-white/10 bg-black/40 p-1">
              <button
                type="button"
                disabled={savingMode || autoEnabled}
                onClick={() => onToggleEngineMode("random")}
                className={`px-4 py-2 rounded-lg text-xs font-black uppercase tracking-wider transition ${
                  engineMode === "random"
                    ? "bg-sky-400 text-black"
                    : "text-white/50 hover:text-white"
                } disabled:opacity-50`}
              >
                Random
              </button>
              <button
                type="button"
                disabled={savingMode || autoEnabled}
                onClick={() => onToggleEngineMode("house_optimized")}
                className={`px-4 py-2 rounded-lg text-xs font-black uppercase tracking-wider transition ${
                  engineMode === "house_optimized"
                    ? "bg-amber-400 text-black"
                    : "text-white/50 hover:text-white"
                } disabled:opacity-50`}
              >
                House
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
        <Kpi label="Total stake" value={stake} accent="text-white" />
        <Kpi label="Total payout" value={payout} accent="text-emerald-300" />
        <Kpi
          label={platformLoss > 0 ? "Platform loss" : "House profit"}
          value={platformLoss > 0 ? platformLoss : houseProfit}
          accent={platformLoss > 0 ? "text-red-300" : "text-amber-300"}
        />
        <Kpi label="Wins / Losses" value={`${summary.win_count} / ${summary.loss_count}`} />
        <Kpi label="Players" value={summary.unique_players} />
      </div>

      <div className="glass-card p-5 space-y-4 border-amber-500/20">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-white/40">
              Platform P&L (filter window)
            </p>
            <p className="text-sm text-white/50 mt-1 max-w-2xl">
              Player → player wins from the stake pool are not platform loss. Platform loss only
              when payouts exceed stakes (paid from house pocket).
            </p>
          </div>
          <p
            className={`text-sm font-black tabular-nums ${houseEdgePct >= 0 ? "text-amber-300" : "text-red-300"}`}
          >
            House edge {fmtPct(houseEdgePct, { signed: true })}
          </p>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
          <MiniStat
            label="House edge"
            value={fmtPct(houseEdgePct, { signed: true })}
            accent={houseEdgePct >= 0 ? "text-amber-300" : "text-red-300"}
          />
          <MiniStat label="RTP" value={fmtPct(rtpPct)} accent="text-sky-300" />
          <MiniStat label="Bet win rate" value={fmtPct(winRatePct)} />
          <MiniStat
            label="Player pool → wins"
            value={playerPool.toLocaleString()}
            accent="text-violet-300"
          />
          <MiniStat
            label="House profit"
            value={houseProfit.toLocaleString()}
            accent="text-amber-300"
          />
          <MiniStat
            label="Platform loss (pocket)"
            value={platformLoss.toLocaleString()}
            accent={platformLoss > 0 ? "text-red-300" : "text-white/50"}
          />
        </div>

        <div className="rounded-xl border border-white/10 bg-black/25 px-4 py-3 space-y-2 text-xs text-white/55">
          <p>
            <span className="text-violet-300 font-bold">Player pool</span>
            {" = "}
            {playerPool.toLocaleString()} — amount of winning payouts covered by other players’
            stakes (redistribution, not house loss).
          </p>
          <p>
            <span className="text-amber-300 font-bold">House profit</span>
            {" = "}
            {houseProfit.toLocaleString()} — stake left after paying winners (platform keeps).
          </p>
          <p>
            <span className="text-red-300 font-bold">Platform loss</span>
            {" = "}
            {platformLoss.toLocaleString()} — only when payout &gt; stake; paid from platform
            pocket.
          </p>
        </div>
      </div>

      {summary.by_game.length > 0 && (
        <div className="glass-card p-5 space-y-3">
          <p className="text-[10px] font-black uppercase tracking-widest text-white/40">
            By game (filter window)
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {summary.by_game.map((g) => {
              const gStake = Number(g.stake) || 0;
              const gPayout = Number(g.payout) || 0;
              const gNet = gStake - gPayout;
              const gEdge = gStake > 0 ? (gNet / gStake) * 100 : 0;
              const gRtp = gStake > 0 ? (gPayout / gStake) * 100 : 0;
              const gHouseLoss = Math.max(0, gPayout - gStake);
              const gHouseProfit = Math.max(0, gStake - gPayout);
              return (
                <button
                  key={g.game_slug}
                  type="button"
                  onClick={() => go({ gameSlug: g.game_slug })}
                  className="text-left rounded-xl border border-white/10 bg-black/30 px-4 py-3 hover:border-violet-500/40 transition"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <p className="font-bold truncate">{g.game_name}</p>
                      <p className="text-[10px] text-white/40 font-mono">{g.game_slug}</p>
                    </div>
                    <span
                      className={`text-[10px] font-black tabular-nums shrink-0 ${gEdge >= 0 ? "text-amber-300" : "text-red-300"}`}
                    >
                      {fmtPct(gEdge, { signed: true })} edge
                    </span>
                  </div>
                  <p className="text-xs text-white/60 mt-2">
                    Stake {gStake.toLocaleString()} · Payout {gPayout.toLocaleString()} · {g.bets}{" "}
                    bets
                  </p>
                  <p className="text-xs mt-1">
                    <span className="text-sky-300">RTP {fmtPct(gRtp)}</span>
                    <span className="text-white/30"> · </span>
                    {gHouseLoss > 0 ? (
                      <span className="text-red-300">
                        Platform loss {gHouseLoss.toLocaleString()}
                      </span>
                    ) : (
                      <span className="text-amber-300">House +{gHouseProfit.toLocaleString()}</span>
                    )}
                  </p>
                </button>
              );
            })}
          </div>
        </div>
      )}

      <div className="glass-card p-5 space-y-4 border-violet-500/20">
        <div className="flex flex-wrap gap-2">
          <Chip
            active={!filters.gameSlug || filters.gameSlug === "all"}
            onClick={() => go({ gameSlug: "all" })}
          >
            All games
          </Chip>
          {games.map((g) => (
            <Chip
              key={g.id}
              active={filters.gameSlug === g.slug}
              onClick={() => go({ gameSlug: g.slug })}
            >
              {g.name}
            </Chip>
          ))}
        </div>

        <div className="flex flex-wrap gap-2">
          {(["all", "win", "loss"] as const).map((o) => (
            <Chip
              key={o}
              active={(filters.outcome || "all") === o}
              onClick={() => go({ outcome: o })}
            >
              {o === "all" ? "All outcomes" : o === "win" ? "Wins" : "Losses"}
            </Chip>
          ))}
        </div>

        <div className="flex flex-wrap gap-2">
          {(
            [
              ["today", "Today"],
              ["7d", "7 days"],
              ["30d", "30 days"],
              ["all", "All time"],
            ] as const
          ).map(([id, label]) => (
            <Chip key={id} active={range === id} onClick={() => go({ range: id })}>
              {label}
            </Chip>
          ))}
        </div>

        <div className="flex flex-col sm:flex-row gap-3 flex-wrap">
          <input
            defaultValue={filters.userQ || ""}
            key={filters.userQ || "q"}
            placeholder="User short ID or username — Enter to search"
            className="flex-1 min-w-[200px] rounded-xl bg-black/40 border border-white/10 px-4 py-2.5 text-sm outline-none focus:border-violet-500/40"
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                go({ userQ: (e.target as HTMLInputElement).value });
              }
            }}
          />
          <input
            defaultValue={filters.minStake ? String(filters.minStake) : ""}
            key={`min-${filters.minStake || 0}`}
            type="number"
            placeholder="Min stake"
            className="w-36 rounded-xl bg-black/40 border border-white/10 px-4 py-2.5 text-sm"
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                const n = Number((e.target as HTMLInputElement).value);
                go({ minStake: Number.isFinite(n) && n > 0 ? n : null });
              }
            }}
          />
          <input
            defaultValue={filters.roundNumber ? String(filters.roundNumber) : ""}
            key={`rnd-${filters.roundNumber || 0}`}
            type="number"
            placeholder="Round #"
            className="w-36 rounded-xl bg-black/40 border border-white/10 px-4 py-2.5 text-sm"
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                const n = Number((e.target as HTMLInputElement).value);
                go({ roundNumber: Number.isFinite(n) && n > 0 ? n : null });
              }
            }}
          />
        </div>
      </div>

      {selectedUser &&
        (() => {
          const uStake = Number(selectedUser.stake) || 0;
          const uPayout = Number(selectedUser.payout) || 0;
          const uBets = (selectedUser.wins || 0) + (selectedUser.losses || 0);
          const uWinRate = uBets > 0 ? (selectedUser.wins / uBets) * 100 : 0;
          const uRoi = uStake > 0 ? (selectedUserNet / uStake) * 100 : 0;
          return (
            <div className="glass-card p-5 border-violet-500/25 space-y-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-[10px] font-black uppercase tracking-widest text-white/40">
                    User overview
                  </p>
                  <p className="text-xl font-black mt-1">
                    {selectedUser.username}{" "}
                    <span className="text-sm font-mono text-white/40">
                      #{selectedUser.short_id}
                    </span>
                  </p>
                  <p className="text-xs text-white/45 mt-1">
                    User win/loss is personal P&amp;L — not the same as platform loss. Their losses
                    fund the player pool for other winners.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => go({ userQ: "" })}
                  className="text-[10px] font-black uppercase tracking-widest text-violet-300 hover:underline shrink-0"
                >
                  Clear
                </button>
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
                <MiniStat label="Stake" value={uStake.toLocaleString()} />
                <MiniStat label="Won" value={uPayout.toLocaleString()} accent="text-emerald-300" />
                <MiniStat
                  label="User net"
                  value={`${selectedUserNet >= 0 ? "+" : ""}${selectedUserNet.toLocaleString()}`}
                  accent={selectedUserNet >= 0 ? "text-emerald-300" : "text-red-300"}
                />
                <MiniStat
                  label="ROI"
                  value={fmtPct(uRoi, { signed: true })}
                  accent={uRoi >= 0 ? "text-emerald-300" : "text-red-300"}
                />
                <MiniStat
                  label="Win rate"
                  value={`${fmtPct(uWinRate)} (${selectedUser.wins}/${uBets})`}
                />
                <MiniStat
                  label="Balance"
                  value={Number(selectedUser.balance_coins).toLocaleString()}
                  accent="text-amber-300"
                />
              </div>
            </div>
          );
        })()}

      {error && (
        <div className="rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300">
          {error}
        </div>
      )}

      <div className="space-y-3">
        <p className="text-[10px] font-black uppercase tracking-widest text-white/30">
          Bets · {rows.length}
          {hasMore ? "+" : ""}
        </p>
        {rows.length === 0 ? (
          <div className="glass-card p-10 text-center text-white/40">
            No bets for these filters.
          </div>
        ) : (
          rows.map((row) => <BetRow key={row.id} row={row} />)
        )}

        {hasMore && (
          <button
            type="button"
            onClick={onLoadMore}
            disabled={loadingMore}
            className="w-full py-4 rounded-2xl border border-violet-500/30 bg-violet-500/10 text-violet-200 font-black text-sm uppercase tracking-widest hover:bg-violet-500/20 disabled:opacity-50"
          >
            {loadingMore ? "Loading…" : "Load more"}
          </button>
        )}
      </div>
    </div>
  );
}
function fmtPct(
  n: number,
  opts?: {
    signed?: boolean;
  },
) {
  if (!Number.isFinite(n)) return "0.00%";
  if (opts?.signed) {
    const sign = n > 0 ? "+" : "";
    return `${sign}${n.toFixed(2)}%`;
  }
  return `${n.toFixed(2)}%`;
}
function Kpi({
  label,
  value,
  accent = "text-white",
}: {
  label: string;
  value: number | string;
  accent?: string;
}) {
  return (
    <div className="glass-card p-4 min-w-0 overflow-hidden">
      <p className="text-[9px] font-black uppercase tracking-widest text-white/30 mb-1">{label}</p>
      {typeof value === "number" ? (
        <AmountValue value={value} size="sm" className={accent} />
      ) : (
        <p className={`font-black tabular-nums ${accent}`}>{value}</p>
      )}
    </div>
  );
}
function MiniStat({
  label,
  value,
  accent = "text-white",
}: {
  label: string;
  value: string;
  accent?: string;
}) {
  return (
    <div className="rounded-xl border border-white/10 bg-black/30 px-3 py-3 min-w-0">
      <p className="text-[9px] font-black uppercase tracking-widest text-white/30">{label}</p>
      <p className={`mt-1 text-sm font-black tabular-nums truncate ${accent}`}>{value}</p>
    </div>
  );
}
function Chip({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`px-3 py-1.5 rounded-xl text-[10px] font-black uppercase tracking-widest border transition ${
        active
          ? "bg-violet-500/20 border-violet-400/40 text-violet-200"
          : "bg-white/5 border-white/10 text-white/50 hover:text-white"
      }`}
    >
      {children}
    </button>
  );
}
function BetRow({ row }: { row: GameBetLogRow }) {
  const net = row.payout_amount - row.amount;
  const when = new Date(row.created_at).toLocaleString();
  return (
    <div className="glass-card p-4 md:p-5 space-y-3">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <Link
            href={`/users/${row.user_id}`}
            className="font-bold text-lg hover:text-violet-200 transition"
          >
            {row.username} <span className="text-white/40 text-sm font-mono">#{row.short_id}</span>
          </Link>
          <p className="text-xs text-white/40 mt-1">
            {row.game_name} · Round {row.round_number}
            {row.winner_result ? ` · Winner ${row.winner_result}` : ""}
          </p>
          <p className="text-[10px] text-white/30 mt-1">{when}</p>
        </div>
        <span
          className={`text-[10px] font-black uppercase tracking-widest px-3 py-1 rounded-full ${
            row.is_win ? "bg-emerald-500/20 text-emerald-300" : "bg-red-500/20 text-red-300"
          }`}
        >
          {row.is_win ? "Win" : "Loss"}
        </span>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">
        <div>
          <p className="text-[9px] uppercase tracking-widest text-white/30">Option</p>
          <p className="font-semibold truncate">{row.bet_option}</p>
        </div>
        <div className="min-w-0">
          <p className="text-[9px] uppercase tracking-widest text-white/30">Stake</p>
          <AmountValue value={row.amount} size="sm" className="text-white" />
        </div>
        <div className="min-w-0">
          <p className="text-[9px] uppercase tracking-widest text-white/30">Payout credited</p>
          <AmountValue
            value={row.payout_amount}
            size="sm"
            className={row.is_win ? "text-emerald-300" : "text-white/40"}
          />
        </div>
        <div className="min-w-0">
          <p className="text-[9px] uppercase tracking-widest text-white/30">Net</p>
          <AmountValue
            value={net}
            size="sm"
            className={net >= 0 ? "text-emerald-300" : "text-red-300"}
          />
        </div>
        <div className="min-w-0">
          <p className="text-[9px] uppercase tracking-widest text-white/30">Balance then</p>
          <AmountValue value={row.balance_coins} size="sm" className="text-amber-300" />
        </div>
      </div>

      {row.is_win && (row.wins_in_filter || 0) > 0 && (
        <p className="text-xs text-emerald-300/80">
          Wins in this filter for user:{" "}
          <span className="font-black tabular-nums">
            {(row.wins_in_filter || 0).toLocaleString()}
          </span>{" "}
          coins credited (sum of payouts)
        </p>
      )}
    </div>
  );
}
