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
  const fails = [];
  const a = await client.query(
    `SELECT public.get_period_id_for_ts('2026-07-15 20:59:00+00'::timestamptz) AS p`,
  );
  const b = await client.query(
    `SELECT public.get_period_id_for_ts('2026-07-15 21:00:00+00'::timestamptz) AS p`,
  );
  if (a.rows[0].p !== "2026-07-A") fails.push(`15 23:59 local expected A got ${a.rows[0].p}`);
  if (b.rows[0].p !== "2026-07-B") fails.push(`16 00:00 local expected B got ${b.rows[0].p}`);
  const procs = await client.query(
    `\n    SELECT proname FROM pg_proc\n    WHERE proname IN (\n      'submit_agency_application',\n      'grant_staff_role_cosmetics',\n      'backfill_staff_role_cosmetics',\n      'get_period_id_for_ts',\n      'run_scheduled_agency_period_payouts',\n      'run_scheduled_bd_monthly_payout'\n    )\n  `,
  );
  const names = new Set(procs.rows.map((r) => r.proname));
  for (const n of [
    "submit_agency_application",
    "grant_staff_role_cosmetics",
    "get_period_id_for_ts",
    "run_scheduled_agency_period_payouts",
    "run_scheduled_bd_monthly_payout",
  ]) {
    if (!names.has(n)) fails.push(`missing ${n}`);
  }
  const cos = await client.query(`SELECT COUNT(*)::int AS n FROM staff_role_cosmetics`);
  if (cos.rows[0].n < 2) fails.push("staff_role_cosmetics rows < 2");
  console.log({
    day15_2359: a.rows[0].p,
    day16_0000: b.rows[0].p,
    procs: [...names],
    cosmetics_rows: cos.rows[0].n,
  });
  if (fails.length) {
    console.error("QA FAIL", fails);
    process.exit(1);
  }
  console.log("QA PASS");
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
