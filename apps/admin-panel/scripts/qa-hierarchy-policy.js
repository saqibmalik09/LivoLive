const { Client: Client } = require("pg");

const fs = require("fs");

const path = require("path");

function loadEnv() {
  const p = path.join(__dirname, "..", ".env.local");
  const env = fs.readFileSync(p, "utf8");
  const get = (k) => {
    const m = env.match(new RegExp(`^${k}=(.*)$`, "m"));
    if (!m) return "";
    return m[1].trim().replace(/^["']|["']$/g, "");
  };
  return {
    dbUrl: get("DATABASE_URL"),
  };
}

async function main() {
  const { dbUrl: dbUrl } = loadEnv();
  if (!dbUrl) throw new Error("Missing DATABASE_URL");
  const client = new Client({
    connectionString: dbUrl,
    ssl: {
      rejectUnauthorized: false,
    },
  });
  await client.connect();
  const { rows: rows } = await client.query(
    `\n    SELECT 'host_pc' AS k, host_pc::text AS v FROM commission_configs WHERE id=1\n    UNION ALL SELECT 'agency_pc', agency_pc::text FROM commission_configs WHERE id=1\n    UNION ALL SELECT 'bd_pc', bd_pc::text FROM commission_configs WHERE id=1\n    UNION ALL SELECT 'agency_levels', COUNT(*)::text FROM agency_salary_level_configs\n    UNION ALL SELECT 'bd_levels', COUNT(*)::text FROM bd_level_configs\n    UNION ALL SELECT 'gift_pct', host_gift_percent::text FROM policy_gift_settings WHERE id=1\n    UNION ALL SELECT 'has_get_my_bd_center', COUNT(*)::text FROM pg_proc WHERE proname='get_my_bd_center'\n    UNION ALL SELECT 'has_ban_rpc', COUNT(*)::text FROM pg_proc WHERE proname='super_bd_set_user_banned'\n    UNION ALL SELECT 'has_host_target', COUNT(*)::text FROM pg_proc WHERE proname='get_host_period_target'\n    UNION ALL SELECT 'has_agency_targets', COUNT(*)::text FROM pg_proc WHERE proname='get_agency_period_targets'\n    UNION ALL SELECT 'payout_A', payout_date::text FROM get_period_bounds('2026-07-A')\n    UNION ALL SELECT 'payout_B', payout_date::text FROM get_period_bounds('2026-07-B')\n    UNION ALL SELECT 'bd_lv3_total', (basic_salary_usd + commission_usd + new_bd_commission_usd)::text\n      FROM bd_level_configs WHERE level = 3\n  `,
  );
  const map = Object.fromEntries(rows.map((r) => [r.k, r.v]));
  const fails = [];
  if (map.host_pc !== "30") fails.push(`host_pc=${map.host_pc}`);
  if (map.agency_pc !== "0") fails.push(`agency_pc=${map.agency_pc}`);
  if (map.bd_pc !== "0") fails.push(`bd_pc=${map.bd_pc}`);
  if (map.agency_levels !== "25") fails.push(`agency_levels=${map.agency_levels}`);
  if (map.bd_levels !== "11") fails.push(`bd_levels=${map.bd_levels}`);
  if (map.payout_A !== "2026-07-16") fails.push(`payout_A=${map.payout_A}`);
  if (map.payout_B !== "2026-08-01") fails.push(`payout_B=${map.payout_B}`);
  if (Number(map.bd_lv3_total) !== 18) fails.push(`bd_lv3_total=${map.bd_lv3_total}`);
  if (map.has_ban_rpc !== "1") fails.push("missing ban rpc");
  console.log(map);
  if (fails.length) {
    console.error("QA FAIL:", fails);
    process.exit(1);
  }
  console.log("QA PASS");
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
