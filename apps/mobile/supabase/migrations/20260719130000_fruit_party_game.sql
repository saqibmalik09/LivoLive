-- Fruit Party: seed game_configs + initial round + jackpot accrual on resolve

-- Ensure slug unique constraint exists (needed for ON CONFLICT)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'game_configs_slug_key'
  ) THEN
    ALTER TABLE public.game_configs ADD CONSTRAINT game_configs_slug_key UNIQUE (slug);
  END IF;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END $$;

INSERT INTO public.game_configs (
  slug, name, is_active, min_bet, max_bet,
  betting_duration, spinning_duration, result_duration,
  config_data, game_url, icon_url, sort_order, maintenance_mode
)
VALUES (
  'fruit_party',
  'Fruit Party',
  true,
  1000,
  500000,
  interval '20 seconds',
  interval '10 seconds',
  interval '5 seconds',
  jsonb_build_object(
    'options', jsonb_build_array(
      jsonb_build_object('id', 'strawberry'),
      jsonb_build_object('id', 'banana'),
      jsonb_build_object('id', 'watermelon'),
      jsonb_build_object('id', 'cherry'),
      jsonb_build_object('id', 'grape'),
      jsonb_build_object('id', 'orange'),
      jsonb_build_object('id', 'plum'),
      jsonb_build_object('id', 'lemon')
    ),
    'multipliers', jsonb_build_object(
      'strawberry', 5,
      'banana', 5,
      'watermelon', 5,
      'cherry', 40,
      'grape', 5,
      'orange', 20,
      'plum', 10,
      'lemon', 10
    ),
    'jackpot_amount', 28685859,
    'jackpot_rate', 0.01
  ),
  'https://sk-live-games.vercel.app/fruit-party',
  'https://sk-live-games.vercel.app/game-icons/fruit_party_icon.png',
  6,
  false
)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  is_active = EXCLUDED.is_active,
  min_bet = EXCLUDED.min_bet,
  max_bet = EXCLUDED.max_bet,
  betting_duration = EXCLUDED.betting_duration,
  spinning_duration = EXCLUDED.spinning_duration,
  result_duration = EXCLUDED.result_duration,
  config_data = EXCLUDED.config_data,
  game_url = EXCLUDED.game_url,
  icon_url = EXCLUDED.icon_url,
  sort_order = EXCLUDED.sort_order;

-- Start first round if none active
INSERT INTO public.game_rounds (game_id, status, betting_ends_at, spinning_ends_at, round_ends_at)
SELECT
  c.id,
  'betting',
  now() + c.betting_duration,
  now() + c.betting_duration + c.spinning_duration,
  now() + c.betting_duration + c.spinning_duration + c.result_duration
FROM public.game_configs c
WHERE c.slug = 'fruit_party'
  AND NOT EXISTS (
    SELECT 1 FROM public.game_rounds r
    WHERE r.game_id = c.id AND r.status <> 'finished'
  );

-- Accrue jackpot: 1% of round bet volume into config_data.jackpot_amount for fruit_party
CREATE OR REPLACE FUNCTION public.accrue_fruit_party_jackpot(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_game_id uuid;
  v_slug text;
  v_rate numeric;
  v_total bigint;
  v_add numeric;
BEGIN
  SELECT r.game_id, c.slug,
         COALESCE((c.config_data->>'jackpot_rate')::numeric, 0.01)
  INTO v_game_id, v_slug, v_rate
  FROM public.game_rounds r
  JOIN public.game_configs c ON c.id = r.game_id
  WHERE r.id = p_round_id;

  IF v_slug IS DISTINCT FROM 'fruit_party' THEN
    RETURN;
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_total
  FROM public.game_bets
  WHERE round_id = p_round_id;

  IF v_total <= 0 OR v_rate <= 0 THEN
    RETURN;
  END IF;

  v_add := ROUND(v_total * v_rate);

  UPDATE public.game_configs
  SET config_data = jsonb_set(
    COALESCE(config_data, '{}'::jsonb),
    '{jackpot_amount}',
    to_jsonb(
      COALESCE((config_data->>'jackpot_amount')::numeric, 0) + v_add
    )
  )
  WHERE id = v_game_id;
END;
$function$;

-- Patch advance_game_rounds to call jackpot accrual after processing bets
CREATE OR REPLACE FUNCTION public.advance_game_rounds()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

      BEGIN
        PERFORM public.accrue_fruit_party_jackpot(v_round.id);
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
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
$function$;
