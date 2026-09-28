-- Wallet Deep Features: withdrawals, payment methods, merchants, wallet records

-- ---------------------------------------------------------------------------
-- Expand transactions.transaction_type CHECK
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
  ALTER TABLE public.transactions
    ADD CONSTRAINT transactions_transaction_type_check
    CHECK (transaction_type = ANY (ARRAY[
      'recharge'::text,
      'gift_sent'::text,
      'gift_received'::text,
      'lucky_gift_bonus'::text,
      'game_win'::text,
      'game_loss'::text,
      'withdrawal'::text,
      'purchase'::text,
      'agency_commission'::text,
      'salary_payout'::text,
      'transfer_out'::text,
      'transfer_in'::text,
      'exchange'::text,
      'rupee_game_entry'::text,
      'rupee_game_refund'::text,
      'lucky_pro_gift_bonus'::text,
      'room_reward'::text,
      'weekly_room_reward'::text,
      'invite_register_bonus'::text,
      'invite_welcome_bonus'::text,
      'invite_milestone'::text,
      'invite_wheel'::text,
      'invite_first_recharge'::text,
      'invite_recharge_bonus'::text,
      'task_checkin'::text,
      'task_wheel'::text,
      'task_reward'::text,
      'cash_exchange_self'::text,
      'cash_exchange_other_out'::text,
      'cash_exchange_other_in'::text,
      'withdrawal_hold'::text,
      'withdrawal_refund'::text
    ]));
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'transactions check constraint update skipped: %', SQLERRM;
END $$;

-- Optional presence column for merchant Online status
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS last_seen_at timestamptz;

-- ---------------------------------------------------------------------------
-- withdrawal_configs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.withdrawal_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fee_percent numeric(6, 2) NOT NULL DEFAULT 0,
  min_amount numeric(12, 2) NOT NULL DEFAULT 1,
  allowed_days integer[] NOT NULL DEFAULT ARRAY[1,2,3,4,5,16,17,18,19,20],
  timezone_offset_hours integer NOT NULL DEFAULT 3,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.withdrawal_configs (fee_percent, min_amount, allowed_days, timezone_offset_hours, is_active)
SELECT 0, 1, ARRAY[1,2,3,4,5,16,17,18,19,20], 3, true
WHERE NOT EXISTS (
  SELECT 1 FROM public.withdrawal_configs WHERE is_active = true
);

ALTER TABLE public.withdrawal_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated read withdrawal configs" ON public.withdrawal_configs;
CREATE POLICY "Authenticated read withdrawal configs"
  ON public.withdrawal_configs FOR SELECT TO authenticated
  USING (true);

-- ---------------------------------------------------------------------------
-- user_payment_methods
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  method text NOT NULL,
  name text NOT NULL,
  address text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_payment_methods_user
  ON public.user_payment_methods(user_id);

ALTER TABLE public.user_payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own payment methods" ON public.user_payment_methods;
CREATE POLICY "Users manage own payment methods"
  ON public.user_payment_methods
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- wallet_withdrawals
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.wallet_withdrawals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount numeric(12, 2) NOT NULL,
  fee numeric(12, 2) NOT NULL DEFAULT 0,
  net_amount numeric(12, 2) NOT NULL,
  target_type text NOT NULL CHECK (target_type = ANY (ARRAY['reseller'::text, 'agent'::text])),
  target_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  payment_method jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status = ANY (ARRAY[
      'pending'::text,
      'approved'::text,
      'rejected'::text,
      'completed'::text,
      'cancelled'::text
    ])),
  admin_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_withdrawals_user_created
  ON public.wallet_withdrawals(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_withdrawals_status
  ON public.wallet_withdrawals(status, created_at DESC);

ALTER TABLE public.wallet_withdrawals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own withdrawals" ON public.wallet_withdrawals;
CREATE POLICY "Users read own withdrawals"
  ON public.wallet_withdrawals FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- request_cash_withdrawal
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_cash_withdrawal(
  p_amount numeric,
  p_target_type text,
  p_target_user_id uuid,
  p_payment_method_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_cash numeric(12, 2);
  v_cfg public.withdrawal_configs%ROWTYPE;
  v_day integer;
  v_fee numeric(12, 2);
  v_net numeric(12, 2);
  v_pm public.user_payment_methods%ROWTYPE;
  v_target_ok boolean := false;
  v_withdrawal_id uuid;
  v_pm_json jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid amount');
  END IF;

  IF p_target_type IS NULL OR p_target_type NOT IN ('reseller', 'agent') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid target type');
  END IF;

  IF p_target_user_id IS NULL OR p_target_user_id = v_uid THEN
    RETURN json_build_object('success', false, 'message', 'Invalid target user');
  END IF;

  SELECT * INTO v_cfg
  FROM public.withdrawal_configs
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_cfg.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Withdrawal config missing');
  END IF;

  -- Day-of-month in configured offset from UTC (default +3)
  v_day := EXTRACT(
    DAY FROM ((now() AT TIME ZONE 'UTC') + make_interval(hours => v_cfg.timezone_offset_hours))
  )::integer;

  IF NOT (v_day = ANY (v_cfg.allowed_days)) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Withdrawals are only allowed on the 1st–5th and 16th–20th of each month (UTC+3)'
    );
  END IF;

  IF p_amount < COALESCE(v_cfg.min_amount, 1) THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Minimum withdrawal amount is $%s', v_cfg.min_amount)
    );
  END IF;

  SELECT * INTO v_pm
  FROM public.user_payment_methods
  WHERE id = p_payment_method_id AND user_id = v_uid;

  IF v_pm.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Please select a payment method');
  END IF;

  v_pm_json := jsonb_build_object(
    'id', v_pm.id,
    'method', v_pm.method,
    'name', v_pm.name,
    'address', v_pm.address
  );

  -- Validate target
  IF p_target_type = 'reseller' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = p_target_user_id AND is_reseller IS TRUE
    ) INTO v_target_ok;
    IF NOT v_target_ok THEN
      RETURN json_build_object('success', false, 'message', 'Target is not an authorized coin reseller');
    END IF;
  ELSE
    SELECT EXISTS (
      SELECT 1 FROM public.agencies
      WHERE owner_id = p_target_user_id AND COALESCE(is_active, true) IS TRUE
    ) INTO v_target_ok;
    IF NOT v_target_ok THEN
      RETURN json_build_object('success', false, 'message', 'Target is not an authorized agent (agency owner)');
    END IF;
  END IF;

  SELECT cash_balance INTO v_cash FROM public.users WHERE id = v_uid FOR UPDATE;
  IF COALESCE(v_cash, 0) < p_amount THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient cash balance');
  END IF;

  v_fee := ROUND(p_amount * COALESCE(v_cfg.fee_percent, 0) / 100.0, 2);
  v_net := p_amount - v_fee;

  UPDATE public.users
  SET cash_balance = cash_balance - p_amount
  WHERE id = v_uid;

  INSERT INTO public.wallet_withdrawals (
    user_id, amount, fee, net_amount, target_type, target_user_id, payment_method, status
  ) VALUES (
    v_uid, p_amount, v_fee, v_net, p_target_type, p_target_user_id, v_pm_json, 'pending'
  )
  RETURNING id INTO v_withdrawal_id;

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, reference_id, description
  ) VALUES (
    v_uid,
    GREATEST(1, ROUND(p_amount)::bigint),
    'withdrawal_hold',
    'cash',
    v_withdrawal_id,
    format('Withdrawal hold $%s (fee $%s, net $%s) via %s', p_amount, v_fee, v_net, p_target_type)
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Withdrawal request submitted',
    'withdrawal_id', v_withdrawal_id,
    'amount', p_amount,
    'fee', v_fee,
    'net_amount', v_net
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- cancel_cash_withdrawal
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_cash_withdrawal(p_withdrawal_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.wallet_withdrawals%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_row
  FROM public.wallet_withdrawals
  WHERE id = p_withdrawal_id AND user_id = v_uid
  FOR UPDATE;

  IF v_row.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Withdrawal not found');
  END IF;

  IF v_row.status IS DISTINCT FROM 'pending' THEN
    RETURN json_build_object('success', false, 'message', 'Only pending withdrawals can be cancelled');
  END IF;

  UPDATE public.users
  SET cash_balance = cash_balance + v_row.amount
  WHERE id = v_uid;

  UPDATE public.wallet_withdrawals
  SET status = 'cancelled', updated_at = now()
  WHERE id = v_row.id;

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, reference_id, description
  ) VALUES (
    v_uid,
    GREATEST(1, ROUND(v_row.amount)::bigint),
    'withdrawal_refund',
    'cash',
    v_row.id,
    format('Withdrawal cancelled — refunded $%s', v_row.amount)
  );

  RETURN json_build_object('success', true, 'message', 'Withdrawal cancelled');
END;
$function$;

-- ---------------------------------------------------------------------------
-- admin_process_withdrawal
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_process_withdrawal(
  p_withdrawal_id uuid,
  p_action text,
  p_note text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_row public.wallet_withdrawals%ROWTYPE;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF p_action IS NULL OR p_action NOT IN ('approve', 'reject', 'complete') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid action');
  END IF;

  SELECT * INTO v_row
  FROM public.wallet_withdrawals
  WHERE id = p_withdrawal_id
  FOR UPDATE;

  IF v_row.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Withdrawal not found');
  END IF;

  IF p_action = 'approve' THEN
    IF v_row.status IS DISTINCT FROM 'pending' THEN
      RETURN json_build_object('success', false, 'message', 'Only pending can be approved');
    END IF;
    UPDATE public.wallet_withdrawals
    SET status = 'approved', admin_note = p_note, updated_at = now()
    WHERE id = v_row.id;

  ELSIF p_action = 'reject' THEN
    IF v_row.status NOT IN ('pending', 'approved') THEN
      RETURN json_build_object('success', false, 'message', 'Cannot reject this withdrawal');
    END IF;
    UPDATE public.users
    SET cash_balance = cash_balance + v_row.amount
    WHERE id = v_row.user_id;

    UPDATE public.wallet_withdrawals
    SET status = 'rejected', admin_note = p_note, updated_at = now()
    WHERE id = v_row.id;

    INSERT INTO public.transactions (
      user_id, amount, transaction_type, currency_type, reference_id, description
    ) VALUES (
      v_row.user_id,
      GREATEST(1, ROUND(v_row.amount)::bigint),
      'withdrawal_refund',
      'cash',
      v_row.id,
      format('Withdrawal rejected — refunded $%s', v_row.amount)
    );

  ELSIF p_action = 'complete' THEN
    IF v_row.status NOT IN ('pending', 'approved') THEN
      RETURN json_build_object('success', false, 'message', 'Cannot complete this withdrawal');
    END IF;
    UPDATE public.wallet_withdrawals
    SET status = 'completed', admin_note = p_note, updated_at = now()
    WHERE id = v_row.id;

    INSERT INTO public.transactions (
      user_id, amount, transaction_type, currency_type, reference_id, description
    ) VALUES (
      v_row.user_id,
      GREATEST(1, ROUND(v_row.amount)::bigint),
      'withdrawal',
      'cash',
      v_row.id,
      format('Withdrawal completed $%s (net $%s)', v_row.amount, v_row.net_amount)
    );
  END IF;

  RETURN json_build_object('success', true, 'message', format('Withdrawal %sd', p_action), 'status', p_action);
END;
$function$;

-- ---------------------------------------------------------------------------
-- get_coin_merchants
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_coin_merchants()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_rows json;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated', 'merchants', '[]'::json);
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.username), '[]'::json)
  INTO v_rows
  FROM (
    SELECT
      u.id,
      u.username,
      u.short_id,
      u.avatar_url,
      u.country_code,
      u.created_at::date AS registration_date,
      CASE
        WHEN u.last_seen_at IS NOT NULL AND u.last_seen_at > now() - interval '15 minutes'
          THEN true
        ELSE false
      END AS is_online
    FROM public.users u
    WHERE u.is_reseller IS TRUE
      AND u.id IS DISTINCT FROM v_uid
    ORDER BY u.username
    LIMIT 200
  ) t;

  RETURN json_build_object('success', true, 'merchants', v_rows);
END;
$function$;

-- ---------------------------------------------------------------------------
-- get_wallet_records
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_wallet_records(
  p_currency text,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_currency text;
  v_rows json;
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
  v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated', 'records', '[]'::json);
  END IF;

  v_currency := CASE lower(COALESCE(p_currency, 'coin'))
    WHEN 'coins' THEN 'coin'
    WHEN 'coin' THEN 'coin'
    WHEN 'diamonds' THEN 'diamond'
    WHEN 'diamond' THEN 'diamond'
    WHEN 'balance' THEN 'cash'
    WHEN 'cash' THEN 'cash'
    ELSE 'coin'
  END;

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_rows
  FROM (
    SELECT
      t.id,
      t.amount,
      t.transaction_type,
      t.currency_type,
      t.description,
      t.created_at,
      CASE
        WHEN t.transaction_type IN (
          'recharge', 'transfer_in', 'cash_exchange_self', 'cash_exchange_other_in',
          'gift_received', 'game_win', 'lucky_gift_bonus', 'lucky_pro_gift_bonus',
          'room_reward', 'weekly_room_reward', 'invite_register_bonus',
          'invite_welcome_bonus', 'invite_milestone', 'invite_wheel',
          'invite_first_recharge', 'invite_recharge_bonus', 'task_checkin',
          'task_wheel', 'task_reward', 'withdrawal_refund', 'exchange'
        ) THEN true
        ELSE false
      END AS is_credit,
      COALESCE(
        NULLIF(trim(t.description), ''),
        initcap(replace(t.transaction_type, '_', ' '))
      ) AS title,
      initcap(replace(t.transaction_type, '_', ' ')) AS subtitle
    FROM public.transactions t
    WHERE t.user_id = v_uid
      AND t.currency_type = v_currency
    ORDER BY t.created_at DESC
    LIMIT v_limit
    OFFSET v_offset
  ) t;

  RETURN json_build_object('success', true, 'records', v_rows);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.request_cash_withdrawal(numeric, text, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_cash_withdrawal(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_process_withdrawal(uuid, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_coin_merchants() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_wallet_records(text, integer, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
