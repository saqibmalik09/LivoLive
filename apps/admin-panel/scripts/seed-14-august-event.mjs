import { createClient } from "@supabase/supabase-js";

import { existsSync, readFileSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const envPath = join(__dirname, "..", ".env.local");

const WEB_URL = "https://sklive-events.sin.app.zuvodev.com/14-august";

const BANNER_URL = "https://sklive-events.sin.app.zuvodev.com/14-august/weekly-star-hero.webp";

const TITLE = "14 August";

const DEFAULT_RULES = [
  "1. Only the specified gifts received will be counted for points. All other gifts are invalid.",
  "2. Receiving a specified gift awards the points shown under that gift.",
  "3. The points are updated in real time. The final ranking is based on the list at the end of the event.",
  "4. After the event ends, the system will automatically send the rewards.",
].join("\n");

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
  const url = env.NEXT_PUBLIC_SUPABASE_URL || env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Supabase credentials missing");
  const supabase = createClient(url, key);
  const { data: weeklyStar } = await supabase
    .from("party_events")
    .select("action_config, banner_url")
    .eq("event_kind", "weekly_star_native")
    .eq("is_active", true)
    .order("priority", {
      ascending: false,
    })
    .limit(1)
    .maybeSingle();
  const wsConfig =
    weeklyStar?.action_config && typeof weeklyStar.action_config === "object"
      ? weeklyStar.action_config
      : {};
  const { data: existing, error: fetchErr } = await supabase
    .from("party_events")
    .select("id, action_config")
    .eq("title", TITLE)
    .eq("event_kind", "webview")
    .limit(1)
    .maybeSingle();
  if (fetchErr) throw fetchErr;
  const startAt = new Date("2026-08-13T00:00:00+05:00").toISOString();
  const endAt = new Date("2026-08-14T23:59:59+05:00").toISOString();
  const action_config = {
    web_url: WEB_URL,
    page_title: TITLE,
    rules: String(wsConfig.rules ?? "").trim() || DEFAULT_RULES,
    weekly_star_gifts: Array.isArray(wsConfig.weekly_star_gifts) ? wsConfig.weekly_star_gifts : [],
    weekly_star_gift_ids: Array.isArray(wsConfig.weekly_star_gift_ids)
      ? wsConfig.weekly_star_gift_ids
      : [],
    reward_slots:
      wsConfig.reward_slots && typeof wsConfig.reward_slots === "object"
        ? wsConfig.reward_slots
        : {},
  };
  const row = {
    title: TITLE,
    subtitle: "Independence Day event",
    banner_url: weeklyStar?.banner_url || BANNER_URL,
    event_kind: "webview",
    screen_template: "recharge",
    action_type: "none",
    action_config: action_config,
    start_at: startAt,
    end_at: endAt,
    is_active: true,
    priority: 200,
    updated_at: new Date().toISOString(),
  };
  let id = existing?.id ?? null;
  if (existing?.id) {
    const { error: error } = await supabase.from("party_events").update(row).eq("id", existing.id);
    if (error) throw error;
  } else {
    const { data: data, error: error } = await supabase
      .from("party_events")
      .insert(row)
      .select("id")
      .single();
    if (error) throw error;
    id = data.id;
  }
  console.log(
    JSON.stringify(
      {
        id: id,
        title: TITLE,
        web_url: WEB_URL,
        start_at: startAt,
        end_at: endAt,
        gifts: action_config.weekly_star_gifts?.length ?? 0,
        has_rewards: Boolean(
          action_config.reward_slots && Object.keys(action_config.reward_slots).length,
        ),
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
