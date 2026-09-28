"use server";
import { supabaseAdmin } from "@/lib/supabase";
export type GameLogOption = {
  id: string;
  slug: string;
  name: string;
};
export type GameLogFilters = {
  gameSlug?: string | null;
  outcome?: "all" | "win" | "loss" | null;
  userQ?: string | null;
  range?: "today" | "7d" | "30d" | "all" | "custom" | null;
  from?: string | null;
  to?: string | null;
  minStake?: number | null;
  roundNumber?: number | null;
};
export type GameBetLogRow = {
  id: string;
  user_id: string;
  round_id: string;
  bet_option: string;
  amount: number;
  payout_amount: number;
  is_win: boolean;
  is_processed: boolean;
  created_at: string;
  username: string;
  short_id: number;
  balance_coins: number;
  round_number: number;
  winner_result: string | null;
  round_status: string;
  game_id: string;
  game_slug: string;
  game_name: string;
  wins_in_filter?: number;
};
export type GameLogsSummary = {
  total_stake: number;
  total_payout: number;
  net: number;
  win_count: number;
  loss_count: number;
  unique_players: number;
  by_game: {
    game_slug: string;
    game_name: string;
    stake: number;
    payout: number;
    bets: number;
  }[];
  by_user: {
    user_id: string;
    username: string;
    short_id: number;
    balance_coins: number;
    stake: number;
    payout: number;
    wins: number;
    losses: number;
    bets: number;
  }[];
  wins_by_user: Record<string, number>;
};
export type GameBetLogCursor = {
  created_at: string;
  id: string;
};
function startOfTodayUtc(): Date {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d;
}
function resolveDateRange(filters: GameLogFilters): {
  from: string | null;
  to: string | null;
} {
  const range = filters.range || "7d";
  if (range === "all") return { from: null, to: null };
  if (range === "custom") {
    return {
      from: filters.from || null,
      to: filters.to || null,
    };
  }
  const to = new Date();
  let from = new Date(to);
  if (range === "today") {
    from = startOfTodayUtc();
  } else if (range === "30d") {
    from.setUTCDate(from.getUTCDate() - 30);
  } else {
    from.setUTCDate(from.getUTCDate() - 7);
  }
  return { from: from.toISOString(), to: to.toISOString() };
}
function rpcFilters(filters: GameLogFilters) {
  const { from, to } = resolveDateRange(filters);
  return {
    p_game_slug: filters.gameSlug && filters.gameSlug !== "all" ? filters.gameSlug : null,
    p_outcome: filters.outcome && filters.outcome !== "all" ? filters.outcome : "all",
    p_user_q: filters.userQ?.trim() || null,
    p_from: from,
    p_to: to,
    p_min_stake:
      filters.minStake != null && Number.isFinite(filters.minStake) && filters.minStake > 0
        ? Math.floor(filters.minStake)
        : null,
    p_round_number:
      filters.roundNumber != null && Number.isFinite(filters.roundNumber)
        ? Math.floor(filters.roundNumber)
        : null,
  };
}
export async function listGameLogOptions(): Promise<GameLogOption[]> {
  const { data, error } = await supabaseAdmin
    .from("game_configs")
    .select("id, slug, name")
    .order("sort_order", { ascending: true });
  if (error) throw new Error(error.message);
  return (data || []) as GameLogOption[];
}
export async function getGameLogsSummary(filters: GameLogFilters): Promise<GameLogsSummary> {
  const params = rpcFilters(filters);
  const { data, error } = await supabaseAdmin.rpc("admin_game_bet_logs_summary", params);
  if (error) throw new Error(error.message);
  const raw = (data || {}) as GameLogsSummary;
  return {
    total_stake: Number(raw.total_stake) || 0,
    total_payout: Number(raw.total_payout) || 0,
    net: Number(raw.net) || 0,
    win_count: Number(raw.win_count) || 0,
    loss_count: Number(raw.loss_count) || 0,
    unique_players: Number(raw.unique_players) || 0,
    by_game: Array.isArray(raw.by_game) ? raw.by_game : [],
    by_user: Array.isArray(raw.by_user) ? raw.by_user : [],
    wins_by_user: raw.wins_by_user && typeof raw.wins_by_user === "object" ? raw.wins_by_user : {},
  };
}
export async function listGameBetLogs(
  filters: GameLogFilters,
  cursor?: GameBetLogCursor | null,
  limit = 40,
  winsByUser?: Record<string, number> | null,
): Promise<{
  rows: GameBetLogRow[];
  hasMore: boolean;
}> {
  const base = rpcFilters(filters);
  const { data, error } = await supabaseAdmin.rpc("admin_list_game_bet_logs", {
    ...base,
    p_cursor_created_at: cursor?.created_at ?? null,
    p_cursor_id: cursor?.id ?? null,
    p_limit: limit,
  });
  if (error) throw new Error(error.message);
  const payload = (data || { rows: [], has_more: false }) as {
    rows: GameBetLogRow[];
    has_more: boolean;
  };
  const winsMap = winsByUser || {};
  const rows = (payload.rows || []).map((r) => ({
    ...r,
    amount: Number(r.amount) || 0,
    payout_amount: Number(r.payout_amount) || 0,
    balance_coins: Number(r.balance_coins) || 0,
    short_id: Number(r.short_id) || 0,
    round_number: Number(r.round_number) || 0,
    wins_in_filter: Number(winsMap[r.user_id] || 0),
  }));
  return { rows, hasMore: !!payload.has_more };
}
export async function loadGameLogsPage(filters: GameLogFilters, limit = 40) {
  const [games, summary] = await Promise.all([listGameLogOptions(), getGameLogsSummary(filters)]);
  const page = await listGameBetLogs(filters, null, limit, summary.wins_by_user);
  return { games, summary, ...page };
}
