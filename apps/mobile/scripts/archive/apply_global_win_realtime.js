const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const connectionString = process.env.DATABASE_URL;
if (!connectionString) throw new Error('DATABASE_URL is required');

const sqlPath = path.join(
  __dirname,
  'supabase',
  'migrations',
  '20250610160000_global_win_announcements_realtime.sql',
);

async function main() {
  const sql = fs.readFileSync(sqlPath, 'utf8');
  const client = new Client({ connectionString });
  await client.connect();
  console.log('Connected to database.');

  await client.query(sql);
  console.log('Migration applied: 20250610160000_global_win_announcements_realtime.sql');

  const check = await client.query(
    `SELECT tablename FROM pg_publication_tables
     WHERE pubname = 'supabase_realtime'
       AND tablename = 'global_win_announcements'`,
  );
  console.log('realtime enabled:', check.rows.length > 0);

  await client.end();
}

main().catch((err) => {
  console.error('FAILED:', err.message);
  process.exit(1);
});
