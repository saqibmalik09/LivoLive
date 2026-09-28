-- Weekly room rewards follow the charm actually credited to gift receivers.
-- gift_logs.charm_amount is authoritative:
--   regular gifts -> full gift value
--   lucky / lucky-pro gifts -> configured receiver share

CREATE OR REPLACE FUNCTION public.weekly_room_reward_charm_points(
  p_room_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
  SELECT COALESCE(
    SUM(COALESCE(gl.charm_amount, gl.amount, 0)),
    0
  )::bigint
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.created_at >= p_start
    AND gl.created_at < p_end;
$function$;

REVOKE ALL ON FUNCTION public.weekly_room_reward_charm_points(
  uuid,
  timestamptz,
  timestamptz
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.weekly_room_reward_charm_points(
  uuid,
  timestamptz,
  timestamptz
) TO service_role;

-- Keep the RPC contracts unchanged, replacing only their point source.
DO $migration$
DECLARE
  v_def text;
  v_updated text;
  v_count integer;
BEGIN
  SELECT pg_get_functiondef(
    'public.get_weekly_room_reward_progress(uuid)'::regprocedure
  ) INTO v_def;

  SELECT count(*) INTO v_count
  FROM regexp_matches(
    v_def,
    'public\.weekly_room_reward_diamond_points\(p_room_id, ([^,]+), ([^)]+)\)',
    'g'
  );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Expected 2 diamond point calls in get_weekly_room_reward_progress, found %',
      v_count;
  END IF;

  v_updated := regexp_replace(
    v_def,
    'public\.weekly_room_reward_diamond_points\(p_room_id, ([^,]+), ([^)]+)\)',
    E'public.weekly_room_reward_charm_points(p_room_id, \\1, \\2)',
    'g'
  );
  EXECUTE v_updated;

  SELECT pg_get_functiondef(
    'public.claim_weekly_room_reward(uuid,integer)'::regprocedure
  ) INTO v_def;

  SELECT count(*) INTO v_count
  FROM regexp_matches(
    v_def,
    'public\.weekly_room_reward_diamond_points\(p_room_id, ([^,]+), ([^)]+)\)',
    'g'
  );

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Expected 1 diamond point call in claim_weekly_room_reward, found %',
      v_count;
  END IF;

  v_updated := regexp_replace(
    v_def,
    'public\.weekly_room_reward_diamond_points\(p_room_id, ([^,]+), ([^)]+)\)',
    E'public.weekly_room_reward_charm_points(p_room_id, \\1, \\2)',
    'g'
  );
  EXECUTE v_updated;
END;
$migration$;

GRANT EXECUTE ON FUNCTION public.get_weekly_room_reward_progress(uuid)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_weekly_room_reward(uuid, integer)
  TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
