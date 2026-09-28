import { createClient } from "@supabase/supabase-js";

import { existsSync, readFileSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

const EVENT_ID = "33cb74e8-2f6d-41c2-b180-ba3b29f35ecf";

function loadEnv() {
  if (!existsSync(envPath)) throw new Error(`Missing ${envPath}`);
  const env = {};
  for (const line of readFileSync(envPath, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return env;
}

async function main() {
  const env = loadEnv();
  const supabase = createClient(
    env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL,
    env.SUPABASE_SERVICE_ROLE_KEY,
  );
  const { data: ev, error: evErr } = await supabase
    .from("party_events")
    .select("id, title, start_at, end_at, action_config")
    .eq("id", EVENT_ID)
    .single();
  if (evErr) throw evErr;
  const cfg = ev.action_config || {};
  const giftsCfg = Array.isArray(cfg.weekly_star_gifts) ? cfg.weekly_star_gifts : [];
  const giftIds = giftsCfg.map((g) => String(g.gift_id || g.id || "")).filter(Boolean);
  const { data: shop } = await supabase
    .from("shop_items")
    .select("id, name, price_coins")
    .in("id", giftIds.length ? giftIds : ["00000000-0000-0000-0000-000000000000"]);
  const shopById = new Map((shop || []).map((g) => [String(g.id), g]));
  const { data: ranks } = await supabase.rpc("get_event_window_gift_rankings", {
    p_event_id: EVENT_ID,
    p_limit: 10,
    p_offset: 0,
  });
  const top = Array.isArray(ranks) ? ranks.slice(0, 5) : [];
  const topIds = top.map((r) => r.user_id).filter(Boolean);
  const breakdown = [];
  if (giftIds.length && topIds.length) {
    const { data: logs } = await supabase
      .from("gift_logs")
      .select("receiver_id, gift_id, amount, created_at")
      .in("receiver_id", topIds)
      .in("gift_id", giftIds)
      .gte("created_at", ev.start_at)
      .lte("created_at", ev.end_at);
    const pts = new Map(giftsCfg.map((g) => [String(g.gift_id), Number(g.points || 0)]));
    const byUser = new Map();
    for (const row of logs || []) {
      const uid = String(row.receiver_id);
      const gid = String(row.gift_id);
      const p = pts.get(gid) || Number(row.amount || 0);
      if (!byUser.has(uid))
        byUser.set(uid, {
          score: 0,
          byGift: {},
        });
      const u = byUser.get(uid);
      u.score += p;
      u.byGift[gid] = (u.byGift[gid] || 0) + p;
    }
    for (const r of top) {
      const u = byUser.get(String(r.user_id)) || {
        score: 0,
        byGift: {},
      };
      breakdown.push({
        rank: r.rank,
        username: r.username,
        listed_score: r.score,
        from_these_gifts: u.score,
        matches: Number(r.score) === Number(u.score),
        gifts: Object.entries(u.byGift).map(([id, score]) => ({
          name: shopById.get(id)?.name || id,
          score: score,
        })),
      });
    }
  }
  console.log(
    JSON.stringify(
      {
        event: ev.title,
        window: {
          start_at: ev.start_at,
          end_at: ev.end_at,
        },
        configured_gifts: giftIds.map((id) => ({
          name: shopById.get(id)?.name || id,
          points: giftsCfg.find((g) => String(g.gift_id) === id)?.points,
          id: id,
        })),
        ranking_count: Array.isArray(ranks) ? ranks.length : 0,
        top_match: breakdown,
      },
      null,
      2,
    ),
  );
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
