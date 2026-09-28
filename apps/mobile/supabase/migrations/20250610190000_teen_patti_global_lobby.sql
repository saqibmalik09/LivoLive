-- Teen Patti: global lobby (room_id optional / NULL = worldwide table).

DROP FUNCTION IF EXISTS public.teen_patti_join_round(uuid, bigint);

ALTER TABLE public.teen_patti_rounds
  ALTER COLUMN room_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_teen_patti_global_rounds
  ON public.teen_patti_rounds (status, created_at DESC)
  WHERE room_id IS NULL;

CREATE OR REPLACE FUNCTION public.teen_patti_ensure_round(p_room_id uuid DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_round_id uuid;
BEGIN
  SELECT id INTO v_round_id
  FROM public.teen_patti_rounds
  WHERE status <> 'finished'
    AND (
      (p_room_id IS NULL AND room_id IS NULL)
      OR room_id = p_room_id
    )
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_round_id IS NOT NULL THEN
    RETURN v_round_id;
  END IF;

  INSERT INTO public.teen_patti_rounds (
    room_id, status, pot, boot_amount, betting_ends_at
  ) VALUES (
    p_room_id, 'betting', 0, 200, now() + interval '20 seconds'
  )
  RETURNING id INTO v_round_id;

  RETURN v_round_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.teen_patti_join_round(
  p_boot_amount bigint DEFAULT 200,
  p_room_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_round public.teen_patti_rounds%ROWTYPE;
  v_balance bigint;
  v_seat_count int;
  v_seat_index int;
  v_round_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_boot_amount IS NULL OR p_boot_amount < 10 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid boot amount');
  END IF;

  v_round_id := public.teen_patti_ensure_round(p_room_id);

  SELECT * INTO v_round
  FROM public.teen_patti_rounds
  WHERE id = v_round_id
  FOR UPDATE;

  IF v_round.status <> 'betting' THEN
    RETURN json_build_object('success', false, 'message', 'Betting closed for this round');
  END IF;

  IF now() >= v_round.betting_ends_at THEN
    RETURN json_build_object('success', false, 'message', 'Betting time ended');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.teen_patti_seats
    WHERE round_id = v_round.id AND user_id = v_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Already joined this round');
  END IF;

  SELECT count(*) INTO v_seat_count
  FROM public.teen_patti_seats
  WHERE round_id = v_round.id;

  IF v_seat_count >= v_round.max_seats THEN
    RETURN json_build_object('success', false, 'message', 'Table is full');
  END IF;

  SELECT coins INTO v_balance
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;

  IF v_balance < p_boot_amount THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  UPDATE public.users
  SET coins = coins - p_boot_amount
  WHERE id = v_user_id;

  SELECT COALESCE(min(s.i), v_seat_count)
  INTO v_seat_index
  FROM generate_series(0, v_round.max_seats - 1) AS s(i)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.teen_patti_seats ts
    WHERE ts.round_id = v_round.id AND ts.seat_index = s.i
  );

  INSERT INTO public.teen_patti_seats (
    round_id, user_id, seat_index, boot_paid
  ) VALUES (
    v_round.id, v_user_id, v_seat_index, p_boot_amount
  );

  UPDATE public.teen_patti_rounds
  SET pot = pot + p_boot_amount,
      boot_amount = p_boot_amount,
      updated_at = now()
  WHERE id = v_round.id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id, description
  ) VALUES (
    v_user_id, p_boot_amount, 'coin', 'game_loss', v_round.id, 'Teen Patti boot'
  );

  RETURN json_build_object(
    'success', true,
    'round_id', v_round.id,
    'seat_index', v_seat_index,
    'new_balance', v_balance - p_boot_amount
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.teen_patti_join_round(bigint, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teen_patti_ensure_round(uuid) TO authenticated;

-- Seed one global round if none active.
SELECT public.teen_patti_ensure_round(NULL);
