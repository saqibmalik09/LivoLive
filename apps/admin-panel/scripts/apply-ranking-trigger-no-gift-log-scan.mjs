/**
 * Apply fast rankings migration (trigger + light cron) on Coolify DB.
 * Usage: node scripts/apply-ranking-trigger-no-gift-log-scan.mjs
 *
 * Connects via SSH + `sudo docker exec` (same path as other Coolify SQL applies).
 * Env: sklive-scripts/.env.coolify-supabase
 */
import { readFileSync, existsSync, writeFileSync, unlinkSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import { spawnSync } from "child_process";
import { tmpdir } from "os";

const __dirname = dirname(fileURLToPath(import.meta.url));
const adminRoot = join(__dirname, "..");
const scriptsEnv = join(adminRoot, "..", "sklive-scripts", ".env.coolify-supabase");
const migrationPath = join(
  adminRoot,
  "..",
  "sklive-mobile",
  "supabase",
  "migrations",
  "20260922180000_ranking_trigger_no_gift_log_scan.sql",
);

function loadEnv(path) {
  if (!existsSync(path)) throw new Error(`Missing ${path}`);
  const env = {};
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const m = line.match(/^([^#=]+)=(.*)$/);
    if (m) env[m[1].trim()] = m[2].trim().replace(/^["']|["']$/g, "");
  }
  return env;
}

function sshPsql(env, sqlPath) {
  const args = [
    "-p",
    env.COOLIFY_VPS_SSH_PASSWORD,
    "ssh",
    "-o",
    "StrictHostKeyChecking=no",
    "-o",
    "PreferredAuthentications=password",
    "-o",
    "PubkeyAuthentication=no",
    "-o",
    "ConnectTimeout=20",
    `${env.COOLIFY_VPS_SSH_USER}@${env.COOLIFY_VPS_IP}`,
    `sudo docker exec -i ${env.COOLIFY_DB_CONTAINER} psql -U postgres -d postgres -v ON_ERROR_STOP=1`,
  ];
  const r = spawnSync("sshpass", args, {
    input: readFileSync(sqlPath),
    encoding: "utf8",
    maxBuffer: 20 * 1024 * 1024,
  });
  if (r.stdout) process.stdout.write(r.stdout);
  if (r.stderr) process.stderr.write(r.stderr);
  if (r.status !== 0) {
    throw new Error(`psql via SSH failed with exit ${r.status}`);
  }
}

async function main() {
  if (!existsSync(migrationPath)) {
    throw new Error(`Missing migration: ${migrationPath}`);
  }
  const env = loadEnv(scriptsEnv);
  for (const k of [
    "COOLIFY_VPS_IP",
    "COOLIFY_VPS_SSH_USER",
    "COOLIFY_VPS_SSH_PASSWORD",
    "COOLIFY_DB_CONTAINER",
  ]) {
    if (!env[k]) throw new Error(`Missing ${k} in ${scriptsEnv}`);
  }

  console.log("Applying ranking trigger migration via Coolify SSH...");
  sshPsql(env, migrationPath);
  console.log("Migration applied.");

  const verifySql = `
SELECT table_name, column_name FROM information_schema.columns
 WHERE table_schema='public' AND column_name IN ('period_start','recent_gift_score','recent_gift_window_start')
   AND table_name IN ('gift_rankings','charm_rankings','room_rankings','agency_rankings','game_rankings','room_stats')
 ORDER BY 1,2;
SELECT tgname FROM pg_trigger WHERE NOT tgisinternal
  AND tgname IN ('trg_gift_logs_bump_rankings','trg_transactions_bump_game_rankings');
SELECT jobname, schedule FROM cron.job WHERE jobname LIKE '%ranking%' OR jobname LIKE '%gift%';
SELECT proname,
       (position('gift_logs' in pg_get_functiondef(oid)) > 0) AS scans_gift_logs
FROM pg_proc
WHERE pronamespace='public'::regnamespace
  AND proname IN (
    'refresh_gift_rankings','refresh_charm_rankings','refresh_room_rankings',
    'refresh_agency_rankings','refresh_game_rankings'
  )
ORDER BY 1;
SELECT (position('gift_logs' in pg_get_viewdef('public.active_rooms_with_rankings'::regclass)) > 0)
  AS view_scans_gift_logs;
SELECT public.refresh_gift_rankings();
SELECT public.refresh_charm_rankings();
`;
  const tmp = join(tmpdir(), `sklive-rankings-verify-${Date.now()}.sql`);
  writeFileSync(tmp, verifySql);
  try {
    console.log("Verifying...");
    sshPsql(env, tmp);
  } finally {
    try {
      unlinkSync(tmp);
    } catch {
      /* ignore */
    }
  }
  console.log("Done.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
