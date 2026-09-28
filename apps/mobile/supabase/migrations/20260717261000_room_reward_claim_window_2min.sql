-- Room gift box: 2-minute claim window after unlocking a level.
-- Miss the window → forfeit that level for the day; continue to next level.

CREATE TABLE IF NOT EXISTS public.room_reward_claim_windows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  level integer NOT NULL REFERENCES public.room_reward_levels(level),
  period_key text NOT NULL,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'claimed', 'forfeited')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, room_id, level, period_key)
);

CREATE INDEX IF NOT EXISTS room_reward_claim_windows_lookup_idx
  ON public.room_reward_claim_windows (user_id, room_id, period_key, status);

ALTER TABLE public.room_reward_claim_windows ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS room_reward_windows_read_own ON public.room_reward_claim_windows;
CREATE POLICY room_reward_windows_read_own
  ON public.room_reward_claim_windows FOR SELECT TO authenticated
  USING (user_id = auth.uid());

UPDATE public.room_reward_rules
SET rules = '[
  "Contribute energy by sending gifts in this room. Gift coins count toward today''s progress.",
  "Progress and claimed boxes reset every day at 00:00 (UTC+3). You start again from LV1.",
  "When you unlock a level you have 2 minutes to claim. If you miss it, that level cannot be claimed that day and you move to the next level.",
  "Each level can be opened once per day in this room (within the 2-minute window). Rewards are randomly selected from that level pool."
]'::jsonb,
updated_at = now()
WHERE id = 1;

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
  v_win public.room_reward_claim_windows%ROWTYPE;
  v_claim_secs integer;
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

    -- Refresh forfeited after possible inserts (none needed) + claimed arrays
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

  SELECT COALESCE(
    (
      SELECT l.level
      FROM public.room_reward_levels l
      WHERE l.is_active = true
        AND NOT (l.level = ANY (v_claimed))
        AND NOT (l.level = ANY (v_forfeited))
      ORDER BY l.level ASC
      LIMIT 1
    ),
    (
      SELECT MAX(l.level)
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

CREATE OR REPLACE FUNCTION public.open_room_reward_box(
  p_room_id uuid,
  p_level integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_energy bigint := 0;
  v_required bigint;
  v_item public.room_reward_items%ROWTYPE;
  v_total_weight integer;
  v_pick integer;
  v_running integer := 0;
  v_claim_id uuid;
  v_expires timestamptz;
  v_snapshot jsonb;
  v_duration integer;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_period text;
  v_win public.room_reward_claim_windows%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_room_id IS NULL OR p_level IS NULL OR p_level < 1 OR p_level > 5 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid params');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.rooms WHERE id = p_room_id) THEN
    RETURN json_build_object('success', false, 'message', 'Room not found');
  END IF;

  SELECT d.day_start, d.day_end, d.period_key
  INTO v_day_start, v_day_end, v_period
  FROM public.room_reward_day_bounds(now()) d;

  -- Expire missed windows first
  UPDATE public.room_reward_claim_windows w
  SET status = 'forfeited'
  WHERE w.user_id = v_user_id
    AND w.room_id = p_room_id
    AND w.period_key = v_period
    AND w.status = 'open'
    AND w.expires_at <= now();

  SELECT l.required_points
  INTO v_required
  FROM public.room_reward_levels l
  WHERE l.level = p_level
    AND l.is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Level not found');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.room_reward_claims c
    WHERE c.user_id = v_user_id
      AND c.room_id = p_room_id
      AND c.level = p_level
      AND c.period_key = v_period
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed today');
  END IF;

  SELECT * INTO v_win
  FROM public.room_reward_claim_windows w
  WHERE w.user_id = v_user_id
    AND w.room_id = p_room_id
    AND w.level = p_level
    AND w.period_key = v_period;

  IF NOT FOUND OR v_win.status <> 'open' OR v_win.expires_at <= now() THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Claim window expired (2 minutes). This level is locked for today.'
    );
  END IF;

  SELECT COALESCE(SUM(gl.amount), 0)::bigint
  INTO v_energy
  FROM public.gift_logs gl
  WHERE gl.room_id = p_room_id
    AND gl.sender_id = v_user_id
    AND gl.created_at >= v_day_start
    AND gl.created_at < v_day_end;

  IF v_energy < v_required THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Not enough energy',
      'energy', v_energy,
      'required', v_required
    );
  END IF;

  SELECT COALESCE(SUM(i.weight), 0)
  INTO v_total_weight
  FROM public.room_reward_items i
  WHERE i.level = p_level
    AND i.is_active = true;

  IF v_total_weight <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No rewards configured');
  END IF;

  v_pick := 1 + floor(random() * v_total_weight)::integer;

  FOR v_item IN
    SELECT *
    FROM public.room_reward_items i
    WHERE i.level = p_level
      AND i.is_active = true
    ORDER BY i.sort_order, i.created_at
  LOOP
    v_running := v_running + v_item.weight;
    IF v_running >= v_pick THEN
      EXIT;
    END IF;
  END LOOP;

  IF v_item.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Reward pick failed');
  END IF;

  v_snapshot := jsonb_build_object(
    'id', v_item.id,
    'title', v_item.title,
    'image_url', v_item.image_url,
    'reward_type', v_item.reward_type,
    'coin_amount', v_item.coin_amount,
    'shop_item_id', v_item.shop_item_id,
    'level', p_level,
    'period_key', v_period
  );

  IF v_item.reward_type = 'coins' AND v_item.coin_amount > 0 THEN
    UPDATE public.users
    SET coins = coins + v_item.coin_amount
    WHERE id = v_user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      v_user_id,
      v_item.coin_amount,
      'coin',
      'room_reward',
      p_room_id
    );
  ELSIF v_item.reward_type = 'shop_item' AND v_item.shop_item_id IS NOT NULL THEN
    SELECT COALESCE(si.duration_days, 0)
    INTO v_duration
    FROM public.shop_items si
    WHERE si.id = v_item.shop_item_id
      AND si.is_active = true;

    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'message', 'Shop item missing');
    END IF;

    v_expires := CASE
      WHEN v_duration > 0 THEN now() + make_interval(days => v_duration)
      ELSE '9999-12-31'::timestamptz
    END;

    INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
    VALUES (v_user_id, v_item.shop_item_id, 'room_reward', v_expires)
    ON CONFLICT (user_id, item_id) DO NOTHING;
  END IF;

  INSERT INTO public.room_reward_claims (
    user_id, room_id, level, reward_item_id, reward_snapshot, period_key
  ) VALUES (
    v_user_id, p_room_id, p_level, v_item.id, v_snapshot, v_period
  )
  RETURNING id INTO v_claim_id;

  UPDATE public.room_reward_claim_windows
  SET status = 'claimed'
  WHERE user_id = v_user_id
    AND room_id = p_room_id
    AND level = p_level
    AND period_key = v_period;

  RETURN json_build_object(
    'success', true,
    'claim_id', v_claim_id,
    'reward', v_snapshot,
    'period_key', v_period
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'Already claimed today');
  WHEN others THEN
    RETURN json_build_object(
      'success', false,
      'message', SQLERRM
    );
END;
$function$;

GRANT SELECT ON public.room_reward_claim_windows TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_room_reward_progress(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.open_room_reward_box(uuid, integer) TO authenticated, service_role;
