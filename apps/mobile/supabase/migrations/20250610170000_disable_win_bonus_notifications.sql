-- Stop creating win-bonus rows in system_notifications (Lucky / Lucky Pro).
-- Also remove existing bonus notification rows.

DELETE FROM public.system_notifications
WHERE type IN ('lucky_gift', 'lucky_pro_gift', 'game_win');

CREATE OR REPLACE FUNCTION public.process_gift_category_bonus(
  p_variant text,
  p_sender_id uuid,
  p_receiver_id uuid,
  p_gift_id uuid,
  p_gift_log_id uuid,
  p_total_cost bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_cfg RECORD;
  v_gift_count INT := 0;
  v_threshold INT := 0;
  v_bonus_coins BIGINT := 0;
  v_multiplier NUMERIC;
  v_bonus_won BOOLEAN := false;
  v_use_sender_counter BOOLEAN := false;
  v_bonus_mode TEXT;
  v_sender_daily BIGINT := 0;
  v_global_daily BIGINT := 0;
  v_last_bonus_at TIMESTAMPTZ;
  v_can_award BOOLEAN := true;
  v_tx_type TEXT;
BEGIN
  IF p_variant = 'lucky_pro' THEN
    SELECT * INTO v_cfg FROM public.lucky_pro_gift_config WHERE id = 1;
    v_tx_type := 'lucky_pro_gift_bonus';
  ELSE
    SELECT * INTO v_cfg FROM public.lucky_gift_config WHERE id = 1;
    v_tx_type := 'lucky_gift_bonus';
  END IF;

  IF v_cfg IS NULL THEN
    RETURN json_build_object(
      'bonus_won', false, 'bonus_coins', 0, 'gift_count', 0, 'threshold', 0, 'bonus_mode', NULL
    );
  END IF;

  v_bonus_mode := v_cfg.bonus_trigger_mode;
  v_use_sender_counter := v_bonus_mode IN ('random', 'both');

  IF p_variant = 'lucky_pro' THEN
    IF v_use_sender_counter THEN
      INSERT INTO public.lucky_pro_gift_sender_counters (sender_id, gift_count, next_bonus_at)
      VALUES (p_sender_id, 1, public.lucky_gift_random_threshold(v_cfg.gifts_for_bonus_min, v_cfg.gifts_for_bonus_max))
      ON CONFLICT (sender_id) DO UPDATE SET gift_count = public.lucky_pro_gift_sender_counters.gift_count + 1
      RETURNING gift_count, next_bonus_at INTO v_gift_count, v_threshold;
    ELSE
      INSERT INTO public.lucky_pro_gift_counters (sender_id, receiver_id, gift_count, next_bonus_at)
      VALUES (p_sender_id, p_receiver_id, 1, public.lucky_gift_random_threshold(v_cfg.gifts_for_bonus_min, v_cfg.gifts_for_bonus_max))
      ON CONFLICT (sender_id, receiver_id) DO UPDATE SET gift_count = public.lucky_pro_gift_counters.gift_count + 1
      RETURNING gift_count, next_bonus_at INTO v_gift_count, v_threshold;
    END IF;
  ELSE
    IF v_use_sender_counter THEN
      INSERT INTO public.lucky_gift_sender_counters (sender_id, gift_count, next_bonus_at)
      VALUES (p_sender_id, 1, public.lucky_gift_random_threshold(v_cfg.gifts_for_bonus_min, v_cfg.gifts_for_bonus_max))
      ON CONFLICT (sender_id) DO UPDATE SET gift_count = public.lucky_gift_sender_counters.gift_count + 1
      RETURNING gift_count, next_bonus_at INTO v_gift_count, v_threshold;
    ELSE
      INSERT INTO public.lucky_gift_counters (sender_id, receiver_id, gift_count, next_bonus_at)
      VALUES (p_sender_id, p_receiver_id, 1, public.lucky_gift_random_threshold(v_cfg.gifts_for_bonus_min, v_cfg.gifts_for_bonus_max))
      ON CONFLICT (sender_id, receiver_id) DO UPDATE SET gift_count = public.lucky_gift_counters.gift_count + 1
      RETURNING gift_count, next_bonus_at INTO v_gift_count, v_threshold;
    END IF;
  END IF;

  IF NOT v_cfg.is_enabled THEN v_can_award := false; END IF;
  IF p_total_cost < v_cfg.min_gift_value_for_bonus THEN v_can_award := false; END IF;

  IF v_can_award AND v_cfg.cooldown_seconds > 0 THEN
    IF p_variant = 'lucky_pro' THEN
      SELECT created_at INTO v_last_bonus_at FROM public.lucky_pro_gift_bonus_logs
      WHERE sender_id = p_sender_id ORDER BY created_at DESC LIMIT 1;
    ELSE
      SELECT created_at INTO v_last_bonus_at FROM public.lucky_gift_bonus_logs
      WHERE sender_id = p_sender_id ORDER BY created_at DESC LIMIT 1;
    END IF;
    IF v_last_bonus_at IS NOT NULL AND (now() - v_last_bonus_at) < make_interval(secs => v_cfg.cooldown_seconds) THEN
      v_can_award := false;
    END IF;
  END IF;

  IF v_gift_count >= v_threshold OR v_gift_count >= v_cfg.gifts_for_bonus_max THEN
    IF v_can_award AND (random() * 100) < v_cfg.bonus_chance_percent THEN
      IF p_variant = 'lucky_pro' THEN
        SELECT COALESCE(SUM(bonus_coins), 0) INTO v_sender_daily
        FROM public.lucky_pro_gift_bonus_logs
        WHERE sender_id = p_sender_id AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC');
        SELECT COALESCE(SUM(bonus_coins), 0) INTO v_global_daily
        FROM public.lucky_pro_gift_bonus_logs
        WHERE created_at >= date_trunc('day', now() AT TIME ZONE 'UTC');
      ELSE
        SELECT COALESCE(SUM(bonus_coins), 0) INTO v_sender_daily
        FROM public.lucky_gift_bonus_logs
        WHERE sender_id = p_sender_id AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC');
        SELECT COALESCE(SUM(bonus_coins), 0) INTO v_global_daily
        FROM public.lucky_gift_bonus_logs
        WHERE created_at >= date_trunc('day', now() AT TIME ZONE 'UTC');
      END IF;

      v_multiplier := v_cfg.bonus_multiplier_min
        + (random() * (v_cfg.bonus_multiplier_max - v_cfg.bonus_multiplier_min));
      v_bonus_coins := ceil(p_total_cost * v_multiplier)::bigint;
      IF v_bonus_coins <= p_total_cost THEN v_bonus_coins := p_total_cost + 1; END IF;

      IF v_cfg.max_bonus_coins_per_win IS NOT NULL THEN
        v_bonus_coins := LEAST(v_bonus_coins, v_cfg.max_bonus_coins_per_win);
      END IF;

      IF v_cfg.max_daily_bonus_per_sender IS NOT NULL
         AND (v_sender_daily + v_bonus_coins) > v_cfg.max_daily_bonus_per_sender THEN
        v_can_award := false;
      END IF;

      IF v_can_award AND v_cfg.max_daily_bonus_global IS NOT NULL
         AND (v_global_daily + v_bonus_coins) > v_cfg.max_daily_bonus_global THEN
        v_can_award := false;
      END IF;

      IF v_can_award THEN
        UPDATE public.users SET coins = coins + v_bonus_coins WHERE id = p_sender_id;

        INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
        VALUES (p_sender_id, v_bonus_coins, 'coin', v_tx_type, p_gift_id);

        IF p_variant = 'lucky_pro' THEN
          INSERT INTO public.lucky_pro_gift_bonus_logs (sender_id, receiver_id, gift_id, gift_log_id, gift_value, bonus_coins)
          VALUES (p_sender_id, p_receiver_id, p_gift_id, p_gift_log_id, p_total_cost, v_bonus_coins);
        ELSE
          INSERT INTO public.lucky_gift_bonus_logs (sender_id, receiver_id, gift_id, gift_log_id, gift_value, bonus_coins)
          VALUES (p_sender_id, p_receiver_id, p_gift_id, p_gift_log_id, p_total_cost, v_bonus_coins);
        END IF;

        v_bonus_won := true;
      END IF;
    END IF;

    IF v_bonus_won OR v_gift_count >= v_cfg.gifts_for_bonus_max THEN
      IF p_variant = 'lucky_pro' THEN
        IF v_use_sender_counter THEN
          UPDATE public.lucky_pro_gift_sender_counters SET
            gift_count = 0,
            next_bonus_at = public.lucky_gift_random_threshold(v_cfg.gifts_for_bonus_min, v_cfg.gifts_for_bonus_max)
          WHERE sender_id = p_sender_id;
        ELSE
          UPDATE public.lucky_pro_gift_counters SET
            gift_count = 0,
            next_bonus_at = public.lucky_gift_random_threshold(v_cfg.gifts_for_bonus_min, v_cfg.gifts_for_bonus_max)
          WHERE sender_id = p_sender_id AND receiver_id = p_receiver_id;
        END IF;
      ELSE
        IF v_use_sender_counter THEN
          UPDATE public.lucky_gift_sender_counters SET
            gift_count = 0,
            next_bonus_at = public.lucky_gift_random_threshold(v_cfg.gifts_for_bonus_min, v_cfg.gifts_for_bonus_max)
          WHERE sender_id = p_sender_id;
        ELSE
          UPDATE public.lucky_gift_counters SET
            gift_count = 0,
            next_bonus_at = public.lucky_gift_random_threshold(v_cfg.gifts_for_bonus_min, v_cfg.gifts_for_bonus_max)
          WHERE sender_id = p_sender_id AND receiver_id = p_receiver_id;
        END IF;
      END IF;
      v_gift_count := 0;
      v_threshold := public.lucky_gift_random_threshold(v_cfg.gifts_for_bonus_min, v_cfg.gifts_for_bonus_max);
    END IF;
  END IF;

  RETURN json_build_object(
    'bonus_won', v_bonus_won,
    'bonus_coins', COALESCE(v_bonus_coins, 0),
    'gift_count', v_gift_count,
    'threshold', v_threshold,
    'bonus_mode', v_bonus_mode
  );
END;
$function$;
