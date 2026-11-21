-- Indexes for the queries a live room runs on every join, seat change and gift.
--
-- Apply OUTSIDE a transaction. CREATE INDEX CONCURRENTLY cannot run inside one:
--   psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f <this file>
-- (psql is autocommit per statement, so do not wrap the file in BEGIN/COMMIT.)
--
-- Every statement is idempotent, so re-running is safe. Nothing is dropped or
-- renamed; existing indexes with other names simply stay.

-- ---------------------------------------------------------------------------
-- Seat wear: equipped inventory, read for every user on a seat
-- ---------------------------------------------------------------------------
-- The gateway reads equipped, unexpired items for a batch of seat holders.
-- Partial on is_equipped because that is a small slice of a large table.
CREATE INDEX CONCURRENTLY IF NOT EXISTS user_inventory_equipped_user_idx
  ON public.user_inventory (user_id, item_id)
  WHERE is_equipped = true;

-- ---------------------------------------------------------------------------
-- Seat wear: agency badge
-- ---------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS agencies_owner_id_idx
  ON public.agencies (owner_id)
  WHERE owner_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS agency_members_user_id_idx
  ON public.agency_members (user_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS agency_rankings_agency_type_idx
  ON public.agency_rankings (agency_id, ranking_type);

-- ---------------------------------------------------------------------------
-- Seat wear: CP level. The lookup is "user1_id = $1 OR user2_id = $1", which
-- Postgres can satisfy as a bitmap OR of these two.
-- ---------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS couples_user1_cp_level_idx
  ON public.couples (user1_id, cp_level DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS couples_user2_cp_level_idx
  ON public.couples (user2_id, cp_level DESC);

-- ---------------------------------------------------------------------------
-- Seats and kicks
-- ---------------------------------------------------------------------------
-- room_seats (room_id, seat_index) is already unique (the seat upsert relies on
-- it), so reads by room are covered. Reads by user are not: leaving other rooms
-- and the orphan sweep both look a user up across rooms.
CREATE INDEX CONCURRENTLY IF NOT EXISTS room_seats_user_id_idx
  ON public.room_seats (user_id)
  WHERE user_id IS NOT NULL;

-- The orphan sweep scans by age.
CREATE INDEX CONCURRENTLY IF NOT EXISTS room_seats_updated_at_idx
  ON public.room_seats (updated_at)
  WHERE user_id IS NOT NULL;

-- Checked on every single room join, before anything else happens.
CREATE INDEX CONCURRENTLY IF NOT EXISTS room_kicks_room_user_active_idx
  ON public.room_kicks (room_id, user_id, kicked_at DESC);

-- ---------------------------------------------------------------------------
-- Seat gift totals: earning_logs joined to gift_logs by room
-- ---------------------------------------------------------------------------
CREATE INDEX CONCURRENTLY IF NOT EXISTS gift_logs_room_id_idx
  ON public.gift_logs (room_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS earning_logs_gift_log_host_idx
  ON public.earning_logs (gift_log_id, host_id)
  WHERE host_amount > 0;

-- ---------------------------------------------------------------------------
-- Profile card
-- ---------------------------------------------------------------------------
-- Received-gift history had no index on receiver_id at all, so the grouped
-- summary behind a profile open scanned the whole gift_logs table. Needed both
-- by the old function and by the rollup backfill/repair path in
-- 20261121130000_profile_gift_rollups.sql.
CREATE INDEX CONCURRENTLY IF NOT EXISTS gift_logs_receiver_gift_idx
  ON public.gift_logs (receiver_id, gift_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS follows_follower_idx
  ON public.follows (follower_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS follows_following_idx
  ON public.follows (following_id);

-- ---------------------------------------------------------------------------
-- Level/badge config lookups. These tables are small, so a plain (locking)
-- index build is a few milliseconds. Each is guarded so that a table or column
-- this deployment does not have cannot abort the rest of the file.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  stmt text;
BEGIN
  FOREACH stmt IN ARRAY ARRAY[
    'CREATE INDEX IF NOT EXISTS level_configs_category_level_idx
       ON public.level_configs (category, level)',
    'CREATE INDEX IF NOT EXISTS charm_level_assets_level_feature_idx
       ON public.charm_level_assets (level, feature_key)',
    'CREATE INDEX IF NOT EXISTS vip_level_assets_level_feature_idx
       ON public.vip_level_assets (level, feature_key)',
    'CREATE INDEX IF NOT EXISTS family_level_assets_feature_level_idx
       ON public.family_level_assets (feature_key, level DESC)',
    'CREATE INDEX IF NOT EXISTS cp_level_configs_level_idx
       ON public.cp_level_configs (level)',
    'CREATE INDEX IF NOT EXISTS agency_level_configs_min_exp_idx
       ON public.agency_level_configs (min_exp DESC)'
  ]
  LOOP
    BEGIN
      EXECUTE stmt;
    EXCEPTION
      WHEN undefined_table OR undefined_column THEN
        RAISE NOTICE 'skipped (missing table/column): %', stmt;
    END;
  END LOOP;
END
$$;

-- Fresh statistics so the planner actually picks the new indexes.
ANALYZE public.user_inventory;
ANALYZE public.room_seats;
ANALYZE public.room_kicks;
