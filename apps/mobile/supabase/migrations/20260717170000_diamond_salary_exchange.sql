-- Diamonds → Salary (cash_balance) exchange

CREATE TABLE IF NOT EXISTS public.diamond_salary_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  diamonds_unit bigint NOT NULL DEFAULT 150000,
  usd_per_unit numeric(12, 4) NOT NULL DEFAULT 0.75,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.diamond_salary_configs (diamonds_unit, usd_per_unit, is_active)
SELECT 150000, 0.75, true
WHERE NOT EXISTS (
  SELECT 1 FROM public.diamond_salary_configs WHERE is_active = true
);

ALTER TABLE public.diamond_salary_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated read diamond salary configs" ON public.diamond_salary_configs;
CREATE POLICY "Authenticated read diamond salary configs"
  ON public.diamond_salary_configs FOR SELECT TO authenticated
  USING (true);

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
      'withdrawal_refund'::text,
      'diamond_salary_exchange'::text
    ]));
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'transactions check constraint update skipped: %', SQLERRM;
END $$;

CREATE OR REPLACE FUNCTION public.exchange_diamonds_to_salary(p_diamonds bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_diamonds bigint;
  v_cfg public.diamond_salary_configs%ROWTYPE;
  v_units bigint;
  v_usd numeric(12, 4);
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_diamonds IS NULL OR p_diamonds <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid amount');
  END IF;

  SELECT * INTO v_cfg
  FROM public.diamond_salary_configs
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_cfg.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Salary exchange config missing');
  END IF;

  IF p_diamonds < v_cfg.diamonds_unit THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Minimum exchange is %s diamonds', v_cfg.diamonds_unit)
    );
  END IF;

  IF (p_diamonds % v_cfg.diamonds_unit) <> 0 THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Amount must be a multiple of %s', v_cfg.diamonds_unit)
    );
  END IF;

  SELECT COALESCE(diamonds, 0) INTO v_diamonds
  FROM public.users
  WHERE id = v_uid
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  IF v_diamonds < p_diamonds THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient diamonds');
  END IF;

  v_units := p_diamonds / v_cfg.diamonds_unit;
  v_usd := ROUND(v_units * v_cfg.usd_per_unit, 2);

  UPDATE public.users
  SET
    diamonds = diamonds - p_diamonds,
    cash_balance = COALESCE(cash_balance, 0) + v_usd
  WHERE id = v_uid;

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, description
  ) VALUES (
    v_uid,
    p_diamonds,
    'diamond_salary_exchange',
    'diamond',
    format('Exchanged %s diamonds → $%s salary wallet', p_diamonds, v_usd)
  );

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, description
  ) VALUES (
    v_uid,
    GREATEST(1, ROUND(v_usd * 100)::bigint),
    'diamond_salary_exchange',
    'cash',
    format('Salary wallet +$%s from %s diamonds', v_usd, p_diamonds)
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Exchange successful',
    'diamonds', p_diamonds,
    'usd', v_usd
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.exchange_diamonds_to_salary(bigint) TO authenticated;

-- Wallet records: treat diamond_salary_exchange correctly per currency
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
        WHEN t.transaction_type = 'diamond_salary_exchange' AND t.currency_type = 'cash' THEN true
        WHEN t.transaction_type = 'diamond_salary_exchange' AND t.currency_type = 'diamond' THEN false
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

NOTIFY pgrst, 'reload schema';
