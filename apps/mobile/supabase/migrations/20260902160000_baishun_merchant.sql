-- BAISHUN Game merchant: one-time codes, ss_token sessions, idempotent orders, balance RPC.

CREATE TABLE IF NOT EXISTS public.baishun_codes (
  code text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS baishun_codes_user_idx
  ON public.baishun_codes (user_id, expires_at DESC);

CREATE TABLE IF NOT EXISTS public.baishun_sessions (
  ss_token text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  expire_date bigint NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS baishun_sessions_user_idx
  ON public.baishun_sessions (user_id, expires_at DESC);

CREATE TABLE IF NOT EXISTS public.baishun_orders (
  order_id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  currency_diff bigint NOT NULL,
  diff_msg text NOT NULL,
  game_id int,
  game_round_id text,
  room_id text,
  balance_after bigint,
  snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS baishun_orders_user_idx
  ON public.baishun_orders (user_id, created_at DESC);

ALTER TABLE public.baishun_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.baishun_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.baishun_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS baishun_codes_no_client ON public.baishun_codes;
CREATE POLICY baishun_codes_no_client
  ON public.baishun_codes FOR ALL TO authenticated, anon
  USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS baishun_sessions_no_client ON public.baishun_sessions;
CREATE POLICY baishun_sessions_no_client
  ON public.baishun_sessions FOR ALL TO authenticated, anon
  USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS baishun_orders_no_client ON public.baishun_orders;
CREATE POLICY baishun_orders_no_client
  ON public.baishun_orders FOR ALL TO authenticated, anon
  USING (false) WITH CHECK (false);

GRANT ALL ON public.baishun_codes TO service_role;
GRANT ALL ON public.baishun_sessions TO service_role;
GRANT ALL ON public.baishun_orders TO service_role;

CREATE OR REPLACE FUNCTION public.baishun_apply_balance(
  p_user_id uuid,
  p_order_id text,
  p_currency_diff bigint,
  p_diff_msg text,
  p_game_id int DEFAULT NULL,
  p_game_round_id text DEFAULT NULL,
  p_room_id text DEFAULT NULL,
  p_snapshot jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_short_id int;
  v_coins bigint;
  v_existing public.baishun_orders%ROWTYPE;
  v_new_balance bigint;
  v_tx_type text;
BEGIN
  IF p_user_id IS NULL OR COALESCE(btrim(p_order_id), '') = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid request', 'code', 1003);
  END IF;

  IF COALESCE(p_currency_diff, 0) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'currency_diff required', 'code', 1003);
  END IF;

  SELECT short_id, COALESCE(coins, 0)
  INTO v_short_id, v_coins
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'user not found', 'code', 1004);
  END IF;
  IF v_short_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user has no short_id', 'code', 1004);
  END IF;

  SELECT *
  INTO v_existing
  FROM public.baishun_orders
  WHERE order_id = p_order_id;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'already', true,
      'balance', COALESCE(v_existing.balance_after, v_coins),
      'short_id', v_short_id
    );
  END IF;

  v_new_balance := v_coins + COALESCE(p_currency_diff, 0);
  IF v_new_balance < 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'insufficient balance',
      'code', 1008,
      'balance', v_coins,
      'short_id', v_short_id
    );
  END IF;

  IF COALESCE(p_diff_msg, '') IN ('bet', 'result', 'refund') THEN
    IF p_diff_msg = 'bet' AND p_currency_diff >= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'bet must decrease balance', 'code', 1003);
    END IF;
  END IF;

  IF p_currency_diff < 0 THEN
    v_tx_type := 'game_loss';
  ELSE
    v_tx_type := 'game_win';
  END IF;

  UPDATE public.users
  SET coins = v_new_balance
  WHERE id = p_user_id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  ) VALUES (
    p_user_id,
    ABS(p_currency_diff),
    'coin',
    v_tx_type,
    p_user_id
  );

  INSERT INTO public.baishun_orders (
    order_id,
    user_id,
    currency_diff,
    diff_msg,
    game_id,
    game_round_id,
    room_id,
    balance_after,
    snapshot
  ) VALUES (
    p_order_id,
    p_user_id,
    p_currency_diff,
    COALESCE(p_diff_msg, ''),
    p_game_id,
    p_game_round_id,
    p_room_id,
    v_new_balance,
    COALESCE(p_snapshot, '{}'::jsonb) || jsonb_build_object(
      'balance_before', v_coins,
      'balance_after', v_new_balance
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'already', false,
    'balance', v_new_balance,
    'short_id', v_short_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.baishun_apply_balance(uuid, text, bigint, text, int, text, text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.baishun_apply_balance(uuid, text, bigint, text, int, text, text, jsonb) TO service_role;
