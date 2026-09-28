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
  const { data: aug, error: augErr } = await supabase
    .from("party_events")
    .select("id, title, action_config")
    .eq("id", EVENT_ID)
    .single();
  if (augErr) throw augErr;
  const { data: weekly } = await supabase
    .from("party_events")
    .select("id, title, action_config")
    .eq("event_kind", "weekly_star_native")
    .eq("is_active", true)
    .order("priority", {
      ascending: false,
    })
    .limit(1)
    .maybeSingle();
  const augCfg = aug.action_config || {};
  const wsCfg = weekly?.action_config || {};
  const wsIds = new Set(
    (Array.isArray(wsCfg.weekly_star_gifts) ? wsCfg.weekly_star_gifts : [])
      .map((g) => String(g?.gift_id || g?.id || ""))
      .filter(Boolean),
  );
  (Array.isArray(wsCfg.weekly_star_gift_ids) ? wsCfg.weekly_star_gift_ids : []).forEach((id) =>
    wsIds.add(String(id)),
  );
  console.log("14 August current gifts:", augCfg.weekly_star_gifts);
  console.log("Weekly Star gift ids:", [...wsIds]);
  const { data: gifts, error: gErr } = await supabase
    .from("shop_items")
    .select("id, name, image_url, price_coins")
    .eq("is_gift", true)
    .eq("is_active", true)
    .order("price_coins", {
      ascending: false,
    });
  if (gErr) throw gErr;
  const candidates = (gifts || []).filter((g) => !wsIds.has(String(g.id)));
  const picked = [];
  const bands = [
    [5e3, 1e12],
    [1e3, 4999],
    [300, 999],
    [1, 299],
  ];
  for (const [lo, hi] of bands) {
    const hit = candidates.find(
      (g) =>
        Number(g.price_coins || 0) >= lo &&
        Number(g.price_coins || 0) <= hi &&
        !picked.some((p) => p.id === g.id),
    );
    if (hit) picked.push(hit);
  }
  while (picked.length < 4 && candidates.length) {
    const next = candidates.find((g) => !picked.some((p) => p.id === g.id));
    if (!next) break;
    picked.push(next);
  }
  const weekly_star_gifts = picked.slice(0, 4).map((g) => ({
    gift_id: g.id,
    points: Math.max(Number(g.price_coins || 0), 1),
  }));
  const weekly_star_gift_ids = weekly_star_gifts.map((g) => g.gift_id);
  const nextCfg = {
    ...augCfg,
    weekly_star_gifts: weekly_star_gifts,
    weekly_star_gift_ids: weekly_star_gift_ids,
  };
  const { error: uErr } = await supabase
    .from("party_events")
    .update({
      action_config: nextCfg,
      updated_at: new Date().toISOString(),
    })
    .eq("id", EVENT_ID);
  if (uErr) throw uErr;
  const { error: rErr } = await supabase.rpc("refresh_event_window_gift_rankings", {
    p_event_id: EVENT_ID,
  });
  if (rErr) throw rErr;
  const { data: ranks } = await supabase.rpc("get_event_window_gift_rankings", {
    p_event_id: EVENT_ID,
    p_limit: 10,
    p_offset: 0,
  });
  const named = picked.slice(0, 4).map((g) => ({
    name: g.name,
    price_coins: g.price_coins,
    points: Math.max(Number(g.price_coins || 0), 1),
    id: g.id,
  }));
  console.log(
    JSON.stringify(
      {
        gifts: named,
        ranking_rows: Array.isArray(ranks) ? ranks.length : 0,
        top: Array.isArray(ranks) ? ranks.slice(0, 3) : ranks,
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
