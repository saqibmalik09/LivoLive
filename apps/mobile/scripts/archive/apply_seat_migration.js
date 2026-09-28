const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const connectionString = process.env.DATABASE_URL;
if (!connectionString) throw new Error('DATABASE_URL is required');

const sqlPath = path.join(
  __dirname,
  'supabase',
  'migrations',
  '20250609120000_cleanup_stale_room_seats_safe.sql',
);

async function main() {
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const client = new Client({ connectionString });
  await client.connect();
  console.log('Connected to database.');

  await client.query(sql);
  console.log('Migration applied: 20250609120000_cleanup_stale_room_seats_safe.sql');

  const cols = await client.query(
    `SELECT column_name
     FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'room_seats'
     ORDER BY ordinal_position`,
  );
  console.log(
    'room_seats columns:',
    cols.rows.map((r) => r.column_name).join(', '),
  );

  const fn = await client.query(
    `SELECT pg_get_functiondef(p.oid) AS def
     FROM pg_proc p
     JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'cleanup_stale_room_seats'`,
  );
  console.log(
    'Safe empty-list guard:',
    fn.rows[0]?.def?.includes('cardinality(p_online_user_ids) = 0'),
  );

  const trig = await client.query(
    `SELECT tgname FROM pg_trigger WHERE tgname = 'room_seats_set_updated_at'`,
  );
  console.log('updated_at trigger exists:', trig.rows.length > 0);

  await client.end();
}

main().catch((err) => {
  console.error('FAILED:', err.message);
  process.exit(1);
});
