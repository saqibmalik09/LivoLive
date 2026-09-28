-- Fix resolve_game_winner_v2 ship blockers:
-- B1 solvency exposure, B2 normalize 1/Σ, H3 mercy 5%+pref, M6 weighted fallbacks,
-- M4 restore resolve_game_winner_v1 + real kill-switch, M9 idempotency,
-- default game_max_round_exposure 12.0, optional per-game config_data.max_round_exposure.

UPDATE public.system_settings
SET
  value = '12.0',
  description = 'Solvency resample if payout > pool×this + 20% of positive bank. Per-game override: config_data.max_round_exposure.',
  updated_at = now()
WHERE key = 'game_max_round_exposure';

INSERT INTO public.system_settings (key, value, description)
VALUES (
  'game_max_round_exposure',
  '12.0',
  'Solvency resample if payout > pool×this + 20% of positive bank. Per-game override: config_data.max_round_exposure.'
)
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();

UPDATE public.system_settings
SET
  description = 'Use inverse-multiplier RTP wheel (v2). false = legacy resolve_game_winner_v1.',
  updated_at = now()
WHERE key = 'game_engine_v2';


-- Legacy v1 body (kill-switch target)
CREATE OR REPLACE FUNCTION public.resolve_game_winner_v1(p_round_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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

    v_popular_rate double precision := 0.70;

    v_pay_to_bets_rate double precision := 0.40;
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

    -- Hard platform loss cap (default 100M): payout cannot push today net below -cap
    v_max_loss_cap bigint := 100000000;
    v_cap_max_payout bigint;

    v_has_safe_bets boolean;
    v_has_safe_any boolean;
BEGIN
    PERFORM public.maybe_auto_switch_game_mode();

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

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_random_popular_pick_rate';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_popular_rate := GREATEST(0, LEAST(1, v_tmp::double precision));
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_pay_to_bets_rate';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_pay_to_bets_rate := GREATEST(0, LEAST(1, v_tmp::double precision));
    ELSE
      SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_natural_win_rate';
      IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
        v_pay_to_bets_rate := GREATEST(0, LEAST(1, v_tmp::double precision));
      END IF;
    END IF;

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_house_soft_edge_rate';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
      v_soft_edge_rate := GREATEST(0, LEAST(1 - v_pay_to_bets_rate, v_tmp::double precision));
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

    SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_platform_max_loss_coins';
    IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]+$' THEN
      v_max_loss_cap := GREATEST(0, v_tmp::bigint);
    END IF;

    -- Today platform net (stakes already include this round; payouts not yet)
    SELECT coalesce(sum(amount), 0)::bigint - coalesce(sum(payout_amount), 0)::bigint
    INTO v_today_net
    FROM public.game_bets
    WHERE created_at >= date_trunc('day', now() AT TIME ZONE 'Asia/Karachi')
        AT TIME ZONE 'Asia/Karachi';

    -- After paying P: net becomes today_net - P. Require today_net - P >= -cap ⇒ P <= today_net + cap
    v_cap_max_payout := GREATEST(0, v_today_net + v_max_loss_cap);

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

    -- ── Random mode (still subject to hard 100M loss cap) ──
    IF coalesce(v_mode, 'random') <> 'house_optimized' THEN
      SELECT coalesce(sum(amount), 0) INTO v_total_pool
      FROM public.game_bets
      WHERE round_id = p_round_id;

      IF v_total_pool > 0 THEN
        v_roll := random();

        IF v_roll < v_popular_rate THEN
          WITH opts AS (
              SELECT value->>'id' AS option_id
              FROM jsonb_array_elements(v_options)
              WHERE coalesce(value->>'id', '') <> ''
          ),
          scored AS (
              SELECT
                  o.option_id,
                  power(
                    greatest(
                      coalesce((
                        SELECT count(*)::double precision
                        FROM public.game_bets b
                        WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
                      ), 0),
                      1
                    ),
                    2
                  ) AS w,
                  coalesce((
                      SELECT sum(b.amount)
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
          FROM scored
          WHERE stake_amount > 0
            AND potential_payout <= v_cap_max_payout
          ORDER BY -ln(greatest(random(), 1e-12)) / greatest(w, 1e-9)
          LIMIT 1;
        ELSE
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
                  )::double precision
                  * sqrt(
                      greatest(
                        coalesce((
                          SELECT sum(b.amount)::double precision
                          FROM public.game_bets b
                          WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
                        ), 0),
                        1
                      )
                    ) AS w,
                  coalesce((
                      SELECT sum(b.amount)
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
          FROM scored
          WHERE stake_amount > 0
            AND potential_payout <= v_cap_max_payout
          ORDER BY -ln(greatest(random(), 1e-12)) / greatest(w, 1e-9)
          LIMIT 1;
        END IF;

        -- Cap blocked all bet options → pick safest (lowest payout / empty)
        IF v_winner IS NULL THEN
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
          WHERE potential_payout <= v_cap_max_payout
          ORDER BY potential_payout ASC, stake_amount ASC, random()
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
          ORDER BY potential_payout ASC, random()
          LIMIT 1;
        END IF;
      END IF;

      IF v_winner IS NULL THEN
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
      END IF;

      RETURN v_winner;
    END IF;

    -- ── House-optimized mode ──
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

    -- Tightest of round RTP cap and platform loss hard cap
    v_max_payout := LEAST(
      floor(v_total_pool::double precision * v_max_round_rtp)::bigint,
      v_cap_max_payout
    );

    IF v_breaker > 0 THEN
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
      WHERE potential_payout <= v_cap_max_payout
      ORDER BY (v_total_pool - potential_payout) DESC, stake_amount ASC, random()
      LIMIT 1;

      IF v_winner IS NULL THEN
        SELECT option_id INTO v_winner
        FROM (
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
          FROM (
              SELECT value->>'id' AS option_id
              FROM jsonb_array_elements(v_options)
              WHERE coalesce(value->>'id', '') <> ''
          ) o
        ) payouts
        ORDER BY potential_payout ASC, stake_amount ASC, random()
        LIMIT 1;
      END IF;

      RETURN v_winner;
    END IF;

    v_roll := random();

    IF v_has_safe_bets AND v_roll < v_pay_to_bets_rate THEN
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
      WHERE potential_payout <= v_max_payout
        AND stake_amount > 0
      ORDER BY potential_payout ASC, stake_amount ASC, random()
      LIMIT 1;

    ELSIF v_has_safe_bets AND v_roll < (v_pay_to_bets_rate + v_soft_edge_rate) THEN
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
              public.game_outcome_weight(mult, v_weights)::double precision AS w
          FROM payouts
          WHERE potential_payout <= v_max_payout
      )
      SELECT option_id INTO v_winner
      FROM safe
      ORDER BY
        CASE WHEN stake_amount = 0 THEN 1 ELSE 0 END,
        -ln(greatest(random(), 1e-12)) / w
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
      WHERE potential_payout <= v_cap_max_payout
      ORDER BY (v_total_pool - potential_payout) DESC, random()
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
      ORDER BY potential_payout ASC, random()
      LIMIT 1;
    END IF;

    RETURN v_winner;
END;
$function$
;

GRANT EXECUTE ON FUNCTION public.resolve_game_winner_v1(uuid) TO authenticated, service_role;


-- Fixed resolve_game_winner_v2 (B1 exposure solvency, B2 normalize 1/Σ, H3 mercy pref, M6 weighted fallbacks, M9 idempotency).
-- Bank balance update removed (applied on actual settle). Keeps avg_pool EMA + streaks.

CREATE OR REPLACE FUNCTION public.resolve_game_winner_v2(p_round_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_game_id uuid;
  v_options jsonb;
  v_multipliers jsonb;
  v_config_data jsonb;
  v_total_pool bigint := 0;
  v_winner text;
  v_tmp text;
  v_existing text;

  v_target_rtp double precision := 0.90;
  v_bank_alpha double precision := 0.30;
  v_k_min double precision := 0.7;
  v_k_max double precision := 1.4;
  v_exposure double precision := 12.0;
  v_mercy_streak int := 8;
  v_mercy_max_mult int := 5;

  v_bank numeric := 0;
  v_avg_pool numeric := 0;
  v_k double precision := 1.0;
  v_blank_base double precision := 0;
  v_blank_w double precision := 0;
  v_sum_opt_w double precision := 0;
  v_total_w double precision := 0;
  v_pick double precision;
  v_acc double precision;
  v_want_blank boolean := false;
  v_payout bigint;
  v_attempt int;
  v_max_attempts int := 12;
  v_option_id text;
  v_weight double precision;
  v_mercy_pref text := NULL;
  v_eff_w double precision;
  v_eff_blank double precision;
  v_eff_total double precision;
BEGIN
  SELECT game_id, winner_result INTO v_game_id, v_existing
  FROM public.game_rounds
  WHERE id = p_round_id;

  IF v_game_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- M9: idempotent if winner already claimed
  IF v_existing IS NOT NULL AND btrim(v_existing) <> '' THEN
    RETURN v_existing;
  END IF;

  SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_target_rtp';
  IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
    v_target_rtp := GREATEST(0.50, LEAST(0.98, v_tmp::double precision));
  END IF;

  SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_bank_alpha';
  IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
    v_bank_alpha := GREATEST(0, LEAST(1, v_tmp::double precision));
  END IF;

  SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_bank_clamp_min';
  IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
    v_k_min := GREATEST(0.3, LEAST(1.0, v_tmp::double precision));
  END IF;

  SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_bank_clamp_max';
  IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
    v_k_max := GREATEST(1.0, LEAST(3.0, v_tmp::double precision));
  END IF;

  SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_max_round_exposure';
  IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
    v_exposure := GREATEST(1.0, LEAST(50.0, v_tmp::double precision));
  END IF;

  SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_mercy_streak';
  IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]+$' THEN
    v_mercy_streak := GREATEST(3, v_tmp::int);
  END IF;

  SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_mercy_max_mult';
  IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]+$' THEN
    v_mercy_max_mult := GREATEST(2, v_tmp::int);
  END IF;

  SELECT config_data
  INTO v_config_data
  FROM public.game_configs
  WHERE id = v_game_id;

  v_options := v_config_data->'options';
  v_multipliers := v_config_data->'multipliers';

  -- Optional per-game exposure override (e.g. Lucky 777 can keep 3)
  v_tmp := v_config_data->>'max_round_exposure';
  IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]*\.?[0-9]+$' THEN
    v_exposure := GREATEST(1.0, LEAST(50.0, v_tmp::double precision));
  END IF;

  IF v_options IS NULL OR jsonb_typeof(v_options) <> 'array' OR jsonb_array_length(v_options) = 0 THEN
    RETURN NULL;
  END IF;
  IF v_multipliers IS NULL OR jsonb_typeof(v_multipliers) <> 'object' THEN
    v_multipliers := '{}'::jsonb;
  END IF;

  SELECT coalesce(sum(amount), 0)::bigint INTO v_total_pool
  FROM public.game_bets
  WHERE round_id = p_round_id;

  INSERT INTO public.game_platform_bank (game_id)
  VALUES (v_game_id)
  ON CONFLICT (game_id) DO NOTHING;

  SELECT balance_coins, avg_pool_coins
  INTO v_bank, v_avg_pool
  FROM public.game_platform_bank
  WHERE game_id = v_game_id
  FOR UPDATE;

  IF v_avg_pool <= 0 THEN
    v_avg_pool := GREATEST(v_total_pool, 1)::numeric;
  END IF;

  -- Layer 2: blank adjustment from bank
  v_k := 1.0 + v_bank_alpha * (v_bank / (v_avg_pool * 20.0));
  IF v_k < v_k_min THEN v_k := v_k_min; END IF;
  IF v_k > v_k_max THEN v_k := v_k_max; END IF;

  CREATE TEMP TABLE IF NOT EXISTS _rgw_opts (
    option_id text PRIMARY KEY,
    mult int NOT NULL,
    stake bigint NOT NULL DEFAULT 0,
    potential bigint NOT NULL DEFAULT 0,
    w double precision NOT NULL DEFAULT 0
  ) ON COMMIT DROP;
  DELETE FROM _rgw_opts;

  INSERT INTO _rgw_opts (option_id, mult, stake, potential, w)
  SELECT
    o.option_id,
    GREATEST(1, coalesce((v_multipliers->>o.option_id)::int, 1)),
    coalesce((
      SELECT sum(b.amount)::bigint
      FROM public.game_bets b
      WHERE b.round_id = p_round_id AND b.bet_option = o.option_id
    ), 0),
    0,
    0
  FROM (
    SELECT DISTINCT value->>'id' AS option_id
    FROM jsonb_array_elements(v_options)
    WHERE coalesce(value->>'id', '') <> ''
  ) o;

  UPDATE _rgw_opts
  SET
    potential = stake * mult,
    w = v_target_rtp / mult::double precision;

  SELECT coalesce(sum(w), 0) INTO v_sum_opt_w FROM _rgw_opts;
  v_blank_base := GREATEST(0, 1.0 - v_sum_opt_w);

  -- B2: when Σ(R/m) > 1, normalize to unit mass (not R again) so blank≈0 and RTP≈1/Σ(1/m)
  IF v_sum_opt_w > 0.999 THEN
    UPDATE _rgw_opts SET w = w * (1.0 / v_sum_opt_w);
    SELECT coalesce(sum(w), 0) INTO v_sum_opt_w FROM _rgw_opts;
    v_blank_base := GREATEST(0, 1.0 - v_sum_opt_w);
  END IF;

  v_blank_w := CASE WHEN v_k > 0 THEN v_blank_base / v_k ELSE v_blank_base END;
  IF v_blank_w < 0 THEN v_blank_w := 0; END IF;

  v_total_w := v_sum_opt_w + v_blank_w;
  IF v_total_w <= 0 THEN
    UPDATE _rgw_opts SET w = 1.0 / (SELECT count(*)::double precision FROM _rgw_opts);
    v_blank_w := 0;
    v_total_w := 1;
  ELSE
    UPDATE _rgw_opts SET w = w / v_total_w;
    v_blank_w := v_blank_w / v_total_w;
  END IF;

  -- H3: soft mercy preference (still goes through exposure loop)
  IF v_bank >= (v_avg_pool * 2)
     AND EXISTS (
    SELECT 1
    FROM public.game_bets b
    JOIN public.game_player_streaks s
      ON s.game_id = v_game_id AND s.user_id = b.user_id
    JOIN _rgw_opts o ON o.option_id = b.bet_option
    WHERE b.round_id = p_round_id
      AND s.loss_streak >= v_mercy_streak
      AND o.mult <= v_mercy_max_mult
      AND o.stake > 0
  ) AND random() < 0.05 THEN
    SELECT o.option_id INTO v_mercy_pref
    FROM public.game_bets b
    JOIN public.game_player_streaks s
      ON s.game_id = v_game_id AND s.user_id = b.user_id
    JOIN _rgw_opts o ON o.option_id = b.bet_option
    WHERE b.round_id = p_round_id
      AND s.loss_streak >= v_mercy_streak
      AND o.mult <= v_mercy_max_mult
      AND o.stake > 0
    ORDER BY o.mult ASC, random()
    LIMIT 1;
  END IF;

  FOR v_attempt IN 1..v_max_attempts LOOP
    v_pick := random();
    v_acc := 0;
    v_want_blank := false;
    v_winner := NULL;

    -- Effective weights: mercy pref ×3, then renormalize with blank
    IF v_mercy_pref IS NOT NULL THEN
      SELECT coalesce(sum(CASE WHEN option_id = v_mercy_pref THEN w * 3.0 ELSE w END), 0)
        INTO v_eff_total
      FROM _rgw_opts;
      v_eff_blank := v_blank_w;
      v_eff_total := v_eff_total + v_eff_blank;
      IF v_eff_total <= 0 THEN
        v_eff_total := 1;
      END IF;
    ELSE
      v_eff_blank := v_blank_w;
      v_eff_total := 1.0;
    END IF;

    v_acc := CASE
      WHEN v_mercy_pref IS NOT NULL THEN v_eff_blank / v_eff_total
      ELSE v_blank_w
    END;
    IF v_pick < v_acc THEN
      v_want_blank := true;
    ELSE
      FOR v_option_id, v_weight IN
        SELECT option_id, w FROM _rgw_opts ORDER BY option_id
      LOOP
        v_eff_w := CASE
          WHEN v_mercy_pref IS NOT NULL AND v_option_id = v_mercy_pref THEN v_weight * 3.0
          ELSE v_weight
        END;
        IF v_mercy_pref IS NOT NULL THEN
          v_eff_w := v_eff_w / v_eff_total;
        END IF;
        v_acc := v_acc + v_eff_w;
        IF v_pick < v_acc THEN
          v_winner := v_option_id;
          EXIT;
        END IF;
      END LOOP;
      IF v_winner IS NULL THEN
        SELECT option_id INTO v_winner
        FROM _rgw_opts
        ORDER BY -ln(greatest(random(), 1e-12)) / greatest(w, 1e-12)
        LIMIT 1;
      END IF;
    END IF;

    IF v_want_blank THEN
      SELECT option_id INTO v_winner
      FROM _rgw_opts
      WHERE stake = 0
      ORDER BY -ln(greatest(random(), 1e-12)) / greatest(w, 1e-12)
      LIMIT 1;

      IF v_winner IS NULL THEN
        -- M6: all options bet — weighted fallback (not lowest potential)
        SELECT option_id INTO v_winner
        FROM _rgw_opts
        ORDER BY -ln(greatest(random(), 1e-12)) / greatest(w, 1e-12)
        LIMIT 1;
      END IF;
    END IF;

    SELECT potential INTO v_payout FROM _rgw_opts WHERE option_id = v_winner;
    v_payout := coalesce(v_payout, 0);

    -- B1: solvency exposure (pool×N + 20% of positive bank), not hard RTP kill
    IF v_total_pool > 0
       AND v_payout::numeric >
             (v_total_pool::numeric * v_exposure)
             + GREATEST(v_bank, 0) * 0.20
    THEN
      v_winner := NULL;
      CONTINUE;
    END IF;

    EXIT;
  END LOOP;

  IF v_winner IS NULL THEN
    -- M6: final fallback weighted
    SELECT option_id INTO v_winner
    FROM _rgw_opts
    ORDER BY -ln(greatest(random(), 1e-12)) / greatest(w, 1e-12)
    LIMIT 1;
  END IF;

  -- Rolling avg_pool only (bank balance applied on actual settle)
  UPDATE public.game_platform_bank
  SET
    avg_pool_coins = CASE
      WHEN rounds_counted <= 0 THEN GREATEST(v_total_pool, 1)::numeric
      ELSE avg_pool_coins * 0.95 + GREATEST(v_total_pool, 1)::numeric * 0.05
    END,
    rounds_counted = rounds_counted + 1,
    updated_at = now()
  WHERE game_id = v_game_id;

  INSERT INTO public.game_player_streaks (game_id, user_id, loss_streak, updated_at)
  SELECT
    v_game_id,
    b.user_id,
    CASE
      WHEN EXISTS (
        SELECT 1 FROM public.game_bets wb
        WHERE wb.round_id = p_round_id
          AND wb.user_id = b.user_id
          AND wb.bet_option = v_winner
      ) THEN 0
      ELSE coalesce(s.loss_streak, 0) + 1
    END,
    now()
  FROM (SELECT DISTINCT user_id FROM public.game_bets WHERE round_id = p_round_id) b
  LEFT JOIN public.game_player_streaks s
    ON s.game_id = v_game_id AND s.user_id = b.user_id
  ON CONFLICT (game_id, user_id) DO UPDATE
  SET
    loss_streak = EXCLUDED.loss_streak,
    updated_at = now();

  RETURN v_winner;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.resolve_game_winner_v2(uuid) TO authenticated, service_role;


-- Real kill-switch: OFF → legacy v1
CREATE OR REPLACE FUNCTION public.resolve_game_winner(p_round_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_tmp text;
  v_use_v2 boolean := true;
BEGIN
  SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_engine_v2';
  IF v_tmp IS NOT NULL THEN
    v_use_v2 := lower(btrim(v_tmp)) IN ('1', 'true', 'yes', 'on');
  END IF;

  IF v_use_v2 THEN
    RETURN public.resolve_game_winner_v2(p_round_id);
  END IF;

  RETURN public.resolve_game_winner_v1(p_round_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.resolve_game_winner(uuid) TO authenticated, service_role;
