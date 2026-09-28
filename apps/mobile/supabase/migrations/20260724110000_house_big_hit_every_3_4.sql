-- Every 3–4 settled rounds per game, force a "big number" (high multiplier) hit
-- when someone has bet on it. Keeps house_optimized otherwise.

INSERT INTO public.system_settings (key, value, description)
VALUES
  (
    'game_control_mode',
    'house_optimized',
    'H5 game engine mode: random | house_optimized'
  ),
  (
    'game_house_big_hit_every_min',
    '3',
    'Force a high-multiplier hit after this many rounds without one (min)'
  ),
  (
    'game_house_big_hit_every_max',
    '4',
    'Force a high-multiplier hit after this many rounds without one (max)'
  ),
  (
    'game_house_big_hit_min_mult',
    '15',
    'Multiplier >= this counts as a "big number" hit'
  ),
  (
    'game_house_natural_win_rate',
    '0.88',
    'When not forcing big hit: land on safe option that has bets'
  ),
  (
    'game_house_soft_edge_rate',
    '0.07',
    'When not forcing big hit: soft edge among safe bet options'
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
    v_has_safe_bets boolean;
    v_has_safe_any boolean;
    v_natural_rate double precision := 0.88;
    v_soft_edge_rate double precision := 0.07;
    v_big_min_mult int := 15;
    v_big_every_min int := 3;
    v_big_every_max int := 4;
    v_big_threshold int;
    v_rounds_since_big int := 0;
    v_force_big boolean := false;
    v_tmp text;
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

    -- This round forces big hit after 3 or 4 dry rounds (random in range).
    v_big_threshold := v_big_every_min
      + floor(random() * (v_big_every_max - v_big_every_min + 1))::int;

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

    -- How many settled rounds since last big-number win for this game?
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
      WHERE rn <= 20
    ),
    first_big AS (
      SELECT min(rn) AS rn FROM recent WHERE mult >= v_big_min_mult
    )
    SELECT coalesce(
      (SELECT rn - 1 FROM first_big WHERE rn IS NOT NULL),
      (SELECT count(*)::int FROM recent)
    )
    INTO v_rounds_since_big;

    v_force_big := v_rounds_since_big >= v_big_threshold;

    IF coalesce(v_mode, 'random') = 'house_optimized' THEN
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

        -- Forced big number: high mult option that has bets (prefer still safe for house).
        IF v_force_big THEN
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
                    mult,
                    stake_amount,
                    (v_total_pool - potential_payout) AS house_profit
                FROM payouts
                WHERE mult >= v_big_min_mult
                  AND stake_amount > 0
            )
            SELECT option_id INTO v_winner
            FROM ranked
            ORDER BY
              CASE WHEN house_profit >= 0 THEN 0 ELSE 1 END,
              mult DESC,
              stake_amount ASC,
              random()
            LIMIT 1;

            IF v_winner IS NOT NULL THEN
              RETURN v_winner;
            END IF;
            -- No big option has bets → fall through to normal logic
        END IF;

        v_roll := random();

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
        SELECT
            EXISTS (SELECT 1 FROM ranked r WHERE r.house_profit >= 0 AND r.stake_amount > 0),
            EXISTS (SELECT 1 FROM ranked r WHERE r.house_profit >= 0)
        INTO v_has_safe_bets, v_has_safe_any;

        IF v_has_safe_bets AND v_roll < v_natural_rate THEN
            -- Prefer smaller stakes (chhoti bets zyada)
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
            ),
            safe AS (
                SELECT option_id, stake_amount
                FROM ranked
                WHERE house_profit >= 0 AND stake_amount > 0
            )
            SELECT option_id INTO v_winner
            FROM safe
            ORDER BY stake_amount ASC, random()
            LIMIT 1;

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
            ranked AS (
                SELECT
                    option_id,
                    stake_amount,
                    (v_total_pool - potential_payout) AS house_profit
                FROM payouts
            )
            SELECT option_id INTO v_winner
            FROM ranked
            WHERE house_profit >= 0 AND stake_amount > 0
            ORDER BY stake_amount ASC, house_profit DESC, random()
            LIMIT 1;

        ELSIF v_has_safe_any THEN
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
            WHERE house_profit >= 0
            ORDER BY stake_amount ASC, house_profit DESC, random()
            LIMIT 1;

        ELSE
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
            ),
            ranked AS (
                SELECT
                    option_id,
                    (v_total_pool - potential_payout) AS house_profit
                FROM payouts
            )
            SELECT option_id INTO v_winner
            FROM ranked
            ORDER BY house_profit DESC, random()
            LIMIT 1;
        END IF;
    ELSE
        SELECT value->>'id' INTO v_winner
        FROM jsonb_array_elements(v_options)
        ORDER BY random()
        LIMIT 1;
    END IF;

    RETURN v_winner;
END;
$function$;
