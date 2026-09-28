-- Fix wallet diamond↔coin exchange for apps still on the legacy client path
-- (update users + insert transactions) after INSERT policies were removed.
-- Keep minting blocked: only allow coin increases that match a real diamond burn
-- at the configured exchange rate (or SECURITY DEFINER / service_role).

CREATE OR REPLACE FUNCTION public.protect_user_economy_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_role text := coalesce(auth.jwt() ->> 'role', '');
  v_spent bigint;
  v_gained bigint;
  v_rate numeric;
  v_min int;
  v_max_recv bigint;
BEGIN
  IF v_role = 'service_role' THEN
    RETURN NEW;
  END IF;
  IF current_user IN ('postgres', 'supabase_admin') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Legacy diamond→coin exchange: allow only if burn/gain matches config rate.
    IF coalesce(NEW.coins, 0) > coalesce(OLD.coins, 0)
       AND coalesce(NEW.diamonds, 0) < coalesce(OLD.diamonds, 0) THEN
      v_spent := coalesce(OLD.diamonds, 0) - coalesce(NEW.diamonds, 0);
      v_gained := coalesce(NEW.coins, 0) - coalesce(OLD.coins, 0);

      SELECT rate, min_amount
      INTO v_rate, v_min
      FROM public.exchange_configs
      WHERE from_currency = 'diamonds'
        AND to_currency IN ('beans', 'coins')
        AND coalesce(is_active, true)
      ORDER BY CASE WHEN to_currency = 'beans' THEN 0 ELSE 1 END
      LIMIT 1;

      v_max_recv := floor(v_spent * coalesce(v_rate, 0))::bigint;

      IF v_rate IS NULL
         OR v_spent < coalesce(v_min, 0)
         OR v_gained > v_max_recv
         OR v_gained <= 0 THEN
        NEW.coins := OLD.coins;
        NEW.diamonds := OLD.diamonds;
      END IF;
    ELSE
      IF coalesce(NEW.coins, 0) > coalesce(OLD.coins, 0) THEN
        NEW.coins := OLD.coins;
      END IF;
      IF coalesce(NEW.diamonds, 0) > coalesce(OLD.diamonds, 0) THEN
        NEW.diamonds := OLD.diamonds;
      END IF;
    END IF;

    IF coalesce(NEW.beans, 0) > coalesce(OLD.beans, 0) THEN
      NEW.beans := OLD.beans;
    END IF;
    IF coalesce(NEW.cash_balance, 0) > coalesce(OLD.cash_balance, 0) THEN
      NEW.cash_balance := OLD.cash_balance;
    END IF;
    IF coalesce(NEW.reseller_coins, 0) > coalesce(OLD.reseller_coins, 0) THEN
      NEW.reseller_coins := OLD.reseller_coins;
    END IF;
    IF coalesce(NEW.wealth_value, 0) > coalesce(OLD.wealth_value, 0) THEN
      NEW.wealth_value := OLD.wealth_value;
    END IF;
    IF coalesce(NEW.charm_value, 0) > coalesce(OLD.charm_value, 0) THEN
      NEW.charm_value := OLD.charm_value;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

ALTER FUNCTION public.protect_user_economy_columns() OWNER TO postgres;

-- Allow legacy clients to log their own exchange ledger rows only.
DROP POLICY IF EXISTS "Users can insert own exchange transactions" ON public.transactions;
CREATE POLICY "Users can insert own exchange transactions"
  ON public.transactions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND transaction_type = 'exchange'
    AND currency_type IN ('diamond', 'coin')
  );

-- Re-assert secure RPC path (preferred by current app builds).
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
