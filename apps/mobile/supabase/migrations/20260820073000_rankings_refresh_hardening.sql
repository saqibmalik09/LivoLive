-- Rankings lock convoy fix: advisory lock + upsert/stale-delete + server cron.
-- Clients must NOT call refresh_* on read; cron rebuilds every 2 minutes.

CREATE OR REPLACE FUNCTION public.refresh_charm_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_charm_rankings')) THEN
    RETURN;
  END IF;

  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    IF v_type = 'daily' THEN
      v_start := date_trunc('day', now());
    ELSIF v_type = 'weekly' THEN
      v_start := date_trunc('week', now());
    ELSE
      v_start := date_trunc('month', now());
    END IF;

    WITH ranked AS (
      SELECT
        gl.receiver_id AS user_id,
        COALESCE(SUM(COALESCE(gl.charm_amount, gl.amount)), 0)::bigint AS total_score,
        row_number() OVER (
          ORDER BY COALESCE(SUM(COALESCE(gl.charm_amount, gl.amount)), 0) DESC
        )::int AS rnk
      FROM public.gift_logs gl
      WHERE gl.created_at >= v_start
        AND gl.receiver_id IS NOT NULL
      GROUP BY gl.receiver_id
      HAVING COALESCE(SUM(COALESCE(gl.charm_amount, gl.amount)), 0) > 0
    ),
    upserted AS (
      INSERT INTO public.charm_rankings (id, user_id, score, rank, ranking_type)
      SELECT gen_random_uuid(), user_id, total_score, rnk, v_type
      FROM ranked
      ON CONFLICT (user_id, ranking_type)
      DO UPDATE SET
        score = EXCLUDED.score,
        rank = EXCLUDED.rank
      RETURNING user_id
    )
    DELETE FROM public.charm_rankings cr
    WHERE cr.ranking_type = v_type
      AND NOT EXISTS (SELECT 1 FROM ranked r WHERE r.user_id = cr.user_id);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_gift_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_gift_rankings')) THEN
    RETURN;
  END IF;

  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    IF v_type = 'daily' THEN
      v_start := date_trunc('day', now());
    ELSIF v_type = 'weekly' THEN
      v_start := date_trunc('week', now());
    ELSE
      v_start := date_trunc('month', now());
    END IF;

    WITH ranked AS (
      SELECT
        gl.sender_id AS user_id,
        COALESCE(SUM(gl.amount), 0)::bigint AS total_score,
        row_number() OVER (
          ORDER BY COALESCE(SUM(gl.amount), 0) DESC
        )::int AS rnk
      FROM public.gift_logs gl
      WHERE gl.created_at >= v_start
        AND gl.sender_id IS NOT NULL
      GROUP BY gl.sender_id
      HAVING COALESCE(SUM(gl.amount), 0) > 0
    ),
    upserted AS (
      INSERT INTO public.gift_rankings (id, user_id, score, rank, ranking_type)
      SELECT gen_random_uuid(), user_id, total_score, rnk, v_type
      FROM ranked
      ON CONFLICT (user_id, ranking_type)
      DO UPDATE SET
        score = EXCLUDED.score,
        rank = EXCLUDED.rank
      RETURNING user_id
    )
    DELETE FROM public.gift_rankings gr
    WHERE gr.ranking_type = v_type
      AND NOT EXISTS (SELECT 1 FROM ranked r WHERE r.user_id = gr.user_id);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_room_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_room_rankings')) THEN
    RETURN;
  END IF;

  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    IF v_type = 'daily' THEN
      v_start := date_trunc('day', now());
    ELSIF v_type = 'weekly' THEN
      v_start := date_trunc('week', now());
    ELSE
      v_start := date_trunc('month', now());
    END IF;

    WITH ranked AS (
      SELECT
        gl.room_id,
        COALESCE(SUM(gl.amount), 0)::bigint AS total_score,
        row_number() OVER (
          ORDER BY COALESCE(SUM(gl.amount), 0) DESC
        )::int AS rnk
      FROM public.gift_logs gl
      WHERE gl.created_at >= v_start
        AND gl.room_id IS NOT NULL
      GROUP BY gl.room_id
      HAVING COALESCE(SUM(gl.amount), 0) > 0
    ),
    upserted AS (
      INSERT INTO public.room_rankings (id, room_id, score, rank, ranking_type, updated_at)
      SELECT gen_random_uuid(), room_id, total_score, rnk, v_type, now()
      FROM ranked
      ON CONFLICT (room_id, ranking_type)
      DO UPDATE SET
        score = EXCLUDED.score,
        rank = EXCLUDED.rank,
        updated_at = now()
      RETURNING room_id
    )
    DELETE FROM public.room_rankings rr
    WHERE rr.ranking_type = v_type
      AND NOT EXISTS (SELECT 1 FROM ranked r WHERE r.room_id = rr.room_id);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_agency_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_agency_rankings')) THEN
    RETURN;
  END IF;

  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    IF v_type = 'daily' THEN
      v_start := date_trunc('day', now());
    ELSIF v_type = 'weekly' THEN
      v_start := date_trunc('week', now());
    ELSE
      v_start := date_trunc('month', now());
    END IF;

    WITH ranked AS (
      SELECT
        am.agency_id,
        COALESCE(SUM(COALESCE(gl.charm_amount, gl.amount)), 0)::bigint AS total_score,
        row_number() OVER (
          ORDER BY COALESCE(SUM(COALESCE(gl.charm_amount, gl.amount)), 0) DESC
        )::int AS rnk
      FROM public.agency_members am
      JOIN public.agencies a
        ON a.id = am.agency_id
       AND COALESCE(a.is_active, true) = true
      JOIN public.gift_logs gl
        ON gl.receiver_id = am.user_id
       AND gl.created_at >= v_start
      GROUP BY am.agency_id
      HAVING COALESCE(SUM(COALESCE(gl.charm_amount, gl.amount)), 0) > 0
    ),
    upserted AS (
      INSERT INTO public.agency_rankings (agency_id, score, rank, ranking_type, updated_at)
      SELECT agency_id, total_score, rnk, v_type, now()
      FROM ranked
      ON CONFLICT (agency_id, ranking_type)
      DO UPDATE SET
        score = EXCLUDED.score,
        rank = EXCLUDED.rank,
        updated_at = now()
      RETURNING agency_id
    )
    DELETE FROM public.agency_rankings ar
    WHERE ar.ranking_type = v_type
      AND NOT EXISTS (SELECT 1 FROM ranked r WHERE r.agency_id = ar.agency_id);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_game_rankings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_type text;
  v_start timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('refresh_game_rankings')) THEN
    RETURN;
  END IF;

  FOREACH v_type IN ARRAY ARRAY['daily', 'weekly', 'monthly'] LOOP
    IF v_type = 'daily' THEN
      v_start := date_trunc('day', now());
    ELSIF v_type = 'weekly' THEN
      v_start := date_trunc('week', now());
    ELSE
      v_start := date_trunc('month', now());
    END IF;

    WITH ranked AS (
      SELECT
        t.user_id,
        COALESCE(SUM(t.amount), 0)::bigint AS total_score,
        row_number() OVER (
          ORDER BY COALESCE(SUM(t.amount), 0) DESC
        )::int AS rnk
      FROM public.transactions t
      WHERE t.transaction_type = 'game_win'
        AND t.created_at >= v_start
      GROUP BY t.user_id
      HAVING COALESCE(SUM(t.amount), 0) > 0
    ),
    upserted AS (
      INSERT INTO public.game_rankings (user_id, score, rank, ranking_type, updated_at)
      SELECT user_id, total_score, rnk, v_type, now()
      FROM ranked
      ON CONFLICT (user_id, ranking_type)
      DO UPDATE SET
        score = EXCLUDED.score,
        rank = EXCLUDED.rank,
        updated_at = now()
      RETURNING user_id
    )
    DELETE FROM public.game_rankings gr
    WHERE gr.ranking_type = v_type
      AND NOT EXISTS (SELECT 1 FROM ranked r WHERE r.user_id = gr.user_id);
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_charm_rankings() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refresh_gift_rankings() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refresh_room_rankings() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refresh_agency_rankings() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refresh_game_rankings() TO anon, authenticated, service_role;

DO $outer$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname = 'refresh-rankings';
EXCEPTION
  WHEN others THEN NULL;
END;
$outer$;

DO $outer$
BEGIN
  PERFORM cron.schedule(
    'refresh-rankings',
    '*/2 * * * *',
    $cron$
      SELECT public.refresh_gift_rankings();
      SELECT public.refresh_charm_rankings();
      SELECT public.refresh_room_rankings();
      SELECT public.refresh_agency_rankings();
      SELECT public.refresh_game_rankings();
    $cron$
  );
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'pg_cron schedule skipped: %', SQLERRM;
END;
$outer$;
