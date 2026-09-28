-- Outcome weights (user table): 5x common → 45x rare.
-- Applied as weighted random among SAFE options only (max_round_rtp still hard).
-- Default board (greedy/pizza): 4×5x@30 + 10x@12 + 15x@6 + 25x@2 + 45x@1 = 141.
-- Weighted pick uses Efraimidis–Spirakis: ORDER BY -ln(random())/weight.

INSERT INTO public.system_settings (key, value, description)
VALUES
  (
    'game_house_outcome_weights',
    '{"5":30,"10":12,"15":6,"25":2,"45":1}',
    'Multiplier → weight for weighted winner pick. 5x most common, 45x rarest. Safe options only.'
  ),
  (
    'game_house_natural_win_rate',
    '0.90',
    'Probability of weighted pick among safe options that have bets.'
  ),
  (
    'game_house_soft_edge_rate',
    '0.08',
    'Probability of picking highest house-profit safe option (edge top-up).'
  )
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();

CREATE OR REPLACE FUNCTION public.game_outcome_weight(
  p_mult int,
  p_weights jsonb DEFAULT NULL
)
RETURNS int
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  v_w jsonb := coalesce(
    p_weights,
    '{"5":30,"10":12,"15":6,"25":2,"45":1}'::jsonb
  );
  v_keys int[];
  v_k int;
  v_best int;
  v_val int;
BEGIN
  IF p_mult IS NULL OR p_mult <= 0 THEN
    RETURN greatest(1, coalesce((v_w->>'5')::int, 30));
  END IF;

  IF v_w ? p_mult::text THEN
    RETURN greatest(1, coalesce((v_w->>p_mult::text)::int, 1));
  END IF;

  SELECT array_agg(k ORDER BY k)
  INTO v_keys
  FROM (
    SELECT (key)::int AS k
    FROM jsonb_each_text(v_w) AS t(key, val)
    WHERE key ~ '^[0-9]+$'
  ) s;

  IF v_keys IS NULL OR array_length(v_keys, 1) IS NULL THEN
    RETURN 1;
  END IF;

  v_best := NULL;
  FOREACH v_k IN ARRAY v_keys LOOP
    IF v_k <= p_mult THEN
      v_best := v_k;
    END IF;
  END LOOP;

  IF v_best IS NULL THEN
    v_best := v_keys[1];
  END IF;

  v_val := coalesce((v_w->>v_best::text)::int, 1);
  RETURN greatest(1, v_val);
END;
$function$;

CREATE OR REPLACE FUNCTION public.resolve_game_winner(p_round_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_game_id uuid;
    v_mode text;
    v_winner text;
    v_options jsonb;
    v_multipliers jsonb;
    v_total_pool bigint;
    v_roll double precision;
    v_tmp text;
    v_weights jsonb := '{"5":30,"10":12,"15":6,"25":2,"45":1}'::jsonb;

    v_natural_rate double precision := 0.90;
    v_soft_edge_rate double precision := 0.08;
    v_max_round_rtp double precision := 0.95;
    v_max_payout bigint;

    v_big_enabled boolean := false;
    v_big_min_mult int := 15;
    v_big_every_min int := 80;
    v_big_every_max int := 120;
    v_big_rate double precision := 0.05;
    v_big_threshold int;
    v_rounds_since_big int := 0;
    v_force_big_window boolean := false;

    v_breaker bigint := 0;
    v_today_net bigint := 0;
    v_breaker_active boolean := false;

    v_has_safe_bets boolean;
    v_has_safe_any boolean;
BEGIN
    SELECT value INTO v_mode
    FROM public.system_settings
    WHERE key = 'game_control_mode';

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_outcome_weights';
    IF v_tmp IS NOT NULL AND left(btrim(v_tmp), 1) = '{' THEN
      BEGIN
        v_weights := v_tmp::jsonb;
      EXCEPTION WHEN others THEN
        v_weights := '{"5":30,"10":12,"15":6,"25":2,"45":1}'::jsonb;
      END;
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_natural_win_rate';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_natural_rate := GREATEST(0, LEAST(1, v_tmp::double precision));
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_soft_edge_rate';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_soft_edge_rate := GREATEST(0, LEAST(1 - v_natural_rate, v_tmp::double precision));
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_max_round_rtp';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_max_round_rtp := GREATEST(0.5, LEAST(1.0, v_tmp::double precision));
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_big_hit_enabled';
    IF v_tmp IS NOT NULL THEN
      v_big_enabled := lower(btrim(v_tmp)) IN ('1', 'true', 'yes', 'on');
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_big_hit_min_mult';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]+$' THEN
      v_big_min_mult := GREATEST(2, v_tmp::int);
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_big_hit_every_min';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]+$' THEN
      v_big_every_min := GREATEST(1, v_tmp::int);
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_big_hit_every_max';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]+$' THEN
      v_big_every_max := GREATEST(v_big_every_min, v_tmp::int);
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_big_hit_rate';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_big_rate := GREATEST(0, LEAST(1, v_tmp::double precision));
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_daily_loss_breaker';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]+$' THEN
      v_breaker := GREATEST(0, v_tmp::bigint);
    END IF;

    SELECT game_id INTO v_game_id
    FROM public.game_rounds
    WHERE id = p_round_id;

    SELECT
        config_data->'options',
        config_data->'multipliers'
    INTO v_options, v_multipliers
    FROM public.game_configs
    WHERE id = v_game_id;

    IF v_options IS NULL THEN
        RETURN NULL;
    END IF;

    -- Random mode: weighted by outcome table
    IF coalesce(v_mode, 'random') <> 'house_optimized' THEN
      WITH opts AS (
          SELECT value->>'id' AS option_id
          FROM jsonb_array_elements(v_options)
          WHERE coalesce(value->>'id', '') <> ''
      ),
      scored AS (
          SELECT
              o.option_id,
              public.game_outcome_weight(
                coalesce((v_multipliers->>o.option_id)::int, 5),
                v_weights
              )::double precision AS w
          FROM opts o
      )
      SELECT option_id INTO v_winner
      FROM scored
      ORDER BY -ln(greatest(random(), 1e-12)) / w
      LIMIT 1;
      RETURN v_winner;
    END IF;

    SELECT coalesce(sum(amount), 0) INTO v_total_pool
    FROM public.game_bets
    WHERE round_id = p_round_id;

    IF v_total_pool = 0 THEN
      WITH opts AS (
          SELECT value->>'id' AS option_id
          FROM jsonb_array_elements(v_options)
          WHERE coalesce(value->>'id', '') <> ''
      ),
      scored AS (
          SELECT
              o.option_id,
              public.game_outcome_weight(
                coalesce((v_multipliers->>o.option_id)::int, 5),
                v_weights
              )::double precision AS w
          FROM opts o
      )
      SELECT option_id INTO v_winner
      FROM scored
      ORDER BY -ln(greatest(random(), 1e-12)) / w
      LIMIT 1;
      RETURN v_winner;
    END IF;

    v_max_payout := floor(v_total_pool::double precision * v_max_round_rtp)::bigint;

    IF v_breaker > 0 THEN
      SELECT coalesce(sum(b.amount), 0)::bigint - coalesce(sum(b.payout_amount), 0)::bigint
      INTO v_today_net
      FROM public.game_bets b
      JOIN public.game_rounds r ON r.id = b.round_id
      WHERE r.game_id = v_game_id
        AND b.created_at >= date_trunc('day', now() AT TIME ZONE 'Asia/Karachi')
            AT TIME ZONE 'Asia/Karachi';
      v_breaker_active := v_today_net < -v_breaker;
    END IF;

    IF v_big_enabled AND NOT v_breaker_active THEN
      v_big_threshold := v_big_every_min
        + floor(random() * (v_big_every_max - v_big_every_min + 1))::int;

      WITH recent AS (
        SELECT mult, rn
        FROM (
          SELECT
            coalesce((v_multipliers->>r.winner_result)::int, 0) AS mult,
            row_number() OVER (
              ORDER BY r.created_at DESC, r.round_number DESC
            ) AS rn
          FROM public.game_rounds r
          WHERE r.game_id = v_game_id
            AND r.id IS DISTINCT FROM p_round_id
            AND r.winner_result IS NOT NULL
            AND r.winner_result <> ''
        ) x
        WHERE rn <= greatest(v_big_every_max + 5, 30)
      ),
      first_big AS (
        SELECT min(rn) AS rn FROM recent WHERE mult >= v_big_min_mult
      )
      SELECT coalesce(
        (SELECT rn - 1 FROM first_big WHERE rn IS NOT NULL),
        (SELECT count(*)::int FROM recent)
      )
      INTO v_rounds_since_big;

      v_force_big_window := v_rounds_since_big >= v_big_threshold;
    END IF;

    IF v_force_big_window AND random() < v_big_rate THEN
      WITH opts AS (
          SELECT value->>'id' AS option_id
          FROM jsonb_array_elements(v_options)
          WHERE coalesce(value->>'id', '') <> ''
      ),
      payouts AS (
          SELECT
              o.option_id,
              coalesce((v_multipliers->>o.option_id)::int, 0) AS mult,
              coalesce((
                  SELECT sum(b.amount)::bigint
                  FROM public.game_bets b
                  WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
              ), 0) AS stake_amount,
              (
                  coalesce((
                      SELECT sum(b.amount)::bigint
                      FROM public.game_bets b
                      WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
                  ), 0)
                  * coalesce((v_multipliers->>o.option_id)::int, 0)
              )::bigint AS potential_payout
          FROM opts o
      )
      SELECT option_id INTO v_winner
      FROM payouts
      WHERE mult >= v_big_min_mult
        AND stake_amount > 0
        AND potential_payout <= v_max_payout
      ORDER BY mult DESC, stake_amount ASC, random()
      LIMIT 1;

      IF v_winner IS NOT NULL THEN
        RETURN v_winner;
      END IF;
    END IF;

    WITH opts AS (
        SELECT value->>'id' AS option_id
        FROM jsonb_array_elements(v_options)
        WHERE coalesce(value->>'id', '') <> ''
    ),
    payouts AS (
        SELECT
            o.option_id,
            coalesce((v_multipliers->>o.option_id)::int, 0) AS mult,
            coalesce((
                SELECT sum(b.amount)::bigint
                FROM public.game_bets b
                WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
            ), 0) AS stake_amount,
            (
                coalesce((
                    SELECT sum(b.amount)::bigint
                    FROM public.game_bets b
                    WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
                ), 0)
                * coalesce((v_multipliers->>o.option_id)::int, 0)
            )::bigint AS potential_payout
        FROM opts o
    ),
    ranked AS (
        SELECT
            option_id,
            stake_amount,
            potential_payout,
            (potential_payout <= v_max_payout) AS is_safe
        FROM payouts
    )
    SELECT
        EXISTS (SELECT 1 FROM ranked r WHERE r.is_safe AND r.stake_amount > 0),
        EXISTS (SELECT 1 FROM ranked r WHERE r.is_safe)
    INTO v_has_safe_bets, v_has_safe_any;

    IF v_breaker_active OR NOT v_has_safe_any THEN
      WITH opts AS (
          SELECT value->>'id' AS option_id
          FROM jsonb_array_elements(v_options)
          WHERE coalesce(value->>'id', '') <> ''
      ),
      payouts AS (
          SELECT
              o.option_id,
              coalesce((
                  SELECT sum(b.amount)::bigint
                  FROM public.game_bets b
                  WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
              ), 0) AS stake_amount,
              (
                  coalesce((
                      SELECT sum(b.amount)::bigint
                      FROM public.game_bets b
                      WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
                  ), 0)
                  * coalesce((v_multipliers->>o.option_id)::int, 0)
              )::bigint AS potential_payout
          FROM opts o
      )
      SELECT option_id INTO v_winner
      FROM payouts
      ORDER BY (v_total_pool - potential_payout) DESC, stake_amount ASC, random()
      LIMIT 1;
      RETURN v_winner;
    END IF;

    v_roll := random();

    -- ~90%: weighted by outcome table among safe options that have bets
    IF v_has_safe_bets AND v_roll < v_natural_rate THEN
      WITH opts AS (
          SELECT value->>'id' AS option_id
          FROM jsonb_array_elements(v_options)
          WHERE coalesce(value->>'id', '') <> ''
      ),
      payouts AS (
          SELECT
              o.option_id,
              coalesce((v_multipliers->>o.option_id)::int, 0) AS mult,
              coalesce((
                  SELECT sum(b.amount)::bigint
                  FROM public.game_bets b
                  WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
              ), 0) AS stake_amount,
              (
                  coalesce((
                      SELECT sum(b.amount)::bigint
                      FROM public.game_bets b
                      WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
                  ), 0)
                  * coalesce((v_multipliers->>o.option_id)::int, 0)
              )::bigint AS potential_payout
          FROM opts o
      ),
      safe AS (
          SELECT
              option_id,
              public.game_outcome_weight(mult, v_weights)::double precision AS w
          FROM payouts
          WHERE potential_payout <= v_max_payout
            AND stake_amount > 0
      )
      SELECT option_id INTO v_winner
      FROM safe
      ORDER BY -ln(greatest(random(), 1e-12)) / w
      LIMIT 1;

    -- ~8%: soft edge — max house profit among safe bet options
    ELSIF v_has_safe_bets AND v_roll < (v_natural_rate + v_soft_edge_rate) THEN
      WITH opts AS (
          SELECT value->>'id' AS option_id
          FROM jsonb_array_elements(v_options)
          WHERE coalesce(value->>'id', '') <> ''
      ),
      payouts AS (
          SELECT
              o.option_id,
              coalesce((
                  SELECT sum(b.amount)::bigint
                  FROM public.game_bets b
                  WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
              ), 0) AS stake_amount,
              (
                  coalesce((
                      SELECT sum(b.amount)::bigint
                      FROM public.game_bets b
                      WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
                  ), 0)
                  * coalesce((v_multipliers->>o.option_id)::int, 0)
              )::bigint AS potential_payout
          FROM opts o
      )
      SELECT option_id INTO v_winner
      FROM payouts
      WHERE potential_payout <= v_max_payout
        AND stake_amount > 0
      ORDER BY (v_total_pool - potential_payout) DESC, stake_amount ASC, random()
      LIMIT 1;

    -- Remainder: weighted among all safe
    ELSE
      WITH opts AS (
          SELECT value->>'id' AS option_id
          FROM jsonb_array_elements(v_options)
          WHERE coalesce(value->>'id', '') <> ''
      ),
      payouts AS (
          SELECT
              o.option_id,
              coalesce((v_multipliers->>o.option_id)::int, 0) AS mult,
              (
                  coalesce((
                      SELECT sum(b.amount)::bigint
                      FROM public.game_bets b
                      WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
                  ), 0)
                  * coalesce((v_multipliers->>o.option_id)::int, 0)
              )::bigint AS potential_payout
          FROM opts o
      ),
      safe AS (
          SELECT
              option_id,
              public.game_outcome_weight(mult, v_weights)::double precision AS w
          FROM payouts
          WHERE potential_payout <= v_max_payout
      )
      SELECT option_id INTO v_winner
      FROM safe
      ORDER BY -ln(greatest(random(), 1e-12)) / w
      LIMIT 1;
    END IF;

    IF v_winner IS NULL THEN
      WITH opts AS (
          SELECT value->>'id' AS option_id
          FROM jsonb_array_elements(v_options)
          WHERE coalesce(value->>'id', '') <> ''
      ),
      payouts AS (
          SELECT
              o.option_id,
              (
                  coalesce((
                      SELECT sum(b.amount)::bigint
                      FROM public.game_bets b
                      WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
                  ), 0)
                  * coalesce((v_multipliers->>o.option_id)::int, 0)
              )::bigint AS potential_payout
          FROM opts o
      )
      SELECT option_id INTO v_winner
      FROM payouts
      ORDER BY (v_total_pool - potential_payout) DESC, random()
      LIMIT 1;
    END IF;

    RETURN v_winner;
END;
$function$;
