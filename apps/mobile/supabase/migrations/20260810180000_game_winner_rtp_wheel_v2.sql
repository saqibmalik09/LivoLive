-- Game winner v2: inverse-multiplier RTP wheel + bank controller + exposure/mercy.
-- Replaces bang-bang house/random switching with a single target_rtp engine.

CREATE TABLE IF NOT EXISTS public.game_platform_bank (
  game_id uuid PRIMARY KEY REFERENCES public.game_configs(id) ON DELETE CASCADE,
  balance_coins numeric NOT NULL DEFAULT 0,
  avg_pool_coins numeric NOT NULL DEFAULT 0,
  rounds_counted bigint NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.game_player_streaks (
  game_id uuid NOT NULL REFERENCES public.game_configs(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  loss_streak int NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (game_id, user_id)
);

CREATE INDEX IF NOT EXISTS game_player_streaks_loss_idx
  ON public.game_player_streaks (game_id, loss_streak DESC);

ALTER TABLE public.game_platform_bank ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_player_streaks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS game_platform_bank_no_client ON public.game_platform_bank;
CREATE POLICY game_platform_bank_no_client
  ON public.game_platform_bank FOR ALL TO authenticated, anon
  USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS game_player_streaks_no_client ON public.game_player_streaks;
CREATE POLICY game_player_streaks_no_client
  ON public.game_player_streaks FOR ALL TO authenticated, anon
  USING (false) WITH CHECK (false);

-- Settings (single RTP engine)
INSERT INTO public.system_settings (key, value, description)
VALUES
  ('game_engine_v2', 'true', 'Use inverse-multiplier RTP wheel resolver (v2).'),
  ('game_target_rtp', '0.90', 'Target player RTP (0.90 = 10% platform edge).'),
  ('game_bank_alpha', '0.30', 'Bank controller strength for blank-weight adjustment.'),
  ('game_bank_clamp_min', '0.7', 'Min k for blank adjustment.'),
  ('game_bank_clamp_max', '1.4', 'Max k for blank adjustment.'),
  ('game_max_round_exposure', '3.0', 'Resample if payout would exceed pool × this.'),
  ('game_mercy_streak', '8', 'Consecutive losses before mercy bias.'),
  ('game_mercy_max_mult', '5', 'Mercy only toward options with multiplier ≤ this.'),
  ('game_control_auto_switch', 'false', 'Disabled under v2 (single RTP engine).')
ON CONFLICT (key) DO UPDATE
SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();

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
  v_total_pool bigint := 0;
  v_winner text;
  v_tmp text;

  v_target_rtp double precision := 0.90;
  v_bank_alpha double precision := 0.30;
  v_k_min double precision := 0.7;
  v_k_max double precision := 1.4;
  v_exposure double precision := 3.0;
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
  v_mult int;
  v_stake bigint;
  v_attempt int;
  v_max_attempts int := 12;
  v_option_id text;
  v_weight double precision;
BEGIN
  SELECT game_id INTO v_game_id
  FROM public.game_rounds
  WHERE id = p_round_id;

  IF v_game_id IS NULL THEN
    RETURN NULL;
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
    v_exposure := GREATEST(1.0, LEAST(20.0, v_tmp::double precision));
  END IF;

  SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_mercy_streak';
  IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]+$' THEN
    v_mercy_streak := GREATEST(3, v_tmp::int);
  END IF;

  SELECT value INTO v_tmp FROM public.system_settings WHERE key = 'game_mercy_max_mult';
  IF v_tmp IS NOT NULL AND v_tmp ~ '^[0-9]+$' THEN
    v_mercy_max_mult := GREATEST(2, v_tmp::int);
  END IF;

  SELECT
    config_data->'options',
    config_data->'multipliers'
  INTO v_options, v_multipliers
  FROM public.game_configs
  WHERE id = v_game_id;

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

  -- Build option weights: w_i = R / m_i
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
  -- If multipliers imply sum(R/m) > 1, normalize option weights to target_rtp mass.
  IF v_sum_opt_w > 0.999 THEN
    UPDATE _rgw_opts SET w = w * (v_target_rtp / v_sum_opt_w);
    SELECT coalesce(sum(w), 0) INTO v_sum_opt_w FROM _rgw_opts;
    v_blank_base := GREATEST(0, 1.0 - v_sum_opt_w);
  END IF;

  v_blank_w := CASE WHEN v_k > 0 THEN v_blank_base / v_k ELSE v_blank_base END;
  IF v_blank_w < 0 THEN v_blank_w := 0; END IF;

  -- Renormalize so option + blank = 1
  v_total_w := v_sum_opt_w + v_blank_w;
  IF v_total_w <= 0 THEN
    UPDATE _rgw_opts SET w = 1.0 / (SELECT count(*)::double precision FROM _rgw_opts);
    v_blank_w := 0;
    v_total_w := 1;
  ELSE
    UPDATE _rgw_opts SET w = w / v_total_w;
    v_blank_w := v_blank_w / v_total_w;
  END IF;

  -- Layer 3 mercy: if cold players bet on low mult and bank allows, soft-force that option.
  IF v_bank >= 0 AND EXISTS (
    SELECT 1
    FROM public.game_bets b
    JOIN public.game_player_streaks s
      ON s.game_id = v_game_id AND s.user_id = b.user_id
    JOIN _rgw_opts o ON o.option_id = b.bet_option
    WHERE b.round_id = p_round_id
      AND s.loss_streak >= v_mercy_streak
      AND o.mult <= v_mercy_max_mult
      AND o.stake > 0
  ) AND random() < 0.45 THEN
    SELECT o.option_id INTO v_winner
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

  -- Layer 1 (+ exposure resample)
  IF v_winner IS NULL THEN
    FOR v_attempt IN 1..v_max_attempts LOOP
      v_pick := random();
      v_acc := 0;
      v_want_blank := false;
      v_winner := NULL;

      v_acc := v_blank_w;
      IF v_pick < v_acc THEN
        v_want_blank := true;
      ELSE
        FOR v_option_id, v_weight IN
          SELECT option_id, w FROM _rgw_opts ORDER BY option_id
        LOOP
          v_acc := v_acc + v_weight;
          IF v_pick < v_acc THEN
            v_winner := v_option_id;
            EXIT;
          END IF;
        END LOOP;
        IF v_winner IS NULL THEN
          SELECT option_id INTO v_winner
          FROM _rgw_opts
          ORDER BY w DESC, random()
          LIMIT 1;
        END IF;
      END IF;

      IF v_want_blank THEN
        -- Visual blank = an option with no bets (true house win).
        SELECT option_id INTO v_winner
        FROM _rgw_opts
        WHERE stake = 0
        ORDER BY random()
        LIMIT 1;

        IF v_winner IS NULL THEN
          -- All options have bets; cannot blank — pick lowest potential payout.
          SELECT option_id INTO v_winner
          FROM _rgw_opts
          ORDER BY potential ASC, random()
          LIMIT 1;
        END IF;
      END IF;

      SELECT potential INTO v_payout FROM _rgw_opts WHERE option_id = v_winner;
      v_payout := coalesce(v_payout, 0);

      -- Exposure cap: resample (don't force blank)
      IF v_total_pool > 0 AND v_payout > (v_total_pool::double precision * v_exposure) THEN
        v_winner := NULL;
        CONTINUE;
      END IF;

      EXIT;
    END LOOP;
  END IF;

  IF v_winner IS NULL THEN
    SELECT option_id INTO v_winner
    FROM _rgw_opts
    ORDER BY potential ASC, random()
    LIMIT 1;
  END IF;

  -- Update rolling bank: + pool*R − payout
  SELECT stake, mult INTO v_stake, v_mult FROM _rgw_opts WHERE option_id = v_winner;
  v_payout := coalesce(v_stake, 0) * coalesce(v_mult, 0);

  UPDATE public.game_platform_bank
  SET
    balance_coins = balance_coins + (v_total_pool::numeric * v_target_rtp) - v_payout::numeric,
    avg_pool_coins = CASE
      WHEN rounds_counted <= 0 THEN GREATEST(v_total_pool, 1)::numeric
      ELSE avg_pool_coins * 0.95 + GREATEST(v_total_pool, 1)::numeric * 0.05
    END,
    rounds_counted = rounds_counted + 1,
    updated_at = now()
  WHERE game_id = v_game_id;

  -- Update loss streaks for bettors this round
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

-- Cutover: resolve_game_winner delegates to v2 when enabled (default true).
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

  -- Legacy path kept only as emergency rollback (re-install old body if needed).
  -- For safety, still use v2 if legacy body was replaced.
  RETURN public.resolve_game_winner_v2(p_round_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.resolve_game_winner(uuid) TO authenticated, service_role;

-- Auto-switch becomes a no-op under v2 (single engine).
-- Keep RETURNS text to match existing signature.
CREATE OR REPLACE FUNCTION public.maybe_auto_switch_game_mode()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
BEGIN
  -- Legacy bang-bang Random↔House switch retired. RTP wheel (v2) is the engine.
  RETURN 'v2_rtp_wheel';
END;
$function$;

GRANT EXECUTE ON FUNCTION public.maybe_auto_switch_game_mode() TO authenticated, service_role;
