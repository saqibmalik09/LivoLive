const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const connectionString = process.env.DATABASE_URL;
if (!connectionString) throw new Error('DATABASE_URL is required');

const sqlPath = path.join(
  __dirname,
  'supabase',
  'migrations',
  '20250610170000_disable_win_bonus_notifications.sql',
);

async function main() {
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const client = new Client({ connectionString });
  await client.connect();
  console.log('Connected to database.');

  await client.query(sql);
  console.log('Migration applied: 20250610170000_disable_win_bonus_notifications.sql');

  const remaining = await client.query(
    `SELECT type, COUNT(*)::int AS count
     FROM public.system_notifications
     WHERE type IN ('lucky_gift', 'lucky_pro_gift', 'game_win')
     GROUP BY type`,
  );
  console.log('Remaining win-bonus notifications:', remaining.rows);

  const fn = await client.query(
    `SELECT pg_get_functiondef(p.oid) AS def
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'process_gift_category_bonus'`,
  );
  const hasInsert = fn.rows[0]?.def?.includes('INSERT INTO public.system_notifications');
  console.log('Function still inserts system_notifications:', hasInsert);

  await client.end();
}

main().catch((err) => {
  console.error('FAILED:', err.message);
  process.exit(1);
});
