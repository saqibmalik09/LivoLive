-- Coin Seller Policy: settings, tiers, rewards, purchases, fulfill RPC

-- 1) Settings (singleton)
CREATE TABLE IF NOT EXISTS public.coin_seller_policy_settings (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  coins_per_usd bigint NOT NULL DEFAULT 88000,
  min_recharge_usd numeric(12, 2) NOT NULL DEFAULT 500,
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.coin_seller_policy_settings (id, coins_per_usd, min_recharge_usd, is_active)
VALUES (1, 88000, 500, true)
ON CONFLICT (id) DO NOTHING;

-- 2) Tiers
CREATE TABLE IF NOT EXISTS public.coin_seller_policy_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  usd_amount numeric(12, 2) NOT NULL,
  basic_coins bigint NOT NULL,
  bonus_ratio_percent numeric(8, 2) NOT NULL DEFAULT 100,
  total_coins bigint NOT NULL,
  label text,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS coin_seller_policy_tiers_sort_idx
  ON public.coin_seller_policy_tiers (sort_order, usd_amount);

-- 3) Rewards per tier
CREATE TABLE IF NOT EXISTS public.coin_seller_policy_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_id uuid NOT NULL REFERENCES public.coin_seller_policy_tiers(id) ON DELETE CASCADE,
  feature_key text NOT NULL CHECK (feature_key = ANY (ARRAY['vip'::text, 'frame'::text, 'entrance'::text, 'custom'::text])),
  vip_plan_id uuid,
  shop_item_id uuid REFERENCES public.shop_items(id) ON DELETE SET NULL,
  duration_days integer,
  label text,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tier_id, feature_key)
);

CREATE INDEX IF NOT EXISTS coin_seller_policy_rewards_tier_idx
  ON public.coin_seller_policy_rewards (tier_id, sort_order);

-- 4) Purchase audit log
CREATE TABLE IF NOT EXISTS public.coin_seller_purchases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  tier_id uuid REFERENCES public.coin_seller_policy_tiers(id) ON DELETE SET NULL,
  usd_amount numeric(12, 2) NOT NULL,
  coins_credited bigint NOT NULL,
  rewards_json jsonb NOT NULL DEFAULT '[]'::jsonb,
  fulfilled_by uuid,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS coin_seller_purchases_user_idx
  ON public.coin_seller_purchases (user_id, created_at DESC);

-- Seed poster tiers (only if empty)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.coin_seller_policy_tiers LIMIT 1) THEN
    INSERT INTO public.coin_seller_policy_tiers
      (usd_amount, basic_coins, bonus_ratio_percent, total_coins, label, is_active, sort_order)
    VALUES
      (500,  44000000,  127, 55880000,  '$500',  true, 1),
      (1000, 88000000,  130, 114400000, '$1000', true, 2),
      (3000, 264000000, 132, 343680000, '$3000', true, 3),
      (5000, 440000000, 135, 594000000, '$5000', true, 4);
  END IF;
END $$;

-- Allow seller_package transaction type
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
ALTER TABLE public.transactions
  ADD CONSTRAINT transactions_transaction_type_check
  CHECK (transaction_type = ANY (ARRAY[
    'recharge'::text, 'gift_sent'::text, 'gift_received'::text, 'lucky_gift_bonus'::text,
    'game_win'::text, 'game_loss'::text, 'withdrawal'::text, 'purchase'::text,
    'agency_commission'::text, 'salary_payout'::text, 'transfer_out'::text, 'transfer_in'::text,
    'exchange'::text, 'rupee_game_entry'::text, 'rupee_game_refund'::text, 'lucky_pro_gift_bonus'::text,
    'room_reward'::text, 'weekly_room_reward'::text, 'invite_register_bonus'::text,
    'invite_welcome_bonus'::text, 'invite_milestone'::text, 'invite_wheel'::text,
    'invite_first_recharge'::text, 'invite_recharge_bonus'::text, 'task_checkin'::text,
    'task_wheel'::text, 'task_reward'::text, 'cash_exchange_self'::text,
    'cash_exchange_other_out'::text, 'cash_exchange_other_in'::text, 'withdrawal_hold'::text,
    'withdrawal_refund'::text, 'real_name_deposit'::text, 'seller_package'::text
  ]));

-- RLS: authenticated can read policy (mobile); writes via service role / admin
ALTER TABLE public.coin_seller_policy_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_seller_policy_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_seller_policy_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_seller_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS coin_seller_settings_read ON public.coin_seller_policy_settings;
CREATE POLICY coin_seller_settings_read ON public.coin_seller_policy_settings
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS coin_seller_tiers_read ON public.coin_seller_policy_tiers;
CREATE POLICY coin_seller_tiers_read ON public.coin_seller_policy_tiers
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS coin_seller_rewards_read ON public.coin_seller_policy_rewards;
CREATE POLICY coin_seller_rewards_read ON public.coin_seller_policy_rewards
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS coin_seller_purchases_own_read ON public.coin_seller_purchases;
CREATE POLICY coin_seller_purchases_own_read ON public.coin_seller_purchases
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Fulfill RPC (service_role only — called from admin with service key)
CREATE OR REPLACE FUNCTION public.admin_fulfill_coin_seller_purchase(
  p_user_id uuid,
  p_tier_id uuid,
  p_notes text DEFAULT NULL
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
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF p_user_id IS NULL OR p_tier_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'user_id and tier_id required');
  END IF;

  SELECT * INTO v_settings FROM public.coin_seller_policy_settings WHERE id = 1;
  IF v_settings.id IS NULL OR v_settings.is_active IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'message', 'Coin seller policy is inactive');
  END IF;

  SELECT * INTO v_tier
  FROM public.coin_seller_policy_tiers
  WHERE id = p_tier_id
  FOR UPDATE;

  IF v_tier.id IS NULL OR v_tier.is_active IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'message', 'Tier not found or inactive');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  -- Ensure reseller + credit stock
  UPDATE public.users
  SET
    is_reseller = true,
    reseller_coins = COALESCE(reseller_coins, 0) + v_tier.total_coins,
    updated_at = v_now
  WHERE id = p_user_id;

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, reference_id, description
  ) VALUES (
    p_user_id,
    v_tier.total_coins,
    'seller_package',
    'coin',
    p_tier_id,
    format('Coin seller package $%s — %s coins credited to reseller stock', v_tier.usd_amount, v_tier.total_coins)
  );

  -- Grant rewards
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

  INSERT INTO public.coin_seller_purchases (
    user_id, tier_id, usd_amount, coins_credited, rewards_json, notes
  ) VALUES (
    p_user_id, v_tier.id, v_tier.usd_amount, v_tier.total_coins, v_rewards, p_notes
  )
  RETURNING id INTO v_purchase_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Seller package fulfilled',
    'purchase_id', v_purchase_id,
    'coins_credited', v_tier.total_coins,
    'usd_amount', v_tier.usd_amount,
    'rewards', v_rewards
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.admin_fulfill_coin_seller_purchase(uuid, uuid, text) TO service_role;
