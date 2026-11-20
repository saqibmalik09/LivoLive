SELECT pg_advisory_xact_lock(8412003);

CREATE TABLE IF NOT EXISTS public.gift_rank_queue (
  id bigserial PRIMARY KEY,
  created_at timestamptz NOT NULL,
  sender_id uuid,
  receiver_id uuid,
  room_id uuid,
  gift_amount bigint NOT NULL DEFAULT 0,
  charm_amount bigint NOT NULL DEFAULT 0
);

ALTER TABLE public.gift_rank_queue ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.gift_rank_queue FROM PUBLIC;
REVOKE ALL ON public.gift_rank_queue FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.gift_rank_queue_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE public.gift_rank_queue_id_seq FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.trg_gift_logs_bump_rankings()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
DECLARE
  v_gift bigint;
  v_charm bigint;
BEGIN
  IF NEW.created_at IS NULL THEN
    RETURN NEW;
  END IF;

  v_gift := COALESCE(NEW.amount, 0)::bigint;
  v_charm := COALESCE(NEW.charm_amount, NEW.amount, 0)::bigint;

  IF (NEW.sender_id IS NOT NULL AND v_gift > 0)
     OR (NEW.receiver_id IS NOT NULL AND v_charm > 0)
     OR (NEW.room_id IS NOT NULL AND v_gift > 0) THEN
    INSERT INTO public.gift_rank_queue
      (created_at, sender_id, receiver_id, room_id, gift_amount, charm_amount)
    VALUES
      (NEW.created_at, NEW.sender_id, NEW.receiver_id, NEW.room_id, v_gift, v_charm);
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.trg_gift_logs_bump_rankings() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.flush_gift_rank_queue(p_limit integer DEFAULT 5000)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET timezone TO 'UTC'
AS $$
DECLARE
  v_day timestamptz := date_trunc('day', now());
  v_week timestamptz := date_trunc('week', now());
  v_month timestamptz := date_trunc('month', now());
  v_count integer := 0;
  v_deltas jsonb;
  v_rooms jsonb;
  d jsonb;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('flush_gift_rank_queue')) THEN
    RETURN 0;
  END IF;

  WITH picked AS (
    DELETE FROM public.gift_rank_queue q
    WHERE q.id IN (
      SELECT id FROM public.gift_rank_queue
      ORDER BY id
      LIMIT GREATEST(COALESCE(p_limit, 5000), 1)
      FOR UPDATE SKIP LOCKED
    )
    RETURNING q.id, q.created_at, q.sender_id, q.receiver_id, q.room_id,
              q.gift_amount, q.charm_amount
  ),
  periods AS (
    SELECT p.*, t.typ, t.per
    FROM picked p
    CROSS JOIN LATERAL (VALUES
      ('daily', date_trunc('day', p.created_at)),
      ('weekly', date_trunc('week', p.created_at)),
      ('monthly', date_trunc('month', p.created_at))
    ) AS t(typ, per)
  ),
  raw AS (
    SELECT 'gift'::text AS board, sender_id AS id, typ, per, gift_amount AS score
    FROM periods
    WHERE sender_id IS NOT NULL AND gift_amount > 0
    UNION ALL
    SELECT 'charm', receiver_id, typ, per, charm_amount
    FROM periods
    WHERE receiver_id IS NOT NULL AND charm_amount > 0
    UNION ALL
    SELECT 'agency', ag.agency_id, typ, per, charm_amount
    FROM periods
    CROSS JOIN LATERAL (
      SELECT am.agency_id
      FROM public.agency_members am
      WHERE am.user_id = periods.receiver_id
      LIMIT 1
    ) ag
    WHERE receiver_id IS NOT NULL AND charm_amount > 0
    UNION ALL
    SELECT 'room', room_id, typ, per, gift_amount
    FROM periods
    WHERE room_id IS NOT NULL AND gift_amount > 0
  ),
  agg AS (
    SELECT board, id, typ, per, SUM(score)::bigint AS score
    FROM raw
    WHERE per = CASE typ
                  WHEN 'daily' THEN v_day
                  WHEN 'weekly' THEN v_week
                  ELSE v_month
                END
    GROUP BY board, id, typ, per
  ),
  room30 AS (
    SELECT DISTINCT ON (room_id) room_id, gift_amount::bigint AS score
    FROM picked
    WHERE room_id IS NOT NULL
      AND gift_amount > 0
      AND created_at >= (now() - interval '30 minutes')
    ORDER BY room_id, created_at DESC, id DESC
  )
  SELECT
    (SELECT COUNT(*) FROM picked),
    (SELECT jsonb_agg(jsonb_build_object(
              'board', board, 'id', id, 'typ', typ, 'per', per, 'score', score)
            ORDER BY board, id, typ)
     FROM agg),
    (SELECT jsonb_agg(jsonb_build_object('room_id', room_id, 'score', score)
            ORDER BY room_id)
     FROM room30)
  INTO v_count, v_deltas, v_rooms;

  IF v_deltas IS NOT NULL THEN
    FOR d IN SELECT * FROM jsonb_array_elements(v_deltas) LOOP
      PERFORM public.ranking_apply_delta(
        d->>'board',
        (d->>'id')::uuid,
        d->>'typ',
        (d->>'per')::timestamptz,
        (d->>'score')::bigint
      );
    END LOOP;
  END IF;

  IF v_rooms IS NOT NULL THEN
    FOR d IN SELECT * FROM jsonb_array_elements(v_rooms) LOOP
      INSERT INTO public.room_stats (room_id, recent_gift_score, recent_gift_window_start, updated_at)
      VALUES ((d->>'room_id')::uuid, (d->>'score')::bigint, now() - interval '30 minutes', now())
      ON CONFLICT (room_id) DO UPDATE
      SET recent_gift_score = CASE
            WHEN public.room_stats.recent_gift_window_start IS NULL
              OR public.room_stats.recent_gift_window_start < (now() - interval '30 minutes')
              THEN EXCLUDED.recent_gift_score
            ELSE public.room_stats.recent_gift_score + EXCLUDED.recent_gift_score
          END,
          recent_gift_window_start = CASE
            WHEN public.room_stats.recent_gift_window_start IS NULL
              OR public.room_stats.recent_gift_window_start < (now() - interval '30 minutes')
              THEN now() - interval '30 minutes'
            ELSE public.room_stats.recent_gift_window_start
          END,
          updated_at = now();
    END LOOP;
  END IF;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.flush_gift_rank_queue(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.flush_gift_rank_queue(integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.flush_gift_rank_queue(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.send_gift(p_sender_id uuid, p_receiver_id uuid, p_gift_id uuid, p_room_id uuid, p_quantity integer DEFAULT 1, p_lucky_engine text DEFAULT 'postgres'::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_gift_price INT;
  v_category_name TEXT;
  v_is_lucky BOOLEAN := false;
  v_is_lucky_pro BOOLEAN := false;
  v_use_gateway_lucky BOOLEAN := false;
  v_lucky_pro_bonus_won BOOLEAN := false;
  v_lucky_pro_bonus_coins BIGINT := 0;
  v_bonus_result JSON;
  v_total_cost BIGINT;
  v_sender_coins BIGINT;
  v_host_pc INT := 30;
  v_agency_id UUID;
  v_agency_owner_id UUID;
  v_sponsor_staff_id UUID;
  v_host_share INT;
  v_charm_credit BIGINT;
  v_official_share INT := 0;
  v_new_wealth_value BIGINT;
  v_new_wealth_level INT;
  v_new_charm_value BIGINT;
  v_new_charm_level INT;
  v_gift_log_id UUID;
  v_lucky_cfg RECORD;
  v_bonus_coins BIGINT;
  v_lucky_bonus_won BOOLEAN := false;
  v_receiver_name TEXT;
  v_period_id text;
  v_on_seat boolean := false;
BEGIN
  SELECT si.price_coins, lower(sc.name)
  INTO v_gift_price, v_category_name
  FROM public.shop_items si
  LEFT JOIN public.shop_categories sc ON sc.id = si.category_id
  WHERE si.id = p_gift_id AND si.is_active = TRUE;

  IF v_gift_price IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Gift not found or inactive');
  END IF;

  v_is_lucky := (v_category_name IN ('lucky', 'luck'));
  v_is_lucky_pro := (v_category_name IN ('lucky pro', 'lucky_pro', 'luckypro'));
  v_use_gateway_lucky := (lower(coalesce(nullif(trim(p_lucky_engine), ''), 'postgres')) = 'gateway');
  v_total_cost := v_gift_price * p_quantity;

  PERFORM 1
  FROM public.users
  WHERE id IN (p_sender_id, p_receiver_id)
  ORDER BY id
  FOR UPDATE;

  SELECT coins INTO v_sender_coins FROM public.users WHERE id = p_sender_id;
  IF v_sender_coins < v_total_cost THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  SELECT COALESCE(host_gift_percent, 30) INTO v_host_pc FROM public.policy_gift_settings WHERE id = 1;
  IF v_host_pc IS NULL THEN v_host_pc := 30; END IF;

  SELECT a.id, a.owner_id, a.sponsor_staff_id
  INTO v_agency_id, v_agency_owner_id, v_sponsor_staff_id
  FROM public.agencies a
  WHERE a.is_active = TRUE
    AND (
      a.owner_id = p_receiver_id
      OR EXISTS (
        SELECT 1 FROM public.agency_members am
        WHERE am.agency_id = a.id AND am.user_id = p_receiver_id
      )
    )
  ORDER BY CASE WHEN a.owner_id = p_receiver_id THEN 0 ELSE 1 END
  LIMIT 1;

  IF p_room_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.room_seats rs
      WHERE rs.room_id = p_room_id AND rs.user_id = p_receiver_id
    ) INTO v_on_seat;
  END IF;

  IF v_is_lucky THEN
    SELECT * INTO v_lucky_cfg FROM public.lucky_gift_config WHERE id = 1;
    v_host_share := (v_total_cost * v_lucky_cfg.receiver_percent::numeric / 100)::int;
  ELSIF v_is_lucky_pro THEN
    SELECT * INTO v_lucky_cfg FROM public.lucky_pro_gift_config WHERE id = 1;
    v_host_share := (v_total_cost * v_lucky_cfg.receiver_percent::numeric / 100)::int;
  ELSE
    v_host_share := (v_total_cost * v_host_pc) / 100;
  END IF;

  v_official_share := v_total_cost - v_host_share;
  IF v_official_share < 0 THEN v_official_share := 0; END IF;

  IF v_host_share > 0 AND v_agency_id IS NULL AND NOT COALESCE(v_on_seat, false) THEN
    v_official_share := v_official_share + v_host_share;
    v_host_share := 0;
  END IF;

  IF v_is_lucky OR v_is_lucky_pro THEN
    v_charm_credit := v_host_share;
  ELSE
    v_charm_credit := v_total_cost;
  END IF;

  SELECT (COALESCE(wealth_value, 0) + v_total_cost)
  INTO v_new_wealth_value
  FROM public.users
  WHERE id = p_sender_id;
  v_new_wealth_level := public.calc_wealth_level(v_new_wealth_value);

  UPDATE public.users
  SET coins = coins - v_total_cost,
      wealth_value = v_new_wealth_value,
      wealth_level = v_new_wealth_level
  WHERE id = p_sender_id;

  SELECT (COALESCE(charm_value, 0) + v_charm_credit)
  INTO v_new_charm_value
  FROM public.users
  WHERE id = p_receiver_id;
  v_new_charm_level := public.calc_charm_level(v_new_charm_value);

  UPDATE public.users
  SET diamonds = COALESCE(diamonds, 0) + v_host_share,
      charm_value = v_new_charm_value,
      charm_level = v_new_charm_level
  WHERE id = p_receiver_id;

  INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
  VALUES (p_sender_id, -v_total_cost, 'coin', 'gift_sent', p_gift_id);
  IF v_host_share > 0 THEN
    INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
    VALUES (p_receiver_id, v_host_share, 'diamond', 'gift_received', p_gift_id);
  END IF;

  BEGIN
    v_period_id := public.get_period_id_for_date(current_date);
    PERFORM public.ensure_salary_period(v_period_id);
    INSERT INTO public.host_period_stats (user_id, period_id, total_diamonds, charm_points)
    VALUES (p_receiver_id, v_period_id, v_host_share, v_charm_credit)
    ON CONFLICT (user_id, period_id) DO UPDATE SET
      total_diamonds = public.host_period_stats.total_diamonds + EXCLUDED.total_diamonds,
      charm_points = public.host_period_stats.charm_points + EXCLUDED.charm_points;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  INSERT INTO public.gift_logs (sender_id, receiver_id, gift_id, room_id, amount, charm_amount)
  VALUES (p_sender_id, p_receiver_id, p_gift_id, p_room_id, v_total_cost, v_charm_credit)
  RETURNING id INTO v_gift_log_id;

  INSERT INTO public.earning_logs (
    gift_log_id, host_id, host_amount,
    agency_owner_id, agency_amount,
    bd_staff_id, bd_amount,
    bd_admin_staff_id, bd_admin_amount,
    super_bd_staff_id, super_bd_amount,
    official_amount, admin_amount,
    total_gift_value
  ) VALUES (
    v_gift_log_id, p_receiver_id, v_host_share,
    v_agency_owner_id, 0,
    NULL, 0,
    NULL, 0,
    NULL, 0,
    v_official_share, v_official_share,
    v_total_cost
  );

  IF (v_is_lucky OR v_is_lucky_pro) AND NOT v_use_gateway_lucky THEN
    BEGIN
      v_bonus_result := public.process_gift_category_bonus(
        CASE WHEN v_is_lucky_pro THEN 'lucky_pro' ELSE 'lucky' END,
        p_sender_id,
        p_receiver_id,
        p_gift_id,
        v_gift_log_id,
        v_total_cost
      );
      IF v_bonus_result IS NOT NULL THEN
        IF v_is_lucky_pro THEN
          v_lucky_pro_bonus_won := COALESCE((v_bonus_result->>'bonus_won')::boolean, false);
          v_lucky_pro_bonus_coins := COALESCE((v_bonus_result->>'bonus_coins')::bigint, 0);
          v_bonus_coins := COALESCE((v_bonus_result->>'bonus_coins')::bigint, 0);
        ELSE
          v_lucky_bonus_won := COALESCE((v_bonus_result->>'bonus_won')::boolean, false);
          v_bonus_coins := COALESCE((v_bonus_result->>'bonus_coins')::bigint, 0);
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'lucky bonus failed: %', SQLERRM;
    END;
  END IF;

  SELECT username INTO v_receiver_name FROM public.users WHERE id = p_receiver_id;

  RETURN json_build_object(
    'success', true,
    'host_share', v_host_share,
    'host_received', v_host_share,
    'host_credited', (v_host_share > 0),
    'charm_credit', v_charm_credit,
    'agency_share', 0,
    'bd_share', 0,
    'official_share', v_official_share,
    'receiver_name', v_receiver_name,
    'is_lucky_gift', v_is_lucky,
    'is_lucky_pro_gift', v_is_lucky_pro,
    'lucky_bonus_won', v_lucky_bonus_won,
    'lucky_bonus_coins', CASE WHEN v_lucky_bonus_won THEN COALESCE(v_bonus_coins, 0) ELSE 0 END,
    'lucky_pro_bonus_won', v_lucky_pro_bonus_won,
    'lucky_pro_bonus_coins', v_lucky_pro_bonus_coins,
    'bonus_coins', COALESCE(v_bonus_coins, 0),
    'gift_log_id', v_gift_log_id,
    'total_cost', v_total_cost,
    'lucky_engine', CASE WHEN v_use_gateway_lucky THEN 'gateway' ELSE 'postgres' END
  );
END;
$function$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'flush-gift-rank-queue';
    PERFORM cron.schedule(
      'flush-gift-rank-queue',
      '* * * * *',
      $cron$ SELECT public.flush_gift_rank_queue(20000); $cron$
    );
  END IF;
END $$;
