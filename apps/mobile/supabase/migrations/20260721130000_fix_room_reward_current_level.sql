-- Fix room reward highlight: current_level must follow gift energy (and open claim),
-- not always the lowest unclaimed tier (which kept UI stuck on Lv1).

CREATE OR REPLACE FUNCTION public.get_room_reward_progress(p_room_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_energy bigint := 0;
  v_current_level integer := 1;
  v_levels json;
  v_items json;
  v_claimed integer[];
  v_forfeited integer[];
  v_rules json;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_period text;
  v_seconds bigint;
  v_lvl record;
BEGIN
  IF p_room_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Room required');
  END IF;

  SELECT d.day_start, d.day_end, d.period_key, d.seconds_remaining
  INTO v_day_start, v_day_end, v_period, v_seconds
  FROM public.room_reward_day_bounds(now()) d;

  IF v_user_id IS NOT NULL THEN
    SELECT COALESCE(SUM(gl.amount), 0)::bigint
    INTO v_energy
    FROM public.gift_logs gl
    WHERE gl.room_id = p_room_id
      AND gl.sender_id = v_user_id
      AND gl.created_at >= v_day_start
      AND gl.created_at < v_day_end;

    -- Expire missed claim windows for today
    UPDATE public.room_reward_claim_windows w
    SET status = 'forfeited'
    WHERE w.user_id = v_user_id
      AND w.room_id = p_room_id
      AND w.period_key = v_period
      AND w.status = 'open'
      AND w.expires_at <= now();

    SELECT COALESCE(array_agg(c.level ORDER BY c.level), '{}')
    INTO v_claimed
    FROM public.room_reward_claims c
    WHERE c.user_id = v_user_id
      AND c.room_id = p_room_id
      AND c.period_key = v_period;

    SELECT COALESCE(array_agg(w.level ORDER BY w.level), '{}')
    INTO v_forfeited
    FROM public.room_reward_claim_windows w
    WHERE w.user_id = v_user_id
      AND w.room_id = p_room_id
      AND w.period_key = v_period
      AND w.status = 'forfeited';

    -- Open 2-minute window only for the lowest unlocked eligible level
    FOR v_lvl IN
      SELECT l.level, l.required_points
      FROM public.room_reward_levels l
      WHERE l.is_active = true
      ORDER BY l.level ASC
    LOOP
      IF v_lvl.level = ANY (v_claimed) THEN
        CONTINUE;
      END IF;
      IF v_lvl.level = ANY (v_forfeited) THEN
        CONTINUE;
      END IF;
      IF v_energy < v_lvl.required_points THEN
        EXIT;
      END IF;

      INSERT INTO public.room_reward_claim_windows (
        user_id, room_id, level, period_key, unlocked_at, expires_at, status
      ) VALUES (
        v_user_id, p_room_id, v_lvl.level, v_period,
        now(), now() + interval '2 minutes', 'open'
      )
      ON CONFLICT (user_id, room_id, level, period_key) DO NOTHING;

      EXIT; -- one claimable level window at a time
    END LOOP;

    SELECT COALESCE(array_agg(w.level ORDER BY w.level), '{}')
    INTO v_forfeited
    FROM public.room_reward_claim_windows w
    WHERE w.user_id = v_user_id
      AND w.room_id = p_room_id
      AND w.period_key = v_period
      AND w.status = 'forfeited';
  ELSE
    v_claimed := '{}';
    v_forfeited := '{}';
  END IF;

  -- Focus level for UI highlight:
  -- 1) open claim window (if any)
  -- 2) highest tier unlocked by today's gift energy
  -- 3) otherwise lowest active tier (next target)
  SELECT COALESCE(
    (
      SELECT w.level
      FROM public.room_reward_claim_windows w
      WHERE w.user_id = v_user_id
        AND w.room_id = p_room_id
        AND w.period_key = v_period
        AND w.status = 'open'
        AND w.expires_at > now()
        AND NOT (w.level = ANY (v_claimed))
      ORDER BY w.level ASC
      LIMIT 1
    ),
    (
      SELECT MAX(l.level)
      FROM public.room_reward_levels l
      WHERE l.is_active = true
        AND v_energy >= l.required_points
    ),
    (
      SELECT MIN(l.level)
      FROM public.room_reward_levels l
      WHERE l.is_active = true
    ),
    1
  )
  INTO v_current_level;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.level), '[]'::json)
  INTO v_levels
  FROM (
    SELECT
      l.level,
      l.required_points,
      l.is_active,
      l.sort_order,
      (l.level = ANY (v_claimed)) AS claimed,
      (l.level = ANY (v_forfeited)) AS forfeited,
      (
        SELECT CASE
          WHEN w.status = 'open' AND w.expires_at > now()
            AND NOT (l.level = ANY (v_claimed))
          THEN true
          ELSE false
        END
        FROM public.room_reward_claim_windows w
        WHERE w.user_id = v_user_id
          AND w.room_id = p_room_id
          AND w.level = l.level
          AND w.period_key = v_period
        LIMIT 1
      ) AS can_open,
      (
        SELECT GREATEST(
          0,
          FLOOR(EXTRACT(EPOCH FROM (w.expires_at - now())))
        )::int
        FROM public.room_reward_claim_windows w
        WHERE w.user_id = v_user_id
          AND w.room_id = p_room_id
          AND w.level = l.level
          AND w.period_key = v_period
          AND w.status = 'open'
          AND w.expires_at > now()
        LIMIT 1
      ) AS claim_seconds_remaining,
      (
        SELECT w.expires_at
        FROM public.room_reward_claim_windows w
        WHERE w.user_id = v_user_id
          AND w.room_id = p_room_id
          AND w.level = l.level
          AND w.period_key = v_period
        LIMIT 1
      ) AS claim_expires_at
    FROM public.room_reward_levels l
    WHERE l.is_active = true
  ) t;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.level, t.sort_order, t.created_at), '[]'::json)
  INTO v_items
  FROM (
    SELECT
      i.id,
      i.level,
      i.title,
      i.image_url,
      i.reward_type,
      i.coin_amount,
      i.shop_item_id,
      i.weight,
      i.sort_order,
      i.is_featured,
      i.created_at
    FROM public.room_reward_items i
    WHERE i.is_active = true
  ) t;

  SELECT r.rules INTO v_rules
  FROM public.room_reward_rules r
  WHERE r.id = 1;

  RETURN json_build_object(
    'success', true,
    'energy', v_energy,
    'current_level', v_current_level,
    'claimed_levels', to_json(v_claimed),
    'forfeited_levels', to_json(v_forfeited),
    'levels', v_levels,
    'items', v_items,
    'rules', COALESCE(v_rules, '[]'::json),
    'period_key', v_period,
    'seconds_remaining', v_seconds,
    'resets_at', v_day_end
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_room_reward_progress(uuid) TO anon, authenticated, service_role;
