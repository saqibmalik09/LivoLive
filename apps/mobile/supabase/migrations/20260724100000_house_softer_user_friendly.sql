-- Softer house_optimized: lower user loss, keep platform profitable.
-- Target feel: ~85–90% of resolvable rounds pay a safe option that already has bets
-- (users win, house still house_profit >= 0). Remaining edge from light/empty safe picks.
-- Never choose a losing outcome when any no-loss option exists.

INSERT INTO public.system_settings (key, value, description)
VALUES (
  'game_control_mode',
  'house_optimized',
  'H5 game engine mode: random | house_optimized'
)
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();

-- Tunables (editable from admin / system_settings without redeploy)
INSERT INTO public.system_settings (key, value, description)
VALUES
  (
    'game_house_natural_win_rate',
    '0.90',
    'house_optimized: probability to land on a no-loss option that already has bets (0–1)'
  ),
  (
    'game_house_soft_edge_rate',
    '0.06',
    'house_optimized: after natural window, pick lowest-stake no-loss option that still has bets'
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
    v_natural_rate double precision := 0.90;
    v_soft_edge_rate double precision := 0.06;
    v_tmp text;
BEGIN
    SELECT value INTO v_mode
    FROM public.system_settings
    WHERE key = 'game_control_mode';

    SELECT value INTO v_tmp
    FROM public.system_settings
    WHERE key = 'game_house_natural_win_rate';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_natural_rate := GREATEST(0, LEAST(1, v_tmp::double precision));
    END IF;

    SELECT value INTO v_tmp
    FROM public.system_settings
    WHERE key = 'game_house_soft_edge_rate';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_soft_edge_rate := GREATEST(0, LEAST(1 - v_natural_rate, v_tmp::double precision));
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
                    WHERE b.round_id = p_round_id
                      AND b.bet_option = o.option_id
                ), 0) AS stake_amount,
                (
                    coalesce((
                        SELECT sum(b.amount)::bigint
                        FROM public.game_bets b
                        WHERE b.round_id = p_round_id
                          AND b.bet_option = o.option_id
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
            -- Stake-weighted natural win: popular safe options hit more → better RTP
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
            ),
            picked AS (
                SELECT option_id
                FROM safe
                ORDER BY random() * ln(1 + stake_amount::double precision) DESC
                LIMIT 1
            )
            SELECT option_id INTO v_winner FROM picked;

        ELSIF v_has_safe_bets AND v_roll < (v_natural_rate + v_soft_edge_rate) THEN
            -- Soft edge: still pay some users, but lightest safe bet-option
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
            -- Remaining edge: empty / light no-loss option (platform keeps coins)
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
            -- All options lose — minimize platform loss (never seek extra pain)
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
