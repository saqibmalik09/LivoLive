-- send_gift returns host_share; clients also expect host_received + host_credited.

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
SET search_path TO 'public'
AS $function$
DECLARE
  v_gift_price INT;
  v_category_name TEXT;
  v_is_lucky BOOLEAN := false;
  v_is_lucky_pro BOOLEAN := false;
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
  v_exp_multiplier FLOAT;
  v_hotness_multiplier FLOAT;
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
  v_total_cost := v_gift_price * p_quantity;

  SELECT coins INTO v_sender_coins FROM public.users WHERE id = p_sender_id FOR UPDATE;
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

  SELECT (wealth_value + v_total_cost) INTO v_new_wealth_value FROM public.users WHERE id = p_sender_id;
  v_new_wealth_level := public.calc_wealth_level(v_new_wealth_value);

  UPDATE public.users SET coins = coins - v_total_cost, wealth_value = v_new_wealth_value, wealth_level = v_new_wealth_level
  WHERE id = p_sender_id;

  SELECT (charm_value + v_charm_credit) INTO v_new_charm_value FROM public.users WHERE id = p_receiver_id;
  v_new_charm_level := public.calc_charm_level(v_new_charm_value);

  UPDATE public.users SET diamonds = diamonds + v_host_share, charm_value = v_new_charm_value, charm_level = v_new_charm_level
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

  BEGIN
    SELECT exp_multiplier, hotness_multiplier INTO v_exp_multiplier, v_hotness_multiplier
    FROM public.gifts WHERE id = p_gift_id;
  EXCEPTION WHEN OTHERS THEN
    v_exp_multiplier := 1; v_hotness_multiplier := 1;
  END;

  BEGIN
    PERFORM public.add_room_exp(p_room_id, (v_total_cost * COALESCE(v_exp_multiplier, 1))::bigint);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    PERFORM public.add_room_hotness(p_room_id, (v_total_cost * COALESCE(v_hotness_multiplier, 1))::bigint);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  IF v_is_lucky OR v_is_lucky_pro THEN
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
    'gift_log_id', v_gift_log_id
  );
END;
$function$;
