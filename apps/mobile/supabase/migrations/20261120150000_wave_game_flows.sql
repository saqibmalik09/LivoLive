-- Wave Games tenant bridge. One row per transactionId so a retried
-- submitFlow cannot debit or credit the same bet twice.

CREATE TABLE IF NOT EXISTS public.wave_game_flows (
  transaction_id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  flow_type smallint NOT NULL,
  amount bigint NOT NULL,
  game_name text,
  game_id bigint,
  balance_after bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS wave_game_flows_user_idx
  ON public.wave_game_flows (user_id, created_at DESC);

ALTER TABLE public.wave_game_flows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS wave_game_flows_no_client ON public.wave_game_flows;
CREATE POLICY wave_game_flows_no_client
  ON public.wave_game_flows FOR ALL TO authenticated, anon
  USING (false) WITH CHECK (false);

GRANT ALL ON public.wave_game_flows TO service_role;

CREATE OR REPLACE FUNCTION public.wave_apply_flow(
  p_user_id uuid,
  p_transaction_id text,
  p_flow_type smallint,
  p_amount bigint,
  p_game_name text DEFAULT NULL,
  p_game_id bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_coins bigint;
  v_existing public.wave_game_flows%ROWTYPE;
  v_delta bigint;
  v_new_balance bigint;
  v_tx_type text;
BEGIN
  IF p_user_id IS NULL OR COALESCE(btrim(p_transaction_id), '') = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'transactionId is required', 'code', 'missing_transaction');
  END IF;

  IF p_flow_type NOT IN (1, 2) THEN
    RETURN jsonb_build_object('success', false, 'error', 'type must be 1 or 2', 'code', 'invalid_type');
  END IF;

  IF COALESCE(p_amount, 0) <= 0 OR p_amount > 1000000000000 THEN
    RETURN jsonb_build_object('success', false, 'error', 'betAmount must be a positive number', 'code', 'invalid_amount');
  END IF;

  SELECT COALESCE(coins, 0)
  INTO v_coins
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'user not found', 'code', 'user_not_found');
  END IF;

  SELECT *
  INTO v_existing
  FROM public.wave_game_flows
  WHERE transaction_id = p_transaction_id;

  IF FOUND THEN
    IF v_existing.user_id <> p_user_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'transaction already used', 'code', 'duplicate_transaction');
    END IF;
    RETURN jsonb_build_object(
      'success', true,
      'already', true,
      'balance', COALESCE(v_existing.balance_after, v_coins)
    );
  END IF;

  v_delta := CASE WHEN p_flow_type = 1 THEN -p_amount ELSE p_amount END;
  v_new_balance := v_coins + v_delta;
  IF v_new_balance < 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'insufficient balance',
      'code', 'insufficient_funds',
      'balance', v_coins
    );
  END IF;

  v_tx_type := CASE WHEN p_flow_type = 1 THEN 'game_loss' ELSE 'game_win' END;

  UPDATE public.users
  SET coins = v_new_balance
  WHERE id = p_user_id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  ) VALUES (
    p_user_id,
    p_amount,
    'coin',
    v_tx_type,
    p_user_id
  );

  INSERT INTO public.wave_game_flows (
    transaction_id,
    user_id,
    flow_type,
    amount,
    game_name,
    game_id,
    balance_after
  ) VALUES (
    p_transaction_id,
    p_user_id,
    p_flow_type,
    p_amount,
    NULLIF(btrim(COALESCE(p_game_name, '')), ''),
    p_game_id,
    v_new_balance
  );

  RETURN jsonb_build_object(
    'success', true,
    'already', false,
    'balance', v_new_balance
  );
END;
$$;

REVOKE ALL ON FUNCTION public.wave_apply_flow(uuid, text, smallint, bigint, text, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.wave_apply_flow(uuid, text, smallint, bigint, text, bigint) TO service_role;
