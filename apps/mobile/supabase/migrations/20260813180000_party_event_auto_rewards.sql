-- Auto-grant party event Top 1–10 rewards after end_at.
-- Admin stores payout on action_config.reward_slots items:
--   reward_type: display | coins | shop_item
--   coin_amount, shop_item_id, duration_days

CREATE TABLE IF NOT EXISTS public.party_event_reward_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  party_event_id uuid NOT NULL REFERENCES public.party_events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  rank int NOT NULL,
  slot_key text NOT NULL,
  item_index int NOT NULL DEFAULT 0,
  reward_type text NOT NULL,
  coin_amount int NOT NULL DEFAULT 0,
  shop_item_id uuid REFERENCES public.shop_items(id) ON DELETE SET NULL,
  snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (party_event_id, user_id, slot_key, item_index)
);

CREATE INDEX IF NOT EXISTS party_event_reward_grants_event_idx
  ON public.party_event_reward_grants (party_event_id, rank);

CREATE TABLE IF NOT EXISTS public.party_event_reward_settlements (
  party_event_id uuid PRIMARY KEY REFERENCES public.party_events(id) ON DELETE CASCADE,
  settled_at timestamptz NOT NULL DEFAULT now(),
  granted_count int NOT NULL DEFAULT 0,
  result jsonb NOT NULL DEFAULT '{}'::jsonb
);

ALTER TABLE public.party_event_reward_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.party_event_reward_settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS party_event_reward_grants_own_read ON public.party_event_reward_grants;
CREATE POLICY party_event_reward_grants_own_read
  ON public.party_event_reward_grants
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS party_event_reward_settlements_read ON public.party_event_reward_settlements;
CREATE POLICY party_event_reward_settlements_read
  ON public.party_event_reward_settlements
  FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON public.party_event_reward_grants TO authenticated;
GRANT SELECT ON public.party_event_reward_settlements TO authenticated;
GRANT ALL ON public.party_event_reward_grants TO service_role;
GRANT ALL ON public.party_event_reward_settlements TO service_role;

CREATE OR REPLACE FUNCTION public._party_event_parse_uuid(p_raw text)
RETURNS uuid
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_raw IS NULL OR btrim(p_raw) = '' THEN
    RETURN NULL;
  END IF;
  RETURN btrim(p_raw)::uuid;
EXCEPTION
  WHEN others THEN
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._party_event_grant_one(
  p_event_id uuid,
  p_user_id uuid,
  p_rank int,
  p_slot_key text,
  p_item_index int,
  p_item jsonb
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type text;
  v_coins int;
  v_shop uuid;
  v_days int;
  v_label text;
  v_image text;
  v_grant_id uuid;
  v_duration int;
  v_expires timestamptz;
  v_title text;
  v_snapshot jsonb;
BEGIN
  IF p_user_id IS NULL OR p_item IS NULL OR jsonb_typeof(p_item) <> 'object' THEN
    RETURN false;
  END IF;

  v_type := lower(btrim(COALESCE(p_item->>'reward_type', 'display')));
  BEGIN
    v_coins := COALESCE(NULLIF(p_item->>'coin_amount', '')::int, 0);
  EXCEPTION
    WHEN others THEN v_coins := 0;
  END;
  v_shop := public._party_event_parse_uuid(p_item->>'shop_item_id');
  BEGIN
    v_days := COALESCE(NULLIF(p_item->>'duration_days', '')::int, 0);
  EXCEPTION
    WHEN others THEN v_days := 0;
  END;
  v_label := COALESCE(NULLIF(btrim(p_item->>'label'), ''), '');
  v_image := COALESCE(p_item->>'image_url', '');

  IF v_type NOT IN ('coins', 'shop_item') THEN
    RETURN false;
  END IF;
  IF v_type = 'coins' AND v_coins <= 0 THEN
    RETURN false;
  END IF;
  IF v_type = 'shop_item' AND v_shop IS NULL THEN
    RETURN false;
  END IF;

  INSERT INTO public.party_event_reward_grants (
    party_event_id, user_id, rank, slot_key, item_index,
    reward_type, coin_amount, shop_item_id, snapshot
  ) VALUES (
    p_event_id, p_user_id, p_rank, p_slot_key, p_item_index,
    v_type, v_coins, v_shop, '{}'::jsonb
  )
  ON CONFLICT (party_event_id, user_id, slot_key, item_index) DO NOTHING
  RETURNING id INTO v_grant_id;

  IF v_grant_id IS NULL THEN
    RETURN false;
  END IF;

  v_snapshot := jsonb_build_object(
    'reward_type', v_type,
    'coin_amount', v_coins,
    'shop_item_id', v_shop,
    'label', v_label,
    'image_url', v_image,
    'rank', p_rank,
    'slot_key', p_slot_key
  );

  IF v_type = 'coins' THEN
    UPDATE public.users
    SET coins = COALESCE(coins, 0) + v_coins
    WHERE id = p_user_id;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      p_user_id,
      v_coins,
      'coin',
      'task_reward',
      p_event_id
    );
  ELSE
    SELECT COALESCE(NULLIF(v_days, 0), si.duration_days, 0),
           CASE WHEN v_label = '' THEN COALESCE(si.name, 'Reward') ELSE v_label END,
           CASE WHEN v_image = '' THEN COALESCE(si.image_url, '') ELSE v_image END
    INTO v_duration, v_title, v_image
    FROM public.shop_items si
    WHERE si.id = v_shop
      AND si.is_active = true;

    IF NOT FOUND THEN
      DELETE FROM public.party_event_reward_grants WHERE id = v_grant_id;
      RETURN false;
    END IF;

    v_expires := CASE
      WHEN v_duration > 0 THEN now() + make_interval(days => v_duration)
      ELSE '9999-12-31'::timestamptz
    END;

    INSERT INTO public.user_inventory (user_id, item_id, source, expires_at)
    VALUES (p_user_id, v_shop, 'party_event_reward', v_expires)
    ON CONFLICT (user_id, item_id) DO UPDATE
      SET expires_at = GREATEST(public.user_inventory.expires_at, EXCLUDED.expires_at),
          source = COALESCE(public.user_inventory.source, EXCLUDED.source);

    v_snapshot := v_snapshot || jsonb_build_object(
      'title', v_title,
      'image_url', v_image,
      'duration_days', v_duration,
      'expires_at', v_expires
    );
  END IF;

  UPDATE public.party_event_reward_grants
  SET snapshot = v_snapshot
  WHERE id = v_grant_id;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_party_event_rewards(
  p_event_id uuid,
  p_force boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event public.party_events%ROWTYPE;
  v_slots jsonb;
  v_items jsonb;
  v_slot_key text;
  v_rank int;
  v_idx int;
  v_item jsonb;
  v_user uuid;
  v_granted int := 0;
  v_ok boolean;
  rec record;
BEGIN
  SELECT * INTO v_event
  FROM public.party_events
  WHERE id = p_event_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Event not found');
  END IF;

  IF NOT p_force THEN
    IF v_event.end_at IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Event has no end time');
    END IF;
    IF v_event.end_at > now() THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Event has not ended yet',
        'end_at', v_event.end_at
      );
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.party_event_reward_settlements s
    WHERE s.party_event_id = p_event_id
  ) AND NOT p_force THEN
    RETURN jsonb_build_object('success', true, 'already_settled', true, 'granted', 0);
  END IF;

  BEGIN
    IF v_event.event_kind = 'webview' THEN
      PERFORM public.refresh_event_window_gift_rankings(p_event_id);
    ELSIF v_event.event_kind = 'weekly_star_native' THEN
      PERFORM public.refresh_weekly_star_rankings(p_event_id);
    ELSIF v_event.event_kind = 'game_star_native' THEN
      PERFORM public.refresh_game_star_rankings(p_event_id);
    ELSIF v_event.event_kind = 'cp_native' THEN
      PERFORM public.refresh_cp_event_rankings(p_event_id);
    END IF;
  EXCEPTION
    WHEN undefined_function THEN
      NULL;
    WHEN others THEN
      NULL;
  END;

  v_slots := COALESCE(v_event.action_config->'reward_slots', '{}'::jsonb);

  IF v_event.event_kind = 'cp_native' THEN
    FOR rec IN
      SELECT r.rank, r.user_1_id, r.user_2_id
      FROM public.cp_event_rankings r
      WHERE r.party_event_id = p_event_id
        AND r.period_key = 'current'
        AND r.rank BETWEEN 1 AND 10
      ORDER BY r.rank
    LOOP
      v_rank := rec.rank;
      v_slot_key := CASE
        WHEN v_rank = 1 THEN 'rank_1'
        WHEN v_rank = 2 THEN 'rank_2'
        WHEN v_rank = 3 THEN 'rank_3'
        ELSE 'rank_4_10'
      END;
      v_items := COALESCE(v_slots->v_slot_key->'items', '[]'::jsonb);
      IF jsonb_typeof(v_items) <> 'array' THEN
        CONTINUE;
      END IF;
      FOR v_idx IN 0 .. jsonb_array_length(v_items) - 1 LOOP
        v_item := v_items->v_idx;
        FOREACH v_user IN ARRAY ARRAY[rec.user_1_id, rec.user_2_id]
        LOOP
          v_ok := public._party_event_grant_one(
            p_event_id, v_user, v_rank, v_slot_key, v_idx, v_item
          );
          IF v_ok THEN
            v_granted := v_granted + 1;
          END IF;
        END LOOP;
      END LOOP;
    END LOOP;
  ELSE
    FOR rec IN
      SELECT x.user_id, x.rank
      FROM (
        SELECT r.user_id, r.rank
        FROM public.weekly_star_rankings r
        WHERE r.party_event_id = p_event_id
          AND r.period_key = CASE
            WHEN v_event.event_kind = 'webview' THEN 'window'
            ELSE 'current'
          END
          AND r.rank BETWEEN 1 AND 10
        UNION ALL
        SELECT g.user_id, g.rank
        FROM public.game_star_rankings g
        WHERE g.party_event_id = p_event_id
          AND v_event.event_kind = 'game_star_native'
          AND g.period_key = 'current'
          AND g.rank BETWEEN 1 AND 10
      ) x
      ORDER BY x.rank
    LOOP
      v_rank := rec.rank;
      v_user := rec.user_id;
      v_slot_key := CASE
        WHEN v_rank = 1 THEN 'rank_1'
        WHEN v_rank = 2 THEN 'rank_2'
        WHEN v_rank = 3 THEN 'rank_3'
        ELSE 'rank_4_10'
      END;
      v_items := COALESCE(v_slots->v_slot_key->'items', '[]'::jsonb);
      IF jsonb_typeof(v_items) <> 'array' THEN
        CONTINUE;
      END IF;
      FOR v_idx IN 0 .. jsonb_array_length(v_items) - 1 LOOP
        v_item := v_items->v_idx;
        v_ok := public._party_event_grant_one(
          p_event_id, v_user, v_rank, v_slot_key, v_idx, v_item
        );
        IF v_ok THEN
          v_granted := v_granted + 1;
        END IF;
      END LOOP;
    END LOOP;
  END IF;

  INSERT INTO public.party_event_reward_settlements (
    party_event_id, settled_at, granted_count, result
  ) VALUES (
    p_event_id,
    now(),
    v_granted,
    jsonb_build_object('granted', v_granted, 'force', p_force)
  )
  ON CONFLICT (party_event_id) DO UPDATE
    SET settled_at = now(),
        granted_count = public.party_event_reward_settlements.granted_count + EXCLUDED.granted_count,
        result = EXCLUDED.result;

  RETURN jsonb_build_object(
    'success', true,
    'granted', v_granted,
    'event_id', p_event_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_ended_party_event_rewards()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rec record;
  v_res jsonb;
  v_total int := 0;
  v_events int := 0;
BEGIN
  FOR rec IN
    SELECT e.id
    FROM public.party_events e
    WHERE e.end_at IS NOT NULL
      AND e.end_at <= now()
      AND e.event_kind IN (
        'webview', 'weekly_star_native', 'game_star_native', 'cp_native'
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.party_event_reward_settlements s
        WHERE s.party_event_id = e.id
      )
  LOOP
    v_res := public.settle_party_event_rewards(rec.id, false);
    v_events := v_events + 1;
    v_total := v_total + COALESCE((v_res->>'granted')::int, 0);
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'events', v_events,
    'granted', v_total
  );
END;
$$;

REVOKE ALL ON FUNCTION public._party_event_grant_one(uuid, uuid, int, text, int, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.settle_party_event_rewards(uuid, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.settle_ended_party_event_rewards() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.settle_party_event_rewards(uuid, boolean) TO service_role;
GRANT EXECUTE ON FUNCTION public.settle_ended_party_event_rewards() TO service_role;

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  PERFORM cron.unschedule('settle-party-event-rewards');
EXCEPTION
  WHEN others THEN NULL;
END $$;

DO $$
BEGIN
  PERFORM cron.schedule(
    'settle-party-event-rewards',
    '*/10 * * * *',
    $cron$SELECT public.settle_ended_party_event_rewards();$cron$
  );
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'pg_cron schedule skipped: %', SQLERRM;
END $$;
