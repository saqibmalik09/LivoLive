-- Teen Patti card game engine (multiplayer per live room, fixed-boot showdown MVP).

CREATE TABLE IF NOT EXISTS public.teen_patti_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'betting'
    CHECK (status IN ('betting', 'showdown', 'finished')),
  pot bigint NOT NULL DEFAULT 0,
  boot_amount bigint NOT NULL DEFAULT 200,
  max_seats integer NOT NULL DEFAULT 6,
  betting_ends_at timestamptz NOT NULL DEFAULT (now() + interval '20 seconds'),
  round_ends_at timestamptz,
  winner_user_id uuid REFERENCES public.users(id),
  winner_hand_rank bigint,
  winner_hand_label text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_teen_patti_rounds_room_status
  ON public.teen_patti_rounds (room_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.teen_patti_seats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES public.teen_patti_rounds(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id),
  seat_index integer NOT NULL CHECK (seat_index >= 0 AND seat_index < 6),
  cards jsonb,
  hand_rank bigint,
  hand_label text,
  boot_paid bigint NOT NULL DEFAULT 0,
  cards_revealed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (round_id, user_id),
  UNIQUE (round_id, seat_index)
);

CREATE INDEX IF NOT EXISTS idx_teen_patti_seats_round
  ON public.teen_patti_seats (round_id);

-- Rank helper: A high for high-card; A=1 for A-2-3 sequence detection handled separately.
CREATE OR REPLACE FUNCTION public.teen_patti_rank_value(p_rank text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE upper(trim(p_rank))
    WHEN 'A' THEN 14 WHEN 'K' THEN 13 WHEN 'Q' THEN 12 WHEN 'J' THEN 11
    WHEN '10' THEN 10 WHEN '9' THEN 9 WHEN '8' THEN 8 WHEN '7' THEN 7
    WHEN '6' THEN 6 WHEN '5' THEN 5 WHEN '4' THEN 4 WHEN '3' THEN 3 WHEN '2' THEN 2
    ELSE 0 END;
$$;

CREATE OR REPLACE FUNCTION public.teen_patti_eval_hand(p_cards jsonb)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_ranks int[];
  v_suits text[];
  v_sorted int[];
  v_is_color boolean;
  v_is_seq boolean;
  v_is_a23 boolean;
  v_is_trail boolean;
  v_pair_high int := 0;
  v_kicker int := 0;
  v_score bigint;
  v_label text;
  i int;
  r int;
BEGIN
  IF p_cards IS NULL OR jsonb_array_length(p_cards) <> 3 THEN
    RETURN jsonb_build_object('score', 0, 'label', 'Invalid');
  END IF;

  SELECT
    array_agg(public.teen_patti_rank_value(c->>'r') ORDER BY 1),
    array_agg(upper(c->>'s') ORDER BY 1)
  INTO v_ranks, v_suits
  FROM jsonb_array_elements(p_cards) AS c;

  SELECT array_agg(x ORDER BY x DESC) INTO v_sorted FROM unnest(v_ranks) x;

  v_is_trail := v_sorted[1] = v_sorted[2] AND v_sorted[2] = v_sorted[3];
  v_is_color := v_suits[1] = v_suits[2] AND v_suits[2] = v_suits[3];

  v_is_a23 := v_sorted[1] = 14 AND v_sorted[2] = 3 AND v_sorted[3] = 2;
  v_is_seq := (
    v_sorted[1] - v_sorted[2] = 1 AND v_sorted[2] - v_sorted[3] = 1
  ) OR v_is_a23;

  IF v_is_trail THEN
    v_score := 600000000000 + v_sorted[1]::bigint * 1000000;
    v_label := 'Trail';
  ELSIF v_is_color AND v_is_seq THEN
    IF v_is_a23 THEN
      v_score := 500000000000 + 3;
    ELSE
      v_score := 500000000000 + v_sorted[1]::bigint * 1000000;
    END IF;
    v_label := 'Pure Sequence';
  ELSIF v_is_seq THEN
    IF v_is_a23 THEN
      v_score := 400000000000 + 3;
    ELSE
      v_score := 400000000000 + v_sorted[1]::bigint * 1000000;
    END IF;
    v_label := 'Sequence';
  ELSIF v_is_color THEN
    v_score := 300000000000
      + v_sorted[1]::bigint * 1000000
      + v_sorted[2]::bigint * 10000
      + v_sorted[3]::bigint * 100;
    v_label := 'Color';
  ELSIF v_sorted[1] = v_sorted[2] OR v_sorted[2] = v_sorted[3] OR v_sorted[1] = v_sorted[3] THEN
    IF v_sorted[1] = v_sorted[2] THEN
      v_pair_high := v_sorted[1];
      v_kicker := v_sorted[3];
    ELSIF v_sorted[2] = v_sorted[3] THEN
      v_pair_high := v_sorted[2];
      v_kicker := v_sorted[1];
    ELSE
      v_pair_high := v_sorted[1];
      v_kicker := v_sorted[2];
    END IF;
    v_score := 200000000000 + v_pair_high::bigint * 1000000 + v_kicker::bigint * 100;
    v_label := 'Pair';
  ELSE
    v_score := 100000000000
      + v_sorted[1]::bigint * 1000000
      + v_sorted[2]::bigint * 10000
      + v_sorted[3]::bigint * 100;
    v_label := 'High Card';
  END IF;

  RETURN jsonb_build_object('score', v_score, 'label', v_label);
END;
$$;

CREATE OR REPLACE FUNCTION public.teen_patti_ensure_round(p_room_id uuid)
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
  WHERE room_id = p_room_id AND status <> 'finished'
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
  p_room_id uuid,
  p_boot_amount bigint DEFAULT 200
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

  IF p_room_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Room is required');
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

CREATE OR REPLACE FUNCTION public.teen_patti_deal_and_showdown(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_round public.teen_patti_rounds%ROWTYPE;
  v_seat record;
  v_deck jsonb;
  v_card jsonb;
  v_idx int := 0;
  v_eval jsonb;
  v_best_score bigint := -1;
  v_winner uuid;
  v_winner_label text;
  v_winner_rank bigint;
BEGIN
  SELECT * INTO v_round FROM public.teen_patti_rounds WHERE id = p_round_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  SELECT jsonb_agg(card ORDER BY ord)
  INTO v_deck
  FROM (
    SELECT jsonb_build_object('s', suit, 'r', rank) AS card, random() AS ord
    FROM unnest(ARRAY['H','D','C','S']) AS suit
    CROSS JOIN unnest(ARRAY['A','K','Q','J','10','9','8','7','6','5','4','3','2']) AS rank
  ) d;

  FOR v_seat IN
    SELECT * FROM public.teen_patti_seats
    WHERE round_id = p_round_id
    ORDER BY seat_index
  LOOP
    v_eval := public.teen_patti_eval_hand(
      jsonb_build_array(v_deck->v_idx, v_deck->(v_idx + 1), v_deck->(v_idx + 2))
    );

    UPDATE public.teen_patti_seats
    SET cards = jsonb_build_array(v_deck->v_idx, v_deck->(v_idx + 1), v_deck->(v_idx + 2)),
        hand_rank = (v_eval->>'score')::bigint,
        hand_label = v_eval->>'label',
        cards_revealed = true
    WHERE id = v_seat.id;

    IF (v_eval->>'score')::bigint > v_best_score THEN
      v_best_score := (v_eval->>'score')::bigint;
      v_winner := v_seat.user_id;
      v_winner_label := v_eval->>'label';
      v_winner_rank := (v_eval->>'score')::bigint;
    END IF;

    v_idx := v_idx + 3;
  END LOOP;

  IF v_winner IS NOT NULL AND v_round.pot > 0 THEN
    UPDATE public.users SET coins = coins + v_round.pot WHERE id = v_winner;
    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id, description
    ) VALUES (
      v_winner, v_round.pot, 'coin', 'game_win', p_round_id, 'Teen Patti win'
    );
  END IF;

  UPDATE public.teen_patti_rounds
  SET status = 'showdown',
      winner_user_id = v_winner,
      winner_hand_label = v_winner_label,
      winner_hand_rank = v_winner_rank,
      round_ends_at = now() + interval '6 seconds',
      updated_at = now()
  WHERE id = p_round_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.teen_patti_refund_round(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seat record;
BEGIN
  FOR v_seat IN
    SELECT * FROM public.teen_patti_seats WHERE round_id = p_round_id
  LOOP
    UPDATE public.users SET coins = coins + v_seat.boot_paid WHERE id = v_seat.user_id;
    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id, description
    ) VALUES (
      v_seat.user_id, v_seat.boot_paid, 'coin', 'game_win', p_round_id, 'Teen Patti refund'
    );
  END LOOP;

  DELETE FROM public.teen_patti_seats WHERE round_id = p_round_id;

  UPDATE public.teen_patti_rounds
  SET pot = 0,
      status = 'finished',
      updated_at = now()
  WHERE id = p_round_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.teen_patti_advance_rounds()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_round public.teen_patti_rounds%ROWTYPE;
  v_seat_count int;
  v_room_id uuid;
BEGIN
  FOR v_round IN
    SELECT * FROM public.teen_patti_rounds
    WHERE status IN ('betting', 'showdown')
    ORDER BY created_at
    FOR UPDATE
  LOOP
    IF v_round.status = 'betting' AND now() >= v_round.betting_ends_at THEN
      SELECT count(*) INTO v_seat_count
      FROM public.teen_patti_seats
      WHERE round_id = v_round.id;

      IF v_seat_count >= 2 THEN
        PERFORM public.teen_patti_deal_and_showdown(v_round.id);
      ELSE
        PERFORM public.teen_patti_refund_round(v_round.id);
      END IF;
    ELSIF v_round.status = 'showdown' AND v_round.round_ends_at IS NOT NULL
      AND now() >= v_round.round_ends_at THEN
      v_room_id := v_round.room_id;
      UPDATE public.teen_patti_rounds
      SET status = 'finished', updated_at = now()
      WHERE id = v_round.id;

      INSERT INTO public.teen_patti_rounds (
        room_id, status, pot, boot_amount, betting_ends_at
      ) VALUES (
        v_room_id, 'betting', 0, COALESCE(v_round.boot_amount, 200), now() + interval '20 seconds'
      );
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.advance_game_rounds()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_round RECORD;
  v_winner text;
  v_next_betting_ends timestamptz;
  v_next_spinning_ends timestamptz;
  v_next_round_ends timestamptz;
BEGIN
  PERFORM public.teen_patti_advance_rounds();

  FOR v_round IN
    SELECT r.*, c.betting_duration, c.spinning_duration, c.result_duration
    FROM public.game_rounds r
    JOIN public.game_configs c ON r.game_id = c.id
    WHERE r.status <> 'finished'
  LOOP
    IF v_round.status = 'betting' AND now() >= v_round.betting_ends_at THEN
      v_winner := public.resolve_game_winner(v_round.id);
      UPDATE public.game_rounds
      SET status = 'spinning', winner_result = v_winner
      WHERE id = v_round.id;

      UPDATE public.game_bets b
      SET is_win = (b.bet_option = v_winner),
          payout_amount = CASE
            WHEN b.bet_option = v_winner THEN b.amount * (
              SELECT (config_data->'multipliers'->>b.bet_option)::int
              FROM public.game_configs WHERE id = v_round.game_id
            )
            ELSE 0
          END,
          is_processed = true
      WHERE round_id = v_round.id AND is_processed = false;

      UPDATE public.users u
      SET coins = u.coins + b.payout_amount
      FROM public.game_bets b
      WHERE b.round_id = v_round.id
        AND b.user_id = u.id
        AND b.is_win = true
        AND b.payout_amount > 0;
    ELSIF v_round.status = 'spinning' AND now() >= v_round.round_ends_at THEN
      UPDATE public.game_rounds SET status = 'finished' WHERE id = v_round.id;

      v_next_betting_ends := now() + v_round.betting_duration;
      v_next_spinning_ends := v_next_betting_ends + v_round.spinning_duration;
      v_next_round_ends := v_next_spinning_ends + v_round.result_duration;

      INSERT INTO public.game_rounds (
        game_id, status, betting_ends_at, spinning_ends_at, round_ends_at
      ) VALUES (
        v_round.game_id, 'betting',
        v_next_betting_ends, v_next_spinning_ends, v_next_round_ends
      );
    END IF;
  END LOOP;
END;
$$;

ALTER TABLE public.teen_patti_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teen_patti_seats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read teen_patti_rounds" ON public.teen_patti_rounds;
CREATE POLICY "Public read teen_patti_rounds"
  ON public.teen_patti_rounds FOR SELECT TO public USING (true);

DROP POLICY IF EXISTS "Public read teen_patti_seats" ON public.teen_patti_seats;
CREATE POLICY "Public read teen_patti_seats"
  ON public.teen_patti_seats FOR SELECT TO public USING (true);

GRANT SELECT ON public.teen_patti_rounds TO anon, authenticated;
GRANT SELECT ON public.teen_patti_seats TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.teen_patti_join_round(uuid, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teen_patti_ensure_round(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teen_patti_eval_hand(jsonb) TO anon, authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'teen_patti_rounds'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.teen_patti_rounds;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'teen_patti_seats'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.teen_patti_seats;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.resolve_game_source_label(
  p_source_label text,
  p_game_name text,
  p_game_slug text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT COALESCE(
    NULLIF(trim(p_source_label), ''),
    NULLIF(trim(p_game_name), ''),
    CASE lower(COALESCE(p_game_slug, ''))
      WHEN 'car-roulette' THEN 'Car Roulette'
      WHEN 'car_roulette' THEN 'Car Roulette'
      WHEN 'game' THEN 'Car Roulette'
      WHEN 'greedy' THEN 'Greedy'
      WHEN 'pizza' THEN 'Pizza'
      WHEN 'football' THEN 'Football'
      WHEN 'teen_patti' THEN 'Teen Patti'
      WHEN 'teen-patti' THEN 'Teen Patti'
      ELSE NULL
    END,
    'Mini Game'
  );
$$;

INSERT INTO public.game_configs (
  slug, name, is_active, game_url, icon_url, sort_order, min_bet, max_bet, config_data
) VALUES (
  'teen_patti',
  'Teen Patti',
  true,
  'https://sk-live-games.vercel.app/teen-patti',
  'https://sk-live-games.vercel.app/game-icons/teen_patti_icon.png',
  5,
  200,
  1000000,
  '{
    "boot_options": [200, 1000, 5000, 10000, 50000, 100000],
    "max_seats": 6,
    "betting_seconds": 20,
    "showdown_seconds": 6
  }'::jsonb
)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  is_active = EXCLUDED.is_active,
  game_url = EXCLUDED.game_url,
  icon_url = EXCLUDED.icon_url,
  sort_order = EXCLUDED.sort_order,
  min_bet = EXCLUDED.min_bet,
  max_bet = EXCLUDED.max_bet,
  config_data = EXCLUDED.config_data;
