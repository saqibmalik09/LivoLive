-- Balanced house_optimized:
-- - Never pick a losing outcome when any no-loss option exists
-- - ~75%: land on a no-loss option that already has bets (users still win)
-- - ~25%: any no-loss option (prefer empty / lighter stake) so platform keeps edge
-- - Only if every option loses: least-loss fallback
-- Flip live mode to house_optimized.

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
BEGIN
    SELECT value INTO v_mode
    FROM public.system_settings
    WHERE key = 'game_control_mode';

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

        -- No bets → pure random (no money at risk)
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

        IF v_has_safe_bets AND v_roll < 0.75 THEN
            -- ~75%: natural user win on a bet option, house still not losing
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
            ORDER BY random()
            LIMIT 1;

        ELSIF v_has_safe_any THEN
            -- ~25% (or no safe bet-option): any no-loss option — prefer empty/light stake
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
            -- Board fully toxic — minimize platform loss
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
