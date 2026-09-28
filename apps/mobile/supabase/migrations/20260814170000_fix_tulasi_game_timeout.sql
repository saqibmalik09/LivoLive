-- SK Live: drop gameEndTimestamp reject (same bug as Rave — 1–2s late callbacks).

CREATE OR REPLACE FUNCTION public.tulasi_apply_balance(
  p_user_id uuid,
  p_transaction_id text,
  p_type int,
  p_coin bigint,
  p_game_coin bigint,
  p_game_end_ts_ms bigint DEFAULT NULL,
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
  v_game_coin bigint;
  v_existing public.tulasi_game_transactions%ROWTYPE;
  v_delta_coin bigint := 0;
  v_delta_game bigint := 0;
  v_tx_type text;
BEGIN
  IF p_user_id IS NULL OR COALESCE(btrim(p_transaction_id), '') = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid request');
  END IF;
  IF p_type IS NULL OR p_type < 0 OR p_type > 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid type');
  END IF;

  SELECT short_id, COALESCE(coins, 0)
  INTO v_short_id, v_coins
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'user not found');
  END IF;
  IF v_short_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'user has no short_id');
  END IF;

  INSERT INTO public.tulasi_game_wallets (user_id, game_coin, updated_at)
  VALUES (p_user_id, 0, now())
  ON CONFLICT (user_id) DO NOTHING;

  SELECT COALESCE(game_coin, 0)
  INTO v_game_coin
  FROM public.tulasi_game_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  SELECT *
  INTO v_existing
  FROM public.tulasi_game_transactions
  WHERE transaction_id = p_transaction_id;

  IF FOUND AND v_existing.status = 'success' THEN
    RETURN jsonb_build_object(
      'success', true,
      'already', true,
      'id', v_short_id,
      'coin', v_coins,
      'gameCoin', v_game_coin
    );
  END IF;

  -- p_game_end_ts_ms intentionally ignored (callback latency made every REDUCE fail).

  IF p_type IN (0, 1) AND COALESCE(p_coin, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'coin amount required');
  END IF;
  IF p_type IN (2, 3) AND COALESCE(p_game_coin, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'gameCoin amount required');
  END IF;

  IF p_type = 0 THEN
    v_delta_coin := -COALESCE(p_coin, 0);
    v_tx_type := 'game_loss';
  ELSIF p_type = 1 THEN
    v_delta_coin := COALESCE(p_coin, 0);
    v_tx_type := 'game_win';
  ELSIF p_type = 2 THEN
    v_delta_game := -COALESCE(p_game_coin, 0);
  ELSIF p_type = 3 THEN
    v_delta_game := COALESCE(p_game_coin, 0);
  END IF;

  IF v_coins + v_delta_coin < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient coins', 'id', v_short_id, 'coin', v_coins);
  END IF;
  IF v_game_coin + v_delta_game < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient gameCoin', 'id', v_short_id, 'coin', v_coins);
  END IF;

  IF v_delta_coin <> 0 THEN
    UPDATE public.users
    SET coins = coins + v_delta_coin
    WHERE id = p_user_id;
    v_coins := v_coins + v_delta_coin;

    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      p_user_id,
      ABS(v_delta_coin),
      'coin',
      v_tx_type,
      p_user_id
    );
  END IF;

  IF v_delta_game <> 0 THEN
    UPDATE public.tulasi_game_wallets
    SET game_coin = game_coin + v_delta_game,
        updated_at = now()
    WHERE user_id = p_user_id;
    v_game_coin := v_game_coin + v_delta_game;
  END IF;

  INSERT INTO public.tulasi_game_transactions (
    transaction_id, user_id, type, coin, game_coin, status, snapshot
  ) VALUES (
    p_transaction_id,
    p_user_id,
    p_type,
    COALESCE(p_coin, 0),
    COALESCE(p_game_coin, 0),
    'success',
    COALESCE(p_snapshot, '{}'::jsonb) || jsonb_build_object(
      'coin_after', v_coins,
      'game_coin_after', v_game_coin
    )
  )
  ON CONFLICT (transaction_id) DO UPDATE
    SET status = 'success',
        snapshot = EXCLUDED.snapshot
    WHERE public.tulasi_game_transactions.status <> 'success';

  RETURN jsonb_build_object(
    'success', true,
    'already', false,
    'id', v_short_id,
    'coin', v_coins,
    'gameCoin', v_game_coin
  );
END;
$$;
