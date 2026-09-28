import { supabase } from "./supabase";

export const DEFAULT_RULES = `1. Only the specified gifts received will be counted for points. All other gifts are invalid.
2. Receiving a specified gift awards the points shown under that gift.
3. The points are updated in real time. The final ranking is based on the list at the end of the event.
4. After the event ends, the system will automatically send the rewards.`;

export type EventRow = {
  id: string;
  title: string;
  subtitle: string | null;
  start_at: string | null;
  end_at: string | null;
  action_config: Record<string, unknown>;
};

export type RankRow = {
  user_id: string;
  username: string | null;
  avatar_url: string | null;
  short_id: string | null;
  score: number;
  rank: number;
};

export type GiftItem = {
  id: string;
  name: string;
  imageUrl: string;
  points: number;
};

export type RewardItem = { label: string; imageUrl: string };
export type RewardSlots = {
  rank1Label: string;
  rank1Items: RewardItem[];
  rank2Label: string;
  rank2Items: RewardItem[];
  rank3Label: string;
  rank3Items: RewardItem[];
  rank4to10Label: string;
  rank4to10Items: RewardItem[];
};

export function formatScore(score: number): string {
  if (score >= 1_000_000) return `${(score / 1_000_000).toFixed(2)}M`;
  if (score >= 1_000) return `${(score / 1_000).toFixed(1)}K`;
  return String(score);
}

export function readEventIdFromSearch(search: string): string | null {
  try {
    const id = new URLSearchParams(search).get("event_id")?.trim();
    return id || null;
  } catch {
    return null;
  }
}

function parseTier(
  raw: unknown,
  fallbackLabel: string,
): { label: string; items: RewardItem[] } {
  if (!raw || typeof raw !== "object") {
    return { label: fallbackLabel, items: [] };
  }
  const m = raw as Record<string, unknown>;
  const label = String(m.label ?? fallbackLabel) || fallbackLabel;
  const items: RewardItem[] = [];
  if (Array.isArray(m.items) && m.items.length > 0) {
    for (const it of m.items) {
      const o =
        it && typeof it === "object" ? (it as Record<string, unknown>) : {};
      const imageUrl = String(o.image_url ?? "").trim();
      const itemLabel = String(o.label ?? "").trim();
      if (imageUrl || itemLabel) {
        items.push({ label: itemLabel, imageUrl });
      }
    }
  } else if (
    String(m.image_url ?? "").trim() ||
    String(m.label ?? "").trim()
  ) {
    items.push({
      label: String(m.label ?? fallbackLabel),
      imageUrl: String(m.image_url ?? "").trim(),
    });
  }
  return { label, items };
}

export function rewardSlotsFromConfig(
  config: Record<string, unknown>,
): RewardSlots {
  const raw =
    config.reward_slots && typeof config.reward_slots === "object"
      ? (config.reward_slots as Record<string, unknown>)
      : {};
  const t1 = parseTier(raw.rank_1, "Top 1");
  const t2 = parseTier(raw.rank_2, "Top 2");
  const t3 = parseTier(raw.rank_3, "Top 3");
  const t4 = parseTier(raw.rank_4_10, "Top 4 ~ 10");
  return {
    rank1Label: t1.label,
    rank1Items: t1.items,
    rank2Label: t2.label,
    rank2Items: t2.items,
    rank3Label: t3.label,
    rank3Items: t3.items,
    rank4to10Label: t4.label,
    rank4to10Items: t4.items,
  };
}

export function rulesFromConfig(config: Record<string, unknown>): string {
  const rules = String(config.rules ?? "").trim();
  return rules || DEFAULT_RULES;
}

type GiftCfg = { giftId: string; points: number };

export function giftConfigsFromEvent(config: Record<string, unknown>): GiftCfg[] {
  const raw = config.weekly_star_gifts;
  if (Array.isArray(raw) && raw.length > 0) {
    const out: GiftCfg[] = [];
    for (const e of raw) {
      if (!e || typeof e !== "object") continue;
      const m = e as Record<string, unknown>;
      const id = String(m.gift_id ?? m.id ?? "").trim();
      if (!id) continue;
      out.push({ giftId: id, points: Number(m.points ?? 0) || 0 });
      if (out.length >= 4) break;
    }
    if (out.length) return out;
  }
  const legacy = config.weekly_star_gift_ids;
  if (!Array.isArray(legacy)) return [];
  return legacy
    .map((g) => String(g ?? "").trim())
    .filter(Boolean)
    .slice(0, 4)
    .map((giftId) => ({ giftId, points: 0 }));
}

export async function fetchEvent(eventId: string): Promise<EventRow | null> {
  const { data, error } = await supabase
    .from("party_events")
    .select("id, title, subtitle, start_at, end_at, action_config")
    .eq("id", eventId)
    .maybeSingle();
  if (error || !data) return null;
  return {
    id: String(data.id),
    title: String(data.title ?? "14 August"),
    subtitle: data.subtitle ? String(data.subtitle) : null,
    start_at: data.start_at ? String(data.start_at) : null,
    end_at: data.end_at ? String(data.end_at) : null,
    action_config:
      data.action_config && typeof data.action_config === "object"
        ? (data.action_config as Record<string, unknown>)
        : {},
  };
}

export async function fetchGifts(config: Record<string, unknown>): Promise<GiftItem[]> {
  const cfgs = giftConfigsFromEvent(config);
  if (!cfgs.length) return [];
  const ids = cfgs.map((c) => c.giftId);
  const { data, error } = await supabase
    .from("shop_items")
    .select("id, name, image_url, price_coins")
    .in("id", ids);
  if (error || !data) return [];
  const byId = new Map(data.map((row) => [String(row.id), row]));
  return cfgs.map((c) => {
    const row = byId.get(c.giftId);
    const price = Number(row?.price_coins ?? 0) || 0;
    return {
      id: c.giftId,
      name: String(row?.name ?? "Gift"),
      imageUrl: String(row?.image_url ?? ""),
      points: c.points > 0 ? c.points : price,
    };
  });
}

export async function refreshWindowRankings(eventId: string): Promise<void> {
  await supabase.rpc("refresh_event_window_gift_rankings", {
    p_event_id: eventId,
  });
}

export async function fetchRankings(eventId: string): Promise<RankRow[]> {
  const { data, error } = await supabase.rpc("get_event_window_gift_rankings", {
    p_event_id: eventId,
    p_limit: 50,
    p_offset: 0,
  });
  if (error || !data) return [];
  return (data as Record<string, unknown>[]).map((row) => ({
    user_id: String(row.user_id ?? ""),
    username: row.username ? String(row.username) : null,
    avatar_url: row.avatar_url ? String(row.avatar_url) : null,
    short_id: row.short_id ? String(row.short_id) : null,
    score: Number(row.score ?? 0) || 0,
    rank: Number(row.rank ?? 0) || 0,
  }));
}

export async function fetchMyRank(eventId: string): Promise<RankRow | null> {
  const { data, error } = await supabase.rpc("get_my_event_window_gift_rank", {
    p_event_id: eventId,
  });
  if (error || !data || typeof data !== "object") return null;
  const row = data as Record<string, unknown>;
  const userId = String(row.user_id ?? "");
  if (!userId) return null;
  return {
    user_id: userId,
    username: row.username ? String(row.username) : null,
    avatar_url: row.avatar_url ? String(row.avatar_url) : null,
    short_id: row.short_id ? String(row.short_id) : null,
    score: Number(row.score ?? 0) || 0,
    rank: Number(row.rank ?? 0) || 0,
  };
}

export async function fetchLeader(eventId: string): Promise<RankRow | null> {
  const { data, error } = await supabase.rpc("get_event_window_gift_leader", {
    p_event_id: eventId,
  });
  if (error || !data || typeof data !== "object") return null;
  const row = data as Record<string, unknown>;
  const userId = String(row.user_id ?? "");
  if (!userId) return null;
  return {
    user_id: userId,
    username: row.username ? String(row.username) : null,
    avatar_url: row.avatar_url ? String(row.avatar_url) : null,
    short_id: row.short_id ? String(row.short_id) : null,
    score: Number(row.score ?? 0) || 0,
    rank: Number(row.rank ?? 0) || 0,
  };
}
