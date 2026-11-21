# Runbook — live room performance (voice, seats, profile, gifts)

Covers the Stage 1 change set: gateway + SQL only, no new APK. Installed app
versions keep working because no response shape, socket event or RPC signature
changed.

## Where things run

| Thing | Where |
|---|---|
| Gateway | `sklive-gateway` container, source in `/opt/sklive-gateway` |
| Git clone | `/opt/livolive` (branch `production` is what serves users) |
| Postgres | `supabase-db-mnq3vesx0syflb0m0bot3oa2` |
| LiveKit | Coolify service `rr1rnq2qirqyr2yinczwpsse`, `voice.skliveparty.online` |

Live app folders under `/opt/sklive-*` are **not** git working copies. Never run
`git init` or `git checkout` inside them; use `ops/deploy/update-from-git.sh`.

## Which branch

Ship the **gateway from `main`**. `main`'s gateway is ahead of `production`: it
already parallelises `buildSnapshot` and emits cached seats early. Its one extra
cost was an agency-badge query in the seat path, and that is now cached and run
in parallel — but it needs step 2's indexes, so apply the SQL first.

**Do not deploy the Next.js panels from `main`.** `production` carries two
things `main` does not: Cloudflare R2 uploads (`CdnImg.tsx`, `lib/r2.ts`, the
sync scripts, `sharp` as a dependency) and a salary period of one per calendar
month rather than split at the 15th. Deploying a panel from `main` would
silently revert both. Only `gateway` is cleared to ship from `main` today.

`production` stays as the frozen snapshot of what served users before this
change set — that is the rollback reference.

## Deploy order (Stage 1)

1. **Measure first.** Without a before-number there is nothing to compare to.

   ```bash
   sudo ops/deploy/voice-health.sh 300
   ```

   Then, with a real room open, note four numbers: time until seats are
   visible, time until a new mic is audible to others, time to open a profile
   from a seat, and time from tapping a gift to seeing it. Repeat with 1, 5 and
   10 people in one room.

2. **Indexes.** Safe while live (`CONCURRENTLY`), re-runnable. Takes minutes on
   `gift_logs`.

   ```bash
   sudo ops/deploy/apply-sql.sh \
     apps/mobile/supabase/migrations/20261121120000_live_room_hot_path_indexes.sql
   ```

3. **Profile rollups.** Must run *after* step 2 — the backfill uses the new
   `gift_logs (receiver_id, gift_id)` index.

   ```bash
   sudo ops/deploy/apply-sql.sh \
     apps/mobile/supabase/migrations/20261121130000_profile_gift_rollups.sql
   ```

   This creates a trigger on `gift_logs` (brief exclusive lock, milliseconds),
   then backfills history outside that lock. Verify:

   ```sql
   SELECT baseline_at, backfilled_at FROM public.gift_rollup_state;
   SELECT count(*) FROM public.user_gift_rollups;
   -- spot-check one user against the source of truth
   SELECT public.user_total_sent('<uuid>'),
          (SELECT COALESCE(SUM(amount),0) FROM public.gift_logs WHERE sender_id = '<uuid>');
   ```

   If a number ever looks wrong for one person:
   `SELECT public.recompute_user_gift_rollup('<uuid>');`

4. **Gateway.**

   ```bash
   sudo ops/deploy/update-from-git.sh gateway main
   ```

   It diffs first and asks before copying, backs the folder up to
   `/opt/sklive-gateway.bak-<stamp>`, then builds and restarts only that
   container. A non-zero build exit stops the deploy.

5. **Verify.**

   ```bash
   sudo ops/deploy/voice-health.sh 180
   ```

   Re-take the four timings from step 1.

## Reading `voice-health.sh`

`perm=` counts come from the voice token mint:

- `pending` — the mint replied without waiting on the LiveKit admin API and the
  sync finished in the background. **This is the expected majority** after the
  change that stopped blocking token replies, and is why taking the mic no
  longer waits on LiveKit.
- `not_connected` — the user is not in the LiveKit room yet. Normal on a first
  join; the token itself already carries the publish grant.
- `updated` — LiveKit applied the permission change to a live connection.
- `error_*` or a rising `perm sync late` count — LiveKit is slow or
  unreachable. Voice still works (the token is authoritative), but someone who
  is already connected may need a reconnect to start publishing. Check the
  LiveKit service and its DNS (it needs explicit `8.8.8.8` / `1.1.1.1`).

## Rollback

Each piece reverts on its own.

- **Gateway**: `rm -rf /opt/sklive-gateway && mv /opt/sklive-gateway.bak-<stamp> /opt/sklive-gateway`
  then `sudo ops/deploy/deploy-service.sh gateway`.
- **Indexes**: harmless to leave. To remove one:
  `DROP INDEX CONCURRENTLY IF EXISTS <name>;`
- **Rollups**: the old behaviour is one statement away — the rollup tables can
  stay while the functions go back to reading `gift_logs` directly:

  ```sql
  DROP TRIGGER IF EXISTS trg_gift_logs_rollups ON public.gift_logs;
  -- then re-apply 20260820081000_profile_gift_aggregates.sql
  ```

  Nothing was dropped or renamed, so this is a function swap, not a migration.

## Tunables (gateway env, all optional)

| Variable | Default | What it does |
|---|---|---|
| `DB_POOL_MAX` | 24 | Main Postgres pool. Was hard-coded at 8. |
| `GIFT_DB_POOL_MAX` | 16 | Gift pool. Was 6. |
| `LIVEKIT_PERM_SYNC_WAIT_MS` | 250 | How long a mint waits for the admin API before replying anyway. |
| `PRESENCE_REPORT_MS` | 3000 | Window for collapsing presence writes to Postgres. |
| `PRESENCE_LIST_TTL_SEC` | 15 | Cached room presence list. Dropped on every join and leave. |
| `SEAT_WEAR_TTL_SEC` | 120 | Cached frames/badges per user. Lower it if a newly bought frame should appear sooner. |
| `GIFT_CACHE_TTL_MS` | 60000 | Cached shop item rows in the send path. |

## Things that will bite you

- Verify `docker compose build` exits 0. A failed build leaves the old
  container running and the deploy looks fine.
- `statement_timeout` is 8s for the `authenticated` role; a timeout surfaces to
  the app as Postgres error `57014`, not as a crash.
- Never `pg_dump` to move this database. Copy `PGDATA` physically.
- `coolify-proxy` must be on the Supabase docker network or `api.` stops
  resolving.
- Delete macOS `._*` files before any Next.js build. `deploy-service.sh` does
  this for you.
- `CREATE INDEX CONCURRENTLY` cannot run inside a transaction. `apply-sql.sh`
  does not open one.
- Do not start the old server's database (`51.222.81.97`) or the stopped test
  LiveKit instance (`trzes9cwliufu1bgylhjqp59`).
