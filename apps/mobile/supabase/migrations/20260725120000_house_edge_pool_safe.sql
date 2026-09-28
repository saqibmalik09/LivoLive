-- Platform-safe house edge: stop RTP bleed from forced big hits.
-- Hard rule: never pick an option where potential_payout > pool * max_round_rtp
-- when any safer option exists. Big-hit forcing OFF by default.

INSERT INTO public.system_settings (key, value, description)
VALUES
  (
    'game_control_mode',
    'house_optimized',
    'H5 game engine mode: random | house_optimized'
  ),
  (
    'game_house_target_edge',
    '0.10',
    'Soft target house edge (0.10 = 10%). Used for ranking among safe options.'
  ),
  (
    'game_house_max_round_rtp',
    '0.95',
    'Hard cap: never pay more than this fraction of the round pool when a safer option exists.'
  ),
  (
    'game_house_natural_win_rate',
    '0.75',
    'Probability of landing on a safe option that has bets (win feel).'
  ),
  (
    'game_house_soft_edge_rate',
    '0.20',
    'Probability of landing on safest high-profit option among bet options.'
  ),
  (
    'game_house_big_hit_enabled',
    'false',
    'If true, occasionally prefer high-mult options ONLY when still under max_round_rtp.'
  ),
  (
    'game_house_big_hit_every_min',
    '80',
    'Min settled rounds without a big hit before considering one (only if enabled).'
  ),
  (
    'game_house_big_hit_every_max',
    '120',
    'Max settled rounds without a big hit before considering one (only if enabled).'
  ),
  (
    'game_house_big_hit_min_mult',
    '15',
    'Multiplier >= this counts as a "big number" hit.'
  ),
  (
    'game_house_big_hit_rate',
    '0.05',
    'When big-hit window is open: probability of attempting a safe big hit.'
  ),
  (
    'game_house_daily_loss_breaker',
    '0',
    'If today house_net for this game < -this (coins), force safest only. 0 = disabled.'
  )
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();

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

    v_natural_rate double precision := 0.75;
    v_soft_edge_rate double precision := 0.20;
    v_max_round_rtp double precision := 0.95;
    v_target_edge double precision := 0.10;
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

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_target_edge';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_target_edge := GREATEST(0, LEAST(0.5, v_tmp::double precision));
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

    IF coalesce(v_mode, 'random') <> 'house_optimized' THEN
        SELECT value->>'id' INTO v_winner
        FROM jsonb_array_elements(v_options)
        ORDER BY random()
        LIMIT 1;
        RETURN v_winner;
    END IF;

    SELECT coalesce(sum(amount), 0) INTO v_total_pool
    FROM public.game_bets
    WHERE round_id = p_round_id;

    IF v_total_pool = 0 THEN
        SELECT value->>'id' INTO v_winner
        FROM jsonb_array_elements(v_options)
        ORDER BY random()
        LIMIT 1;
        RETURN v_winner;
    END IF;

    -- Max coins we are allowed to pay this round (hard cap).
    v_max_payout := floor(v_total_pool::double precision * v_max_round_rtp)::bigint;

    -- Optional daily circuit breaker: today house net already deeply negative → safest only.
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

    -- Big-hit window (affordable only). Disabled by default.
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

    -- Affordable big hit attempt (never exceeds max_payout).
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
      ),
      safe_big AS (
          SELECT option_id, mult, stake_amount, potential_payout,
                 (v_total_pool - potential_payout) AS house_profit
          FROM payouts
          WHERE mult >= v_big_min_mult
            AND stake_amount > 0
            AND potential_payout <= v_max_payout
      )
      SELECT option_id INTO v_winner
      FROM safe_big
      ORDER BY mult DESC, stake_amount ASC, random()
      LIMIT 1;

      IF v_winner IS NOT NULL THEN
        RETURN v_winner;
      END IF;
    END IF;

    -- Classify options under hard RTP cap.
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
    ),
    ranked AS (
        SELECT
            option_id,
            stake_amount,
            potential_payout,
            (v_total_pool - potential_payout) AS house_profit,
            (potential_payout <= v_max_payout) AS is_safe
        FROM payouts
    )
    SELECT
        EXISTS (SELECT 1 FROM ranked r WHERE r.is_safe AND r.stake_amount > 0),
        EXISTS (SELECT 1 FROM ranked r WHERE r.is_safe)
    INTO v_has_safe_bets, v_has_safe_any;

    -- Circuit breaker or no soft rolls: always pick safest.
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
      ),
      ranked AS (
          SELECT
              option_id,
              stake_amount,
              (v_total_pool - potential_payout) AS house_profit
          FROM payouts
      )
      SELECT option_id INTO v_winner
      FROM ranked
      ORDER BY house_profit DESC, stake_amount ASC, random()
      LIMIT 1;
      RETURN v_winner;
    END IF;

    v_roll := random();

    -- ~75%: natural win feel — safe option with bets, prefer smaller stake.
    IF v_has_safe_bets AND v_roll < v_natural_rate THEN
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
      ),
      safe AS (
          SELECT
              option_id,
              stake_amount,
              (v_total_pool - potential_payout) AS house_profit
          FROM payouts
          WHERE potential_payout <= v_max_payout
            AND stake_amount > 0
      )
      SELECT option_id INTO v_winner
      FROM safe
      ORDER BY
        -- Prefer options near target edge when possible, then smaller stakes (more winners feel)
        abs(house_profit::double precision / nullif(v_total_pool, 0) - v_target_edge),
        stake_amount ASC,
        random()
      LIMIT 1;

    -- ~20%: soft edge — safest among bet options under cap.
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
      ),
      safe AS (
          SELECT
              option_id,
              stake_amount,
              (v_total_pool - potential_payout) AS house_profit
          FROM payouts
          WHERE potential_payout <= v_max_payout
            AND stake_amount > 0
      )
      SELECT option_id INTO v_winner
      FROM safe
      ORDER BY house_profit DESC, stake_amount ASC, random()
      LIMIT 1;

    -- Remainder / empty-safe: land on any safe option (incl. zero bets = full house keep).
    ELSE
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
      ),
      safe AS (
          SELECT
              option_id,
              stake_amount,
              (v_total_pool - potential_payout) AS house_profit
          FROM payouts
          WHERE potential_payout <= v_max_payout
      )
      SELECT option_id INTO v_winner
      FROM safe
      ORDER BY house_profit DESC, stake_amount ASC, random()
      LIMIT 1;
    END IF;

    -- Absolute fallback: least loss.
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
