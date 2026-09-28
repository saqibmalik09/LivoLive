-- Weekly room reward points must follow the diamonds actually credited to
-- gift receivers, not the coins spent by gift senders.

CREATE OR REPLACE FUNCTION public.weekly_room_reward_diamond_points(
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
  SELECT COALESCE(SUM(COALESCE(el.host_amount, 0)), 0)::bigint
  FROM public.gift_logs gl
  LEFT JOIN public.earning_logs el ON el.gift_log_id = gl.id
  WHERE gl.room_id = p_room_id
    AND gl.created_at >= p_start
    AND gl.created_at < p_end;
$function$;

REVOKE ALL ON FUNCTION public.weekly_room_reward_diamond_points(
  uuid,
  timestamptz,
  timestamptz
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.weekly_room_reward_diamond_points(
  uuid,
  timestamptz,
  timestamptz
) TO service_role;

-- Preserve the current RPC contracts and reward behavior, replacing only
-- their point source. Guards make this migration fail rather than silently
-- leaving one of the security-critical claim checks on sender coins.
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
    'SELECT COALESCE\(SUM\(gl\.amount\), 0\)::bigint[[:space:]]+INTO (v_charm|v_claim_charm)[[:space:]]+FROM public\.gift_logs gl[[:space:]]+WHERE gl\.room_id = p_room_id[[:space:]]+AND gl\.created_at >= (v_[a-z_]+)[[:space:]]+AND gl\.created_at < (v_[a-z_]+);',
    'g'
  );

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Expected 2 coin point queries in get_weekly_room_reward_progress, found %',
      v_count;
  END IF;

  v_updated := regexp_replace(
    v_def,
    'SELECT COALESCE\(SUM\(gl\.amount\), 0\)::bigint[[:space:]]+INTO (v_charm|v_claim_charm)[[:space:]]+FROM public\.gift_logs gl[[:space:]]+WHERE gl\.room_id = p_room_id[[:space:]]+AND gl\.created_at >= (v_[a-z_]+)[[:space:]]+AND gl\.created_at < (v_[a-z_]+);',
    E'SELECT public.weekly_room_reward_diamond_points(p_room_id, \\2, \\3) INTO \\1;',
    'g'
  );

  EXECUTE v_updated;

  SELECT pg_get_functiondef(
    'public.claim_weekly_room_reward(uuid,integer)'::regprocedure
  ) INTO v_def;

  SELECT count(*) INTO v_count
  FROM regexp_matches(
    v_def,
    'SELECT COALESCE\(SUM\(gl\.amount\), 0\)::bigint[[:space:]]+INTO (v_claim_charm)[[:space:]]+FROM public\.gift_logs gl[[:space:]]+WHERE gl\.room_id = p_room_id[[:space:]]+AND gl\.created_at >= (v_[a-z_]+)[[:space:]]+AND gl\.created_at < (v_[a-z_]+);',
    'g'
  );

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'Expected 1 coin point query in claim_weekly_room_reward, found %',
      v_count;
  END IF;

  v_updated := regexp_replace(
    v_def,
    'SELECT COALESCE\(SUM\(gl\.amount\), 0\)::bigint[[:space:]]+INTO (v_claim_charm)[[:space:]]+FROM public\.gift_logs gl[[:space:]]+WHERE gl\.room_id = p_room_id[[:space:]]+AND gl\.created_at >= (v_[a-z_]+)[[:space:]]+AND gl\.created_at < (v_[a-z_]+);',
    E'SELECT public.weekly_room_reward_diamond_points(p_room_id, \\2, \\3) INTO \\1;',
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
