-- Official withdrawals: no target ID search — amount + payment method only.
-- Appears in admin Withdrawals like agent/reseller requests.

ALTER TABLE public.wallet_withdrawals
  DROP CONSTRAINT IF EXISTS wallet_withdrawals_target_type_check;

ALTER TABLE public.wallet_withdrawals
  ADD CONSTRAINT wallet_withdrawals_target_type_check
  CHECK (target_type = ANY (ARRAY['reseller'::text, 'agent'::text, 'official'::text]));

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
  v_requester_name text;
  v_requester_short_id text;
  v_target_label text;
  v_resolved_target uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid amount');
  END IF;

  IF p_target_type IS NULL OR p_target_type NOT IN ('reseller', 'agent', 'official') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid target type');
  END IF;

  -- Official: no target user required (admin processes payout).
  IF p_target_type = 'official' THEN
    v_resolved_target := NULL;
  ELSE
    IF p_target_user_id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Invalid target user');
    END IF;
    v_resolved_target := p_target_user_id;
  END IF;

  SELECT * INTO v_cfg
  FROM public.withdrawal_configs
  WHERE is_active = true
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_cfg.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Withdrawal config missing');
  END IF;

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

  IF p_target_type = 'reseller' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.users
      WHERE id = v_resolved_target AND is_reseller IS TRUE
    ) INTO v_target_ok;
    IF NOT v_target_ok THEN
      RETURN json_build_object('success', false, 'message', 'Target is not an authorized coin reseller');
    END IF;
    v_target_label := 'Coin Reseller';
  ELSIF p_target_type = 'agent' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.agencies
      WHERE owner_id = v_resolved_target AND COALESCE(is_active, true) IS TRUE
    ) INTO v_target_ok;
    IF NOT v_target_ok THEN
      RETURN json_build_object('success', false, 'message', 'Target is not an authorized agent (agency owner)');
    END IF;
    v_target_label := 'Agent';
  ELSE
    v_target_ok := true;
    v_target_label := 'Official';
  END IF;

  SELECT cash_balance, COALESCE(username, 'User'), short_id::text
  INTO v_cash, v_requester_name, v_requester_short_id
  FROM public.users
  WHERE id = v_uid
  FOR UPDATE;

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
    v_uid, p_amount, v_fee, v_net, p_target_type, v_resolved_target, v_pm_json, 'pending'
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

  -- Notify reseller/agent target only (Official goes to admin panel).
  IF v_resolved_target IS NOT NULL THEN
    INSERT INTO public.system_notifications (
      user_id, title, content, type, icon_type, metadata
    ) VALUES (
      v_resolved_target,
      'New Withdrawal Request',
      CASE
        WHEN v_requester_short_id IS NOT NULL AND v_requester_short_id <> ''
          THEN format(
            '%s (UID %s) requested $%s withdrawal via %s. Net $%s.',
            v_requester_name,
            v_requester_short_id,
            to_char(p_amount, 'FM999,999,999,990.00'),
            v_target_label,
            to_char(v_net, 'FM999,999,999,990.00')
          )
        ELSE format(
          '%s requested $%s withdrawal via %s. Net $%s.',
          v_requester_name,
          to_char(p_amount, 'FM999,999,999,990.00'),
          v_target_label,
          to_char(v_net, 'FM999,999,999,990.00')
        )
      END,
      'withdrawal_request',
      'wallet',
      jsonb_build_object(
        'withdrawal_id', v_withdrawal_id::text,
        'requester_id', v_uid::text,
        'requester_name', v_requester_name,
        'requester_short_id', COALESCE(v_requester_short_id, ''),
        'amount', p_amount::text,
        'fee', v_fee::text,
        'net_amount', v_net::text,
        'target_type', p_target_type,
        'currency', 'cash'
      )
    );
  END IF;

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

GRANT EXECUTE ON FUNCTION public.request_cash_withdrawal(numeric, text, uuid, uuid) TO authenticated;
