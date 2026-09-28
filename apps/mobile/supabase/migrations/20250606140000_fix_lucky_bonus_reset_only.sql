-- Fix: bonus only after 3–4 lucky gifts, then counter resets (not every gift after)

CREATE TABLE IF NOT EXISTS public.lucky_gift_sender_counters (
  sender_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  gift_count integer NOT NULL DEFAULT 0,
  next_bonus_at integer NOT NULL DEFAULT 3
);

CREATE OR REPLACE FUNCTION public.send_gift(
  p_sender_id uuid,
  p_receiver_id uuid,
  p_gift_id uuid,
  p_room_id uuid,
  p_quantity integer DEFAULT 1
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_gift_price INT;
  v_category_name TEXT;
  v_is_lucky BOOLEAN := false;
  v_total_cost BIGINT;
  v_sender_coins BIGINT;
  v_host_pc INT;
  v_agency_pc INT;
  v_admin_pc INT;
  v_agency_id UUID;
  v_agency_owner_id UUID;
  v_host_share INT;
  v_agency_share INT := 0;
  v_admin_share INT;
  v_remainder BIGINT;
  v_new_wealth_value BIGINT;
  v_new_wealth_level INT;
  v_new_charm_value BIGINT;
  v_new_charm_level INT;
  v_exp_multiplier FLOAT;
  v_hotness_multiplier FLOAT;
  v_gift_log_id UUID;
  v_week_id TEXT;
  v_couple_id UUID;
  v_new_cp_exp BIGINT;
  v_new_cp_level INT;
  v_family_id UUID;
  v_new_family_exp BIGINT;
  v_new_family_level INT;
  v_lucky_cfg RECORD;
  v_gift_count INT := 0;
  v_threshold INT := 0;
  v_bonus_coins BIGINT;
  v_multiplier NUMERIC;
  v_lucky_bonus_won BOOLEAN := false;
  v_use_sender_counter BOOLEAN := false;
  v_receiver_name TEXT;
  v_bonus_mode TEXT;
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
  v_total_cost := v_gift_price * p_quantity;

  SELECT coins INTO v_sender_coins FROM public.users WHERE id = p_sender_id FOR UPDATE;
  IF v_sender_coins < v_total_cost THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  SELECT host_pc, agency_pc, admin_pc INTO v_host_pc, v_agency_pc, v_admin_pc FROM public.commission_configs WHERE id = 1;

  SELECT am.agency_id, a.owner_id INTO v_agency_id, v_agency_owner_id
  FROM public.agency_members am
  JOIN public.agencies a ON a.id = am.agency_id
  WHERE am.user_id = p_receiver_id AND a.is_active = TRUE;

  IF v_is_lucky THEN
    SELECT * INTO v_lucky_cfg FROM public.lucky_gift_config WHERE id = 1;
    v_host_share := (v_total_cost * v_lucky_cfg.receiver_percent::numeric / 100)::int;
    v_remainder := v_total_cost - v_host_share;
    IF v_agency_owner_id IS NOT NULL AND (v_agency_pc + v_admin_pc) > 0 THEN
      v_agency_share := (v_remainder * v_agency_pc) / (v_agency_pc + v_admin_pc);
      v_admin_share := v_remainder - v_agency_share;
    ELSE
      v_agency_share := 0;
      v_admin_share := v_remainder;
    END IF;
  ELSE
    v_host_share := (v_total_cost * v_host_pc) / 100;
    IF v_agency_owner_id IS NOT NULL THEN
      v_agency_share := (v_total_cost * v_agency_pc) / 100;
      v_admin_share := v_total_cost - v_host_share - v_agency_share;
    ELSE
      v_agency_share := 0;
      v_admin_share := v_total_cost - v_host_share;
    END IF;
  END IF;

  SELECT (wealth_value + v_total_cost) INTO v_new_wealth_value FROM public.users WHERE id = p_sender_id;
  SELECT level INTO v_new_wealth_level FROM public.level_configs
    WHERE category = 'wealth' AND min_exp <= v_new_wealth_value ORDER BY level DESC LIMIT 1;
  IF v_new_wealth_level IS NULL THEN v_new_wealth_level := 1; END IF;

  UPDATE public.users SET coins = coins - v_total_cost, wealth_value = v_new_wealth_value, wealth_level = v_new_wealth_level
  WHERE id = p_sender_id;

  SELECT (charm_value + v_total_cost) INTO v_new_charm_value FROM public.users WHERE id = p_receiver_id;
  SELECT level INTO v_new_charm_level FROM public.level_configs
    WHERE category = 'charm' AND min_exp <= v_new_charm_value ORDER BY level DESC LIMIT 1;
  IF v_new_charm_level IS NULL THEN v_new_charm_level := 1; END IF;

  UPDATE public.users SET diamonds = diamonds + v_host_share, charm_value = v_new_charm_value, charm_level = v_new_charm_level
  WHERE id = p_receiver_id;

  IF v_agency_owner_id IS NOT NULL AND v_agency_share > 0 THEN
    UPDATE public.users SET diamonds = diamonds + v_agency_share WHERE id = v_agency_owner_id;
  END IF;

  INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
  VALUES (p_sender_id, -v_total_cost, 'coin', 'gift_sent', p_gift_id),
         (p_receiver_id, v_host_share, 'diamond', 'gift_received', p_gift_id);

  IF v_agency_owner_id IS NOT NULL AND v_agency_share > 0 THEN
    INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
    VALUES (v_agency_owner_id, v_agency_share, 'diamond', 'agency_commission', p_gift_id);
  END IF;

  INSERT INTO public.gift_logs (sender_id, receiver_id, gift_id, room_id, amount)
  VALUES (p_sender_id, p_receiver_id, p_gift_id, p_room_id, v_total_cost)
  RETURNING id INTO v_gift_log_id;

  INSERT INTO public.earning_logs (gift_log_id, host_id, host_amount, agency_owner_id, agency_amount, admin_amount, total_gift_value)
  VALUES (v_gift_log_id, p_receiver_id, v_host_share, v_agency_owner_id, v_agency_share, v_admin_share, v_total_cost);

  v_week_id := to_char(now(), 'IYYY-IW');
  INSERT INTO public.host_weekly_stats (user_id, week_id, total_diamonds)
  VALUES (p_receiver_id, v_week_id, v_host_share)
  ON CONFLICT (user_id, week_id) DO UPDATE SET
    total_diamonds = public.host_weekly_stats.total_diamonds + v_host_share, updated_at = now();

  IF p_room_id IS NOT NULL THEN
    SELECT exp_per_unit, hotness_per_unit INTO v_exp_multiplier, v_hotness_multiplier
    FROM public.room_activity_configs WHERE activity_type = 'gift';
    INSERT INTO public.room_stats (room_id, total_exp, hotness_score)
    VALUES (p_room_id, (v_total_cost * COALESCE(v_exp_multiplier, 1.0))::bigint, (v_total_cost * COALESCE(v_hotness_multiplier, 1.0))::bigint)
    ON CONFLICT (room_id) DO UPDATE SET
      total_exp = public.room_stats.total_exp + (v_total_cost * COALESCE(v_exp_multiplier, 1.0))::bigint,
      hotness_score = public.room_stats.hotness_score + (v_total_cost * COALESCE(v_hotness_multiplier, 1.0))::bigint,
      updated_at = now();
  END IF;

  SELECT id, cp_exp INTO v_couple_id, v_new_cp_exp FROM public.couples
  WHERE (user1_id = p_sender_id AND user2_id = p_receiver_id) OR (user1_id = p_receiver_id AND user2_id = p_sender_id)
  FOR UPDATE;
  IF v_couple_id IS NOT NULL THEN
    v_new_cp_exp := v_new_cp_exp + v_total_cost;
    SELECT level INTO v_new_cp_level FROM public.cp_level_configs WHERE min_exp <= v_new_cp_exp ORDER BY level DESC LIMIT 1;
    IF v_new_cp_level IS NULL THEN v_new_cp_level := 1; END IF;
    UPDATE public.couples SET cp_exp = v_new_cp_exp, cp_level = v_new_cp_level WHERE id = v_couple_id;
  END IF;

  SELECT family_id INTO v_family_id FROM public.family_members WHERE user_id = p_sender_id;
  IF v_family_id IS NOT NULL THEN
    SELECT total_exp INTO v_new_family_exp FROM public.families WHERE id = v_family_id FOR UPDATE;
    v_new_family_exp := v_new_family_exp + v_total_cost;
    SELECT level INTO v_new_family_level FROM public.family_level_configs WHERE min_exp <= v_new_family_exp ORDER BY level DESC LIMIT 1;
    IF v_new_family_level IS NULL THEN v_new_family_level := 1; END IF;
    UPDATE public.families SET total_exp = v_new_family_exp, level = v_new_family_level WHERE id = v_family_id;
  END IF;

  SELECT family_id INTO v_family_id FROM public.family_members WHERE user_id = p_receiver_id;
  IF v_family_id IS NOT NULL THEN
    SELECT total_exp INTO v_new_family_exp FROM public.families WHERE id = v_family_id FOR UPDATE;
    v_new_family_exp := v_new_family_exp + v_total_cost;
    SELECT level INTO v_new_family_level FROM public.family_level_configs WHERE min_exp <= v_new_family_exp ORDER BY level DESC LIMIT 1;
    IF v_new_family_level IS NULL THEN v_new_family_level := 1; END IF;
    UPDATE public.families SET total_exp = v_new_family_exp, level = v_new_family_level WHERE id = v_family_id;
  END IF;

  -- Lucky: ONE bonus per streak of 3–4 gifts, then counter resets to 0
  IF v_is_lucky THEN
    SELECT * INTO v_lucky_cfg FROM public.lucky_gift_config WHERE id = 1;
    v_bonus_mode := v_lucky_cfg.bonus_trigger_mode;
    v_use_sender_counter := v_bonus_mode IN ('random', 'both');

    IF v_use_sender_counter THEN
      INSERT INTO public.lucky_gift_sender_counters (sender_id, gift_count, next_bonus_at)
      VALUES (
        p_sender_id, 1,
        public.lucky_gift_random_threshold(v_lucky_cfg.gifts_for_bonus_min, v_lucky_cfg.gifts_for_bonus_max)
      )
      ON CONFLICT (sender_id) DO UPDATE SET
        gift_count = public.lucky_gift_sender_counters.gift_count + 1
      RETURNING gift_count, next_bonus_at INTO v_gift_count, v_threshold;
    ELSE
      INSERT INTO public.lucky_gift_counters (sender_id, receiver_id, gift_count, next_bonus_at)
      VALUES (
        p_sender_id, p_receiver_id, 1,
        public.lucky_gift_random_threshold(v_lucky_cfg.gifts_for_bonus_min, v_lucky_cfg.gifts_for_bonus_max)
      )
      ON CONFLICT (sender_id, receiver_id) DO UPDATE SET
        gift_count = public.lucky_gift_counters.gift_count + 1
      RETURNING gift_count, next_bonus_at INTO v_gift_count, v_threshold;
    END IF;

    IF v_gift_count >= v_threshold OR v_gift_count >= v_lucky_cfg.gifts_for_bonus_max THEN
      IF (random() * 100) < v_lucky_cfg.bonus_chance_percent THEN
        v_multiplier := v_lucky_cfg.bonus_multiplier_min
          + (random() * (v_lucky_cfg.bonus_multiplier_max - v_lucky_cfg.bonus_multiplier_min));
        v_bonus_coins := ceil(v_total_cost * v_multiplier)::bigint;
        IF v_bonus_coins <= v_total_cost THEN v_bonus_coins := v_total_cost + 1; END IF;

        UPDATE public.users SET coins = coins + v_bonus_coins WHERE id = p_sender_id;

        INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
        VALUES (p_sender_id, v_bonus_coins, 'coin', 'lucky_gift_bonus', p_gift_id);

        INSERT INTO public.lucky_gift_bonus_logs (sender_id, receiver_id, gift_id, gift_log_id, gift_value, bonus_coins)
        VALUES (p_sender_id, p_receiver_id, p_gift_id, v_gift_log_id, v_total_cost, v_bonus_coins);

        SELECT username INTO v_receiver_name FROM public.users WHERE id = p_receiver_id;

        INSERT INTO public.system_notifications (user_id, title, content, type, icon_type)
        VALUES (
          p_sender_id, 'Lucky Gift Bonus!',
          format('You won %s coins! Lucky bonus after %s lucky gifts (last gift %s coins to %s).',
            v_bonus_coins, v_gift_count, v_total_cost, COALESCE(v_receiver_name, 'user')),
          'lucky_gift', 'gift'
        );

        v_lucky_bonus_won := true;
      END IF;

      -- Always reset after streak ends (bonus given OR max gifts reached without win)
      IF v_lucky_bonus_won OR v_gift_count >= v_lucky_cfg.gifts_for_bonus_max THEN
        IF v_use_sender_counter THEN
          UPDATE public.lucky_gift_sender_counters SET
            gift_count = 0,
            next_bonus_at = public.lucky_gift_random_threshold(
              v_lucky_cfg.gifts_for_bonus_min, v_lucky_cfg.gifts_for_bonus_max)
          WHERE sender_id = p_sender_id;
        ELSE
          UPDATE public.lucky_gift_counters SET
            gift_count = 0,
            next_bonus_at = public.lucky_gift_random_threshold(
              v_lucky_cfg.gifts_for_bonus_min, v_lucky_cfg.gifts_for_bonus_max)
          WHERE sender_id = p_sender_id AND receiver_id = p_receiver_id;
        END IF;
        v_gift_count := 0;
        v_threshold := public.lucky_gift_random_threshold(
          v_lucky_cfg.gifts_for_bonus_min, v_lucky_cfg.gifts_for_bonus_max);
      END IF;
    END IF;
  END IF;

  PERFORM public.provision_user_assets(p_sender_id);
  PERFORM public.provision_user_assets(p_receiver_id);

  RETURN json_build_object(
    'success', true,
    'new_wealth_level', v_new_wealth_level,
    'new_cp_level', v_new_cp_level,
    'new_family_level', v_new_family_level,
    'host_received', v_host_share,
    'is_lucky_gift', v_is_lucky,
    'lucky_bonus_won', v_lucky_bonus_won,
    'lucky_bonus_coins', COALESCE(v_bonus_coins, 0),
    'lucky_gift_count', v_gift_count,
    'lucky_gifts_until_bonus', CASE
      WHEN v_is_lucky THEN GREATEST(0, v_threshold - v_gift_count)
      ELSE NULL
    END,
    'lucky_bonus_mode', CASE WHEN v_is_lucky THEN v_bonus_mode ELSE NULL END
  );
END;
$function$;
