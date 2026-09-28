-- Reseller withdrawal bills: Approve / Reject → admin credits reseller_coins

-- ---------------------------------------------------------------------------
-- Schema: status + reseller processing columns
-- ---------------------------------------------------------------------------
ALTER TABLE public.wallet_withdrawals
  DROP CONSTRAINT IF EXISTS wallet_withdrawals_status_check;

ALTER TABLE public.wallet_withdrawals
  ADD CONSTRAINT wallet_withdrawals_status_check
  CHECK (status = ANY (ARRAY[
    'pending'::text,
    'approved'::text,
    'reseller_approved'::text,
    'rejected'::text,
    'completed'::text,
    'cancelled'::text
  ]));

ALTER TABLE public.wallet_withdrawals
  ADD COLUMN IF NOT EXISTS reseller_processed_at timestamptz,
  ADD COLUMN IF NOT EXISTS reseller_note text;

CREATE INDEX IF NOT EXISTS idx_wallet_withdrawals_target_status_created
  ON public.wallet_withdrawals(target_user_id, status, created_at DESC);

-- ---------------------------------------------------------------------------
-- get_reseller_withdrawal_bills
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_reseller_withdrawal_bills(
  p_status text DEFAULT NULL,
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
  v_is_reseller boolean := false;
  v_rows json;
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
  v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
  v_status text := NULLIF(trim(lower(COALESCE(p_status, ''))), '');
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated', 'bills', '[]'::json);
  END IF;

  SELECT COALESCE(is_reseller, false) INTO v_is_reseller
  FROM public.users
  WHERE id = v_uid;

  IF v_is_reseller IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'message', 'Not a reseller', 'bills', '[]'::json);
  END IF;

  IF v_status IS NOT NULL AND v_status NOT IN (
    'pending', 'reseller_approved', 'approved', 'rejected', 'completed', 'cancelled', 'all'
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Invalid status filter', 'bills', '[]'::json);
  END IF;

  IF v_status = 'all' THEN
    v_status := NULL;
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  INTO v_rows
  FROM (
    SELECT
      w.id,
      w.user_id,
      w.amount,
      w.fee,
      w.net_amount,
      w.payment_method,
      w.status,
      w.reseller_note,
      w.reseller_processed_at,
      w.admin_note,
      w.created_at,
      w.updated_at,
      u.username AS requester_username,
      u.avatar_url AS requester_avatar_url,
      u.short_id AS requester_short_id
    FROM public.wallet_withdrawals w
    JOIN public.users u ON u.id = w.user_id
    WHERE w.target_user_id = v_uid
      AND w.target_type = 'reseller'
      AND (v_status IS NULL OR w.status = v_status)
    ORDER BY w.created_at DESC
    LIMIT v_limit
    OFFSET v_offset
  ) t;

  RETURN json_build_object('success', true, 'bills', COALESCE(v_rows, '[]'::json));
END;
$function$;

-- ---------------------------------------------------------------------------
-- reseller_process_withdrawal
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reseller_process_withdrawal(
  p_id uuid,
  p_action text,
  p_note text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_is_reseller boolean := false;
  v_row public.wallet_withdrawals%ROWTYPE;
  v_action text := lower(trim(COALESCE(p_action, '')));
  v_note text := NULLIF(trim(COALESCE(p_note, '')), '');
  v_amount_label text;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT COALESCE(is_reseller, false) INTO v_is_reseller
  FROM public.users
  WHERE id = v_uid;

  IF v_is_reseller IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'message', 'Not a reseller');
  END IF;

  IF v_action NOT IN ('approve', 'reject') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid action');
  END IF;

  SELECT * INTO v_row
  FROM public.wallet_withdrawals
  WHERE id = p_id
  FOR UPDATE;

  IF v_row.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Withdrawal not found');
  END IF;

  IF v_row.target_type IS DISTINCT FROM 'reseller'
     OR v_row.target_user_id IS DISTINCT FROM v_uid THEN
    RETURN json_build_object('success', false, 'message', 'Not your bill');
  END IF;

  IF v_row.status IS DISTINCT FROM 'pending' THEN
    RETURN json_build_object('success', false, 'message', 'Only pending bills can be processed');
  END IF;

  v_amount_label := to_char(v_row.amount, 'FM999,999,999,990.00');

  IF v_action = 'approve' THEN
    UPDATE public.wallet_withdrawals
    SET
      status = 'reseller_approved',
      reseller_processed_at = now(),
      reseller_note = v_note,
      updated_at = now()
    WHERE id = v_row.id;

    INSERT INTO public.system_notifications (
      user_id, title, content, type, icon_type, metadata
    ) VALUES (
      v_row.user_id,
      'Withdrawal Approved by Reseller',
      format(
        'Your $%s withdrawal was approved by the reseller and is waiting for admin to credit stock.',
        v_amount_label
      ),
      'withdrawal_approved',
      'wallet',
      jsonb_build_object(
        'withdrawal_id', v_row.id::text,
        'status', 'reseller_approved',
        'amount', v_row.amount::text,
        'net_amount', v_row.net_amount::text,
        'action', 'approve'
      )
    );

    RETURN json_build_object(
      'success', true,
      'message', 'Withdrawal approved',
      'status', 'reseller_approved'
    );
  END IF;

  -- reject: refund held cash
  UPDATE public.users
  SET cash_balance = cash_balance + v_row.amount
  WHERE id = v_row.user_id;

  UPDATE public.wallet_withdrawals
  SET
    status = 'rejected',
    reseller_processed_at = now(),
    reseller_note = v_note,
    updated_at = now()
  WHERE id = v_row.id;

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, reference_id, description
  ) VALUES (
    v_row.user_id,
    GREATEST(1, ROUND(v_row.amount)::bigint),
    'withdrawal_refund',
    'cash',
    v_row.id,
    format('Withdrawal rejected by reseller — refunded $%s', v_row.amount)
  );

  INSERT INTO public.system_notifications (
    user_id, title, content, type, icon_type, metadata
  ) VALUES (
    v_row.user_id,
    'Withdrawal Rejected',
    format(
      'Your $%s withdrawal was rejected by the reseller. Cash has been refunded to your balance.',
      v_amount_label
    ),
    'withdrawal_rejected',
    'wallet',
    jsonb_build_object(
      'withdrawal_id', v_row.id::text,
      'status', 'rejected',
      'amount', v_row.amount::text,
      'action', 'reject'
    )
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Withdrawal rejected and refunded',
    'status', 'rejected'
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- admin_process_withdrawal — reseller_approved + credit reseller_coins
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
  v_rate bigint;
  v_stock bigint;
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
    IF v_row.status NOT IN ('pending', 'approved', 'reseller_approved') THEN
      RETURN json_build_object('success', false, 'message', 'Cannot reject this withdrawal');
    END IF;

    -- Refund held cash (still held for pending / approved / reseller_approved)
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

    INSERT INTO public.system_notifications (
      user_id, title, content, type, icon_type, metadata
    ) VALUES (
      v_row.user_id,
      'Withdrawal Rejected',
      format(
        'Your $%s withdrawal was rejected. Cash has been refunded to your balance.',
        to_char(v_row.amount, 'FM999,999,999,990.00')
      ),
      'withdrawal_rejected',
      'wallet',
      jsonb_build_object(
        'withdrawal_id', v_row.id::text,
        'status', 'rejected',
        'amount', v_row.amount::text,
        'action', 'reject'
      )
    );

  ELSIF p_action = 'complete' THEN
    IF v_row.status NOT IN ('pending', 'approved', 'reseller_approved') THEN
      RETURN json_build_object('success', false, 'message', 'Cannot complete this withdrawal');
    END IF;

    -- Credit reseller stock when target is a reseller
    IF v_row.target_type = 'reseller' AND v_row.target_user_id IS NOT NULL THEN
      SELECT COALESCE(coins_per_usd, 88000)
      INTO v_rate
      FROM public.coin_seller_policy_settings
      WHERE id = 1;

      IF v_rate IS NULL OR v_rate <= 0 THEN
        v_rate := 88000;
      END IF;

      v_stock := FLOOR(COALESCE(v_row.net_amount, 0) * v_rate)::bigint;
      IF v_stock < 1 THEN
        RETURN json_build_object(
          'success', false,
          'message', 'Computed reseller stock is zero — check net amount / coins_per_usd'
        );
      END IF;

      UPDATE public.users
      SET
        reseller_coins = COALESCE(reseller_coins, 0) + v_stock,
        updated_at = now()
      WHERE id = v_row.target_user_id;

      INSERT INTO public.transactions (
        user_id, amount, transaction_type, currency_type, reference_id, description
      ) VALUES (
        v_row.target_user_id,
        v_stock,
        'seller_package',
        'coin',
        v_row.id,
        format(
          'Withdrawal stock credit — $%s net × %s = %s reseller coins',
          v_row.net_amount,
          v_rate,
          v_stock
        )
      );
    ELSE
      v_stock := NULL;
      v_rate := NULL;
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

    INSERT INTO public.system_notifications (
      user_id, title, content, type, icon_type, metadata
    ) VALUES (
      v_row.user_id,
      'Withdrawal Completed',
      format(
        'Your $%s withdrawal has been completed.',
        to_char(v_row.amount, 'FM999,999,999,990.00')
      ),
      'withdrawal_completed',
      'wallet',
      jsonb_build_object(
        'withdrawal_id', v_row.id::text,
        'status', 'completed',
        'amount', v_row.amount::text,
        'action', 'complete'
      )
    );
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', format('Withdrawal %sd', p_action),
    'status', CASE
      WHEN p_action = 'approve' THEN 'approved'
      WHEN p_action = 'reject' THEN 'rejected'
      WHEN p_action = 'complete' THEN 'completed'
      ELSE p_action
    END,
    'reseller_coins_credited', v_stock,
    'coins_per_usd', v_rate
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_reseller_withdrawal_bills(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reseller_process_withdrawal(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_process_withdrawal(uuid, text, text) TO service_role;

NOTIFY pgrst, 'reload schema';
