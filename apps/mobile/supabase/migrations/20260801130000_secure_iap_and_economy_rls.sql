-- Harden economy: block client self-credit, secure IAP delivery, enable missing RLS.

-- 1) Receipts for idempotent IAP (one purchase_id → one credit)
CREATE TABLE IF NOT EXISTS public.iap_purchase_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  product_id text NOT NULL,
  purchase_id text NOT NULL,
  purchase_token text,
  coins_credited bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT iap_purchase_receipts_purchase_id_key UNIQUE (purchase_id)
);

CREATE INDEX IF NOT EXISTS iap_purchase_receipts_user_idx
  ON public.iap_purchase_receipts (user_id, created_at DESC);

ALTER TABLE public.iap_purchase_receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users read own iap receipts" ON public.iap_purchase_receipts;
CREATE POLICY "users read own iap receipts"
  ON public.iap_purchase_receipts FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- 2) Prevent authenticated clients from writing economy columns on users
CREATE OR REPLACE FUNCTION public.protect_user_economy_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_role text := coalesce(auth.jwt() ->> 'role', '');
BEGIN
  IF v_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- SECURITY DEFINER RPCs (games, gift, salary, IAP) run as table owner
  IF current_user IN ('postgres', 'supabase_admin') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    NEW.coins := OLD.coins;
    NEW.diamonds := OLD.diamonds;
    NEW.beans := OLD.beans;
    NEW.cash_balance := OLD.cash_balance;
    NEW.reseller_coins := OLD.reseller_coins;
    NEW.wealth_value := OLD.wealth_value;
    NEW.charm_value := OLD.charm_value;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_protect_user_economy ON public.users;
CREATE TRIGGER trg_protect_user_economy
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_user_economy_columns();

-- 3) Stop client inserts into transactions (RPCs / service_role only)
DROP POLICY IF EXISTS "System can insert transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
-- No INSERT policy for authenticated → denied. Table owner / service_role bypass.

-- 4) Secure IAP credit (amount from DB package, not client; purchase_id unique)
CREATE OR REPLACE FUNCTION public.deliver_iap_purchase(
  p_product_id text,
  p_purchase_id text,
  p_purchase_token text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_pkg public.recharge_packages%ROWTYPE;
  v_coins bigint;
  v_existing public.iap_purchase_receipts%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_product_id IS NULL OR length(trim(p_product_id)) = 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid product');
  END IF;

  IF p_purchase_id IS NULL OR length(trim(p_purchase_id)) = 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid purchase id');
  END IF;

  SELECT * INTO v_existing
  FROM public.iap_purchase_receipts
  WHERE purchase_id = p_purchase_id;

  IF FOUND THEN
    RETURN json_build_object(
      'success', true,
      'message', 'Already credited',
      'duplicate', true,
      'coins', v_existing.coins_credited
    );
  END IF;

  SELECT * INTO v_pkg
  FROM public.recharge_packages
  WHERE play_store_id = p_product_id
    AND coalesce(is_active, true) = true
  LIMIT 1;

  IF v_pkg.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Unknown product');
  END IF;

  v_coins := coalesce(v_pkg.beans_amount, 0)::bigint;
  IF v_coins <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid package amount');
  END IF;

  BEGIN
    INSERT INTO public.iap_purchase_receipts (
      user_id, product_id, purchase_id, purchase_token, coins_credited
    ) VALUES (
      v_uid, p_product_id, p_purchase_id, p_purchase_token, v_coins
    );
  EXCEPTION WHEN unique_violation THEN
    SELECT * INTO v_existing FROM public.iap_purchase_receipts WHERE purchase_id = p_purchase_id;
    RETURN json_build_object(
      'success', true,
      'message', 'Already credited',
      'duplicate', true,
      'coins', coalesce(v_existing.coins_credited, v_coins)
    );
  END;

  UPDATE public.users
  SET coins = coalesce(coins, 0) + v_coins,
      updated_at = now()
  WHERE id = v_uid;

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, description, reference_id
  ) VALUES (
    v_uid,
    v_coins,
    'recharge',
    'coin',
    format('In-App Purchase: %s (%s)', p_product_id, p_purchase_id),
    NULL
  );

  BEGIN
    PERFORM public.apply_invite_recharge_bonus(v_uid, v_coins::integer);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN json_build_object(
    'success', true,
    'message', 'Credited',
    'duplicate', false,
    'coins', v_coins,
    'product_id', p_product_id
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.deliver_iap_purchase(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.deliver_iap_purchase(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.deliver_iap_purchase(text, text, text) TO service_role;

-- Block legacy client-callable recharge helper if present
REVOKE ALL ON FUNCTION public.handle_coin_recharge(uuid, integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_coin_recharge(uuid, integer, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.handle_coin_recharge(uuid, integer, text) TO service_role;

-- 5) Enable RLS on tables that were wide open (read configs; lock ledgers)
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'agency_period_settlements',
    'bd_staff_monthly_stats',
    'bd_staff_settlements',
    'cp_gifts',
    'cp_level_configs',
    'cp_rankings',
    'family_exp_logs',
    'family_rankings',
    'host_weekly_stats',
    'lucky_gift_bonus_logs',
    'lucky_gift_config',
    'lucky_gift_counters',
    'lucky_gift_sender_counters',
    'lucky_pro_gift_bonus_logs',
    'lucky_pro_gift_config',
    'lucky_pro_gift_counters',
    'lucky_pro_gift_sender_counters',
    'medal_configs',
    'policy_gift_settings',
    'room_daily_stats',
    'salary_tiers',
    'wealth_level_assets'
  ]
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

-- Config / catalog: authenticated can read
DO $$
DECLARE
  t text;
  pol text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'cp_level_configs',
    'lucky_gift_config',
    'lucky_pro_gift_config',
    'medal_configs',
    'policy_gift_settings',
    'salary_tiers',
    'wealth_level_assets'
  ]
  LOOP
    pol := t || '_read_authenticated';
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (true)',
      pol, t
    );
  END LOOP;
END $$;

-- Counters used by app gift UI (read)
DO $$
DECLARE
  t text;
  pol text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'lucky_gift_counters',
    'lucky_gift_sender_counters',
    'lucky_pro_gift_counters',
    'lucky_pro_gift_sender_counters'
  ]
  LOOP
    pol := t || '_read_authenticated';
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol, t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (true)',
      pol, t
    );
  END LOOP;
END $$;

-- Ledgers / settlements / rankings: no client policies (service_role / definer only)
-- (RLS on + zero policies = locked for authenticated)

-- 6) Soften economy trigger: block increases only (family fee decreases still work)
CREATE OR REPLACE FUNCTION public.protect_user_economy_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_role text := coalesce(auth.jwt() ->> 'role', '');
BEGIN
  IF v_role = 'service_role' THEN
    RETURN NEW;
  END IF;
  IF current_user IN ('postgres', 'supabase_admin') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF coalesce(NEW.coins, 0) > coalesce(OLD.coins, 0) THEN NEW.coins := OLD.coins; END IF;
    IF coalesce(NEW.diamonds, 0) > coalesce(OLD.diamonds, 0) THEN NEW.diamonds := OLD.diamonds; END IF;
    IF coalesce(NEW.beans, 0) > coalesce(OLD.beans, 0) THEN NEW.beans := OLD.beans; END IF;
    IF coalesce(NEW.cash_balance, 0) > coalesce(OLD.cash_balance, 0) THEN NEW.cash_balance := OLD.cash_balance; END IF;
    IF coalesce(NEW.reseller_coins, 0) > coalesce(OLD.reseller_coins, 0) THEN NEW.reseller_coins := OLD.reseller_coins; END IF;
    IF coalesce(NEW.wealth_value, 0) > coalesce(OLD.wealth_value, 0) THEN NEW.wealth_value := OLD.wealth_value; END IF;
    IF coalesce(NEW.charm_value, 0) > coalesce(OLD.charm_value, 0) THEN NEW.charm_value := OLD.charm_value; END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 7) Secure diamond/coin exchange (client can no longer raise balances)
CREATE OR REPLACE FUNCTION public.exchange_wallet_currency(
  p_from_currency text,
  p_to_currency text,
  p_amount bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_from text;
  v_to text;
  v_rate numeric;
  v_min int;
  v_recv bigint;
  v_coins bigint;
  v_diamonds bigint;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid amount');
  END IF;

  v_from := CASE WHEN p_from_currency = 'coins' THEN 'beans' ELSE p_from_currency END;
  v_to := CASE WHEN p_to_currency = 'coins' THEN 'beans' ELSE p_to_currency END;

  SELECT rate, min_amount INTO v_rate, v_min
  FROM public.exchange_configs
  WHERE from_currency = v_from AND to_currency = v_to AND coalesce(is_active, true)
  LIMIT 1;

  IF v_rate IS NULL THEN
    SELECT rate, min_amount INTO v_rate, v_min
    FROM public.exchange_configs
    WHERE from_currency = p_from_currency AND to_currency = p_to_currency AND coalesce(is_active, true)
    LIMIT 1;
  END IF;

  IF v_rate IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Exchange config not found');
  END IF;
  IF p_amount < coalesce(v_min, 0) THEN
    RETURN json_build_object('success', false, 'message', format('Minimum is %s', v_min));
  END IF;

  v_recv := floor(p_amount * v_rate)::bigint;

  SELECT coalesce(coins,0), coalesce(diamonds,0) INTO v_coins, v_diamonds
  FROM public.users WHERE id = v_uid FOR UPDATE;

  IF p_from_currency = 'diamonds' OR v_from = 'diamonds' THEN
    IF v_diamonds < p_amount THEN
      RETURN json_build_object('success', false, 'message', 'Insufficient diamonds');
    END IF;
    UPDATE public.users SET
      diamonds = diamonds - p_amount,
      coins = coalesce(coins,0) + v_recv,
      updated_at = now()
    WHERE id = v_uid;
    INSERT INTO public.transactions(user_id, amount, transaction_type, currency_type, description)
    VALUES (v_uid, p_amount, 'exchange', 'diamond',
      format('Exchanged %s diamonds for %s coins', p_amount, v_recv));
  ELSE
    IF v_coins < p_amount THEN
      RETURN json_build_object('success', false, 'message', 'Insufficient coins');
    END IF;
    UPDATE public.users SET
      coins = coins - p_amount,
      diamonds = coalesce(diamonds,0) + v_recv,
      updated_at = now()
    WHERE id = v_uid;
    INSERT INTO public.transactions(user_id, amount, transaction_type, currency_type, description)
    VALUES (v_uid, p_amount, 'exchange', 'coin',
      format('Exchanged %s coins for %s diamonds', p_amount, v_recv));
  END IF;

  RETURN json_build_object('success', true, 'received', v_recv);
END;
$function$;

REVOKE ALL ON FUNCTION public.exchange_wallet_currency(text, text, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.exchange_wallet_currency(text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.exchange_wallet_currency(text, text, bigint) TO service_role;
