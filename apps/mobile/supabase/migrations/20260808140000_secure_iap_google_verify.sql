-- Harden IAP: only service_role may credit; require token; rate-limit; optional p_user_id for Edge Function.

CREATE OR REPLACE FUNCTION public.deliver_iap_purchase(
  p_product_id text,
  p_purchase_id text,
  p_purchase_token text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid;
  v_role text := coalesce(auth.jwt() ->> 'role', '');
  v_pkg public.recharge_packages%ROWTYPE;
  v_coins bigint;
  v_existing public.iap_purchase_receipts%ROWTYPE;
  v_hour_count integer;
  v_token text := nullif(trim(coalesce(p_purchase_token, '')), '');
BEGIN
  -- Clients must not call this directly (revoked below). Edge Function uses service_role + p_user_id.
  IF v_role = 'service_role' THEN
    IF p_user_id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'user_id required');
    END IF;
    v_uid := p_user_id;
  ELSE
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;
    -- Ignore client-supplied user override
    IF p_user_id IS NOT NULL AND p_user_id <> v_uid THEN
      RETURN json_build_object('success', false, 'message', 'Forbidden');
    END IF;
  END IF;

  IF p_product_id IS NULL OR length(trim(p_product_id)) = 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid product');
  END IF;

  IF p_purchase_id IS NULL OR length(trim(p_purchase_id)) = 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid purchase id');
  END IF;

  IF v_token IS NULL OR length(v_token) < 20 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid purchase token');
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

  -- Same token already credited under another purchase_id
  IF EXISTS (
    SELECT 1 FROM public.iap_purchase_receipts
    WHERE purchase_token = v_token
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Purchase token already used'
    );
  END IF;

  -- Rate limit: max 10 new successful credits per user per hour
  SELECT COUNT(*)::integer INTO v_hour_count
  FROM public.iap_purchase_receipts
  WHERE user_id = v_uid
    AND created_at > now() - interval '1 hour';

  IF v_hour_count >= 10 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Too many purchases in a short time. Try again later.'
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
      v_uid, p_product_id, p_purchase_id, v_token, v_coins
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

-- Unique token when present (partial) — blocks token replay under new GPA ids
CREATE UNIQUE INDEX IF NOT EXISTS iap_purchase_receipts_token_uidx
  ON public.iap_purchase_receipts (purchase_token)
  WHERE purchase_token IS NOT NULL AND length(trim(purchase_token)) > 0;

CREATE INDEX IF NOT EXISTS iap_purchase_receipts_user_hour_idx
  ON public.iap_purchase_receipts (user_id, created_at DESC);

-- Drop legacy 3-arg overload so clients cannot call the old signature.
DROP FUNCTION IF EXISTS public.deliver_iap_purchase(text, text, text);

REVOKE ALL ON FUNCTION public.deliver_iap_purchase(text, text, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.deliver_iap_purchase(text, text, text, uuid) FROM authenticated;
REVOKE ALL ON FUNCTION public.deliver_iap_purchase(text, text, text, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.deliver_iap_purchase(text, text, text, uuid) TO service_role;
