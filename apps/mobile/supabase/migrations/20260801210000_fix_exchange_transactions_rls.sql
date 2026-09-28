-- Fix diamond↔gold exchange RLS failure:
-- 20260801130000 dropped client INSERT policies on transactions; SECURITY DEFINER
-- RPCs must bypass RLS (and run as postgres) so ledger rows can be written.

CREATE OR REPLACE FUNCTION public.exchange_wallet_currency(
  p_from_currency text,
  p_to_currency text,
  p_amount bigint
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
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
    WHERE from_currency = p_from_currency
      AND to_currency = p_to_currency
      AND coalesce(is_active, true)
    LIMIT 1;
  END IF;

  IF v_rate IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Exchange config not found');
  END IF;
  IF p_amount < coalesce(v_min, 0) THEN
    RETURN json_build_object('success', false, 'message', format('Minimum is %s', v_min));
  END IF;

  v_recv := floor(p_amount * v_rate)::bigint;

  SELECT coalesce(coins, 0), coalesce(diamonds, 0)
  INTO v_coins, v_diamonds
  FROM public.users
  WHERE id = v_uid
  FOR UPDATE;

  IF p_from_currency = 'diamonds' OR v_from = 'diamonds' THEN
    IF v_diamonds < p_amount THEN
      RETURN json_build_object('success', false, 'message', 'Insufficient diamonds');
    END IF;
    UPDATE public.users SET
      diamonds = diamonds - p_amount,
      coins = coalesce(coins, 0) + v_recv,
      updated_at = now()
    WHERE id = v_uid;
    INSERT INTO public.transactions (
      user_id, amount, transaction_type, currency_type, description
    ) VALUES (
      v_uid, p_amount, 'exchange', 'diamond',
      format('Exchanged %s diamonds for %s coins', p_amount, v_recv)
    );
  ELSE
    IF v_coins < p_amount THEN
      RETURN json_build_object('success', false, 'message', 'Insufficient coins');
    END IF;
    UPDATE public.users SET
      coins = coins - p_amount,
      diamonds = coalesce(diamonds, 0) + v_recv,
      updated_at = now()
    WHERE id = v_uid;
    INSERT INTO public.transactions (
      user_id, amount, transaction_type, currency_type, description
    ) VALUES (
      v_uid, p_amount, 'exchange', 'coin',
      format('Exchanged %s coins for %s diamonds', p_amount, v_recv)
    );
  END IF;

  RETURN json_build_object('success', true, 'received', v_recv);
END;
$function$;

ALTER FUNCTION public.exchange_wallet_currency(text, text, bigint) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.exchange_wallet_currency(text, text, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.exchange_wallet_currency(text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.exchange_wallet_currency(text, text, bigint) TO service_role;

-- Same fix for diamonds → salary (cash) wallet exchange
CREATE OR REPLACE FUNCTION public.exchange_diamonds_to_salary(p_diamonds bigint)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
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

ALTER FUNCTION public.exchange_diamonds_to_salary(bigint) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.exchange_diamonds_to_salary(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.exchange_diamonds_to_salary(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.exchange_diamonds_to_salary(bigint) TO service_role;
