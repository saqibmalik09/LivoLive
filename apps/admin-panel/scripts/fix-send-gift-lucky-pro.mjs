import pg from "pg";

import { readFileSync, existsSync, writeFileSync } from "fs";

import { dirname, join } from "path";

import { fileURLToPath } from "url";

const { Client: Client } = pg;

const __dirname = dirname(fileURLToPath(import.meta.url));

const adminRoot = join(__dirname, "..");

const envPath = join(adminRoot, ".env.local");

const livePath = join(__dirname, "send_gift_live.sql");

const outPath = join(
  adminRoot,
  "..",
  "sk_live",
  "supabase",
  "migrations",
  "20250712130000_send_gift_lucky_pro_bonus.sql",
);

function loadEnv() {
  const text = readFileSync(envPath, "utf8");
  const env = {};
  for (const line of text.split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim();
  }
  return env;
}

function patch(sql) {
  let s = sql.replace(/\r\n/g, "\n");
  if (!s.includes("v_is_lucky := (v_category_name IN ('lucky', 'luck'));")) {
    throw new Error("Unexpected send_gift: lucky detection line missing");
  }
  s = s.replace(
    `  v_is_lucky BOOLEAN := false;`,
    `  v_is_lucky BOOLEAN := false;\n  v_is_lucky_pro BOOLEAN := false;\n  v_lucky_pro_bonus_won BOOLEAN := false;\n  v_lucky_pro_bonus_coins BIGINT := 0;\n  v_bonus_result JSON;`,
  );
  s = s.replace(
    `  v_is_lucky := (v_category_name IN ('lucky', 'luck'));\n  v_total_cost := v_gift_price * p_quantity;`,
    `  v_is_lucky := (v_category_name IN ('lucky', 'luck'));\n  v_is_lucky_pro := (v_category_name IN ('lucky pro', 'lucky_pro', 'luckypro'));\n  v_total_cost := v_gift_price * p_quantity;`,
  );
  s = s.replace(
    `  IF v_is_lucky THEN\n    SELECT * INTO v_lucky_cfg FROM public.lucky_gift_config WHERE id = 1;\n    v_host_share := (v_total_cost * v_lucky_cfg.receiver_percent::numeric / 100)::int;\n    v_pool := v_total_cost - v_host_share;\n  ELSE\n    v_host_share := (v_total_cost * v_host_pc) / 100;\n    v_pool := v_total_cost - v_host_share;\n  END IF;`,
    `  IF v_is_lucky THEN\n    SELECT * INTO v_lucky_cfg FROM public.lucky_gift_config WHERE id = 1;\n    v_host_share := (v_total_cost * v_lucky_cfg.receiver_percent::numeric / 100)::int;\n    v_pool := v_total_cost - v_host_share;\n  ELSIF v_is_lucky_pro THEN\n    SELECT * INTO v_lucky_cfg FROM public.lucky_pro_gift_config WHERE id = 1;\n    v_host_share := (v_total_cost * v_lucky_cfg.receiver_percent::numeric / 100)::int;\n    v_pool := v_total_cost - v_host_share;\n  ELSE\n    v_host_share := (v_total_cost * v_host_pc) / 100;\n    v_pool := v_total_cost - v_host_share;\n  END IF;`,
  );
  const bonusStart = `  IF v_is_lucky THEN\n    SELECT * INTO v_lucky_cfg FROM public.lucky_gift_config WHERE id = 1;\n    v_bonus_mode := v_lucky_cfg.bonus_trigger_mode;`;
  const bonusEndMarker = `  PERFORM public.provision_user_assets(p_sender_id);`;
  const startIdx = s.indexOf(bonusStart);
  const endIdx = s.indexOf(bonusEndMarker);
  if (startIdx < 0 || endIdx < 0) {
    throw new Error(`Could not locate lucky bonus block (start=${startIdx}, end=${endIdx})`);
  }
  const replacement = `  IF v_is_lucky OR v_is_lucky_pro THEN\n    v_bonus_result := public.process_gift_category_bonus(\n      CASE WHEN v_is_lucky_pro THEN 'lucky_pro' ELSE 'lucky' END,\n      p_sender_id,\n      p_receiver_id,\n      p_gift_id,\n      v_gift_log_id,\n      v_total_cost\n    );\n    v_gift_count := COALESCE((v_bonus_result->>'gift_count')::int, 0);\n    v_threshold := COALESCE((v_bonus_result->>'threshold')::int, 0);\n    v_bonus_mode := v_bonus_result->>'bonus_mode';\n    IF v_is_lucky_pro THEN\n      v_lucky_pro_bonus_won := COALESCE((v_bonus_result->>'bonus_won')::boolean, false);\n      v_lucky_pro_bonus_coins := COALESCE((v_bonus_result->>'bonus_coins')::bigint, 0);\n      v_bonus_coins := v_lucky_pro_bonus_coins;\n    ELSE\n      v_lucky_bonus_won := COALESCE((v_bonus_result->>'bonus_won')::boolean, false);\n      v_bonus_coins := COALESCE((v_bonus_result->>'bonus_coins')::bigint, 0);\n    END IF;\n  END IF;\n\n  PERFORM public.provision_user_assets(p_sender_id);`;
  s = s.slice(0, startIdx) + replacement + s.slice(endIdx + bonusEndMarker.length);
  s = s.replace(
    `    'is_lucky_gift', v_is_lucky,\n    'lucky_bonus_won', v_lucky_bonus_won,\n    'lucky_bonus_coins', COALESCE(v_bonus_coins, 0),\n    'lucky_gift_count', v_gift_count,\n    'lucky_gifts_until_bonus', CASE\n      WHEN v_is_lucky THEN GREATEST(0, v_threshold - v_gift_count)\n      ELSE NULL\n    END,\n    'lucky_bonus_mode', CASE WHEN v_is_lucky THEN v_bonus_mode ELSE NULL END,`,
    `    'is_lucky_gift', v_is_lucky,\n    'lucky_bonus_won', v_lucky_bonus_won,\n    'lucky_bonus_coins', CASE WHEN v_is_lucky THEN COALESCE(v_bonus_coins, 0) ELSE 0 END,\n    'is_lucky_pro_gift', v_is_lucky_pro,\n    'lucky_pro_bonus_won', v_lucky_pro_bonus_won,\n    'lucky_pro_bonus_coins', COALESCE(v_lucky_pro_bonus_coins, 0),\n    'lucky_gift_count', v_gift_count,\n    'lucky_gifts_until_bonus', CASE\n      WHEN v_is_lucky OR v_is_lucky_pro THEN GREATEST(0, v_threshold - v_gift_count)\n      ELSE NULL\n    END,\n    'lucky_bonus_mode', CASE WHEN v_is_lucky OR v_is_lucky_pro THEN v_bonus_mode ELSE NULL END,`,
  );
  if (!s.includes("is_lucky_pro_gift") || !s.includes("v_is_lucky_pro")) {
    throw new Error("Patch incomplete — lucky pro fields missing");
  }
  return s;
}

async function main() {
  if (!existsSync(livePath)) {
    throw new Error(`Missing ${livePath}. Run dump-send-gift.mjs first.`);
  }
  const patched = patch(readFileSync(livePath, "utf8"));
  const header = `-- Fix: send_gift ignored "Lucky Pro" category (only lucky/luck).\n-- Routes Lucky + Lucky Pro through process_gift_category_bonus and returns pro fields.\n\n`;
  writeFileSync(outPath, header + patched);
  console.log("Wrote migration", outPath);
  const env = loadEnv();
  const client = new Client({
    connectionString: env.DATABASE_URL || env.SUPABASE_DB_URL,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  try {
    await client.query(patched);
    console.log("Applied send_gift patch to live DB.");
    const check = await client.query(
      `\n      SELECT pg_get_functiondef(p.oid) AS def\n      FROM pg_proc p\n      JOIN pg_namespace n ON n.oid = p.pronamespace\n      WHERE n.nspname = 'public' AND p.proname = 'send_gift'\n      ORDER BY p.oid DESC LIMIT 1\n    `,
    );
    const def = check.rows[0]?.def ?? "";
    console.log(
      "has lucky_pro detect:",
      def.includes("lucky pro") && def.includes("process_gift_category_bonus"),
    );
    console.log("returns is_lucky_pro_gift:", def.includes("is_lucky_pro_gift"));
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
