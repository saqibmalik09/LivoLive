-- Allow admin free-hand coin/USD overrides when fulfilling seller packages.
-- p_tier_id may be null for custom credit (no tier rewards).

DROP FUNCTION IF EXISTS public.admin_fulfill_coin_seller_purchase(uuid, uuid, text);

CREATE OR REPLACE FUNCTION public.admin_fulfill_coin_seller_purchase(
  p_user_id uuid,
  p_tier_id uuid DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_coins_override bigint DEFAULT NULL,
  p_usd_override numeric DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_tier public.coin_seller_policy_tiers%ROWTYPE;
  v_settings public.coin_seller_policy_settings%ROWTYPE;
  v_reward RECORD;
  v_plan RECORD;
  v_purchase_id uuid;
  v_rewards jsonb := '[]'::jsonb;
  v_days integer;
  v_expires timestamptz;
  v_now timestamptz := now();
  v_vip_until timestamptz;
  v_current_vip_until timestamptz;
  v_inv_id uuid;
  v_coins bigint;
  v_usd numeric(12, 2);
  v_stock bigint;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF p_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'user_id required');
  END IF;

  SELECT * INTO v_settings FROM public.coin_seller_policy_settings WHERE id = 1;
  IF v_settings.id IS NULL OR v_settings.is_active IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'message', 'Coin seller policy is inactive');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  IF p_tier_id IS NOT NULL THEN
    SELECT * INTO v_tier
    FROM public.coin_seller_policy_tiers
    WHERE id = p_tier_id
    FOR UPDATE;

    IF v_tier.id IS NULL OR v_tier.is_active IS NOT TRUE THEN
      RETURN json_build_object('success', false, 'message', 'Tier not found or inactive');
    END IF;

    v_coins := COALESCE(p_coins_override, v_tier.total_coins);
    v_usd := COALESCE(p_usd_override, v_tier.usd_amount);
  ELSE
    IF p_coins_override IS NULL THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Custom fulfill requires coins amount'
      );
    END IF;
    v_coins := p_coins_override;
    v_usd := COALESCE(p_usd_override, 0);
  END IF;

  IF v_coins = 0 THEN
    RETURN json_build_object('success', false, 'message', 'Coins amount cannot be 0');
  END IF;

  SELECT COALESCE(reseller_coins, 0) INTO v_stock
  FROM public.users WHERE id = p_user_id FOR UPDATE;

  IF v_coins < 0 AND (v_stock + v_coins) < 0 THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Insufficient reseller stock (%s) to deduct %s', v_stock, abs(v_coins))
    );
  END IF;

  UPDATE public.users
  SET
    is_reseller = true,
    reseller_coins = COALESCE(reseller_coins, 0) + v_coins,
    updated_at = v_now
  WHERE id = p_user_id;

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, reference_id, description
  ) VALUES (
    p_user_id,
    abs(v_coins),
    'seller_package',
    'coin',
    COALESCE(p_tier_id::text, 'custom'),
    CASE
      WHEN v_coins < 0 THEN
        format(
          'Coin seller stock adjust −%s (USD %s)%s',
          abs(v_coins),
          v_usd,
          CASE WHEN p_tier_id IS NULL THEN ' — custom' ELSE '' END
        )
      ELSE
        format(
          'Coin seller package $%s — %s coins credited to reseller stock%s',
          v_usd,
          v_coins,
          CASE WHEN p_tier_id IS NULL THEN ' — custom' ELSE '' END
        )
    END
  );

  -- Grant tier rewards only when a real tier is selected (not custom-only).
  IF p_tier_id IS NOT NULL THEN
    FOR v_reward IN
      SELECT *
      FROM public.coin_seller_policy_rewards
      WHERE tier_id = v_tier.id
      ORDER BY sort_order, feature_key
    LOOP
      IF v_reward.feature_key = 'vip' AND v_reward.vip_plan_id IS NOT NULL THEN
        SELECT id, level, name, duration_days
        INTO v_plan
        FROM public.vip_plans
        WHERE id = v_reward.vip_plan_id;

        IF v_plan.id IS NOT NULL THEN
          v_days := COALESCE(v_reward.duration_days, v_plan.duration_days, 30);
          IF v_days < 1 THEN v_days := 30; END IF;

          SELECT vip_until INTO v_current_vip_until FROM public.users WHERE id = p_user_id;
          IF v_current_vip_until IS NOT NULL AND v_current_vip_until > v_now THEN
            v_vip_until := v_current_vip_until + make_interval(days => v_days);
          ELSE
            v_vip_until := v_now + make_interval(days => v_days);
          END IF;

          UPDATE public.users
          SET vip_level = GREATEST(COALESCE(vip_level, 0), COALESCE(v_plan.level, 0)),
              vip_until = v_vip_until,
              updated_at = v_now
          WHERE id = p_user_id;

          BEGIN
            PERFORM public.provision_user_assets(p_user_id);
          EXCEPTION WHEN OTHERS THEN
            NULL;
          END;

          v_rewards := v_rewards || jsonb_build_array(jsonb_build_object(
            'feature_key', 'vip',
            'vip_plan_id', v_plan.id,
            'level', v_plan.level,
            'duration', v_plan.name,
            'duration_days', v_days
          ));
        END IF;

      ELSIF v_reward.shop_item_id IS NOT NULL THEN
        v_days := v_reward.duration_days;
        IF v_days IS NULL OR v_days <= 0 THEN
          v_expires := '9999-12-31T00:00:00Z'::timestamptz;
        ELSE
          v_expires := v_now + make_interval(days => v_days);
        END IF;

        SELECT id INTO v_inv_id
        FROM public.user_inventory
        WHERE user_id = p_user_id AND item_id = v_reward.shop_item_id;

        IF v_inv_id IS NULL THEN
          INSERT INTO public.user_inventory (user_id, item_id, expires_at, is_equipped, source)
          VALUES (p_user_id, v_reward.shop_item_id, v_expires, false, 'coin_seller_policy')
          RETURNING id INTO v_inv_id;
        ELSE
          UPDATE public.user_inventory
          SET expires_at = CASE
                WHEN expires_at > v_now AND v_days IS NOT NULL AND v_days > 0
                  THEN expires_at + make_interval(days => v_days)
                ELSE v_expires
              END,
              source = COALESCE(source, 'coin_seller_policy')
          WHERE id = v_inv_id;
        END IF;

        v_rewards := v_rewards || jsonb_build_array(jsonb_build_object(
          'feature_key', v_reward.feature_key,
          'shop_item_id', v_reward.shop_item_id,
          'label', v_reward.label,
          'duration_days', v_days,
          'inventory_id', v_inv_id
        ));
      END IF;
    END LOOP;
  END IF;

  INSERT INTO public.coin_seller_purchases (
    user_id, tier_id, usd_amount, coins_credited, rewards_json, notes
  ) VALUES (
    p_user_id, p_tier_id, v_usd, v_coins, v_rewards, p_notes
  )
  RETURNING id INTO v_purchase_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Seller package fulfilled',
    'purchase_id', v_purchase_id,
    'coins_credited', v_coins,
    'usd_amount', v_usd,
    'rewards', v_rewards
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_fulfill_coin_seller_purchase(uuid, uuid, text, bigint, numeric)
  TO service_role;
