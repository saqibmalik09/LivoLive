-- Task Center: 7-day check-in streak + prize wheel + newbie seed.

-- ---------------------------------------------------------------------------
-- Transaction types
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_transaction_type_check;
  ALTER TABLE public.transactions
    ADD CONSTRAINT transactions_transaction_type_check
    CHECK (transaction_type = ANY (ARRAY[
      'recharge'::text,
      'gift_sent'::text,
      'gift_received'::text,
      'lucky_gift_bonus'::text,
      'game_win'::text,
      'game_loss'::text,
      'withdrawal'::text,
      'purchase'::text,
      'agency_commission'::text,
      'salary_payout'::text,
      'transfer_out'::text,
      'transfer_in'::text,
      'exchange'::text,
      'rupee_game_entry'::text,
      'rupee_game_refund'::text,
      'lucky_pro_gift_bonus'::text,
      'room_reward'::text,
      'weekly_room_reward'::text,
      'invite_register_bonus'::text,
      'invite_welcome_bonus'::text,
      'invite_milestone'::text,
      'invite_wheel'::text,
      'invite_first_recharge'::text,
      'invite_recharge_bonus'::text,
      'task_checkin'::text,
      'task_wheel'::text,
      'task_reward'::text
    ]));
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'transactions check constraint update skipped: %', SQLERRM;
END $$;

-- ---------------------------------------------------------------------------
-- Columns / tables
-- ---------------------------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS task_wheel_draws integer NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.task_checkins (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  streak_day integer NOT NULL DEFAULT 0 CHECK (streak_day BETWEEN 0 AND 7),
  consecutive_days integer NOT NULL DEFAULT 0,
  last_checkin_date date,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.task_wheel_spins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reward_label text NOT NULL,
  reward_coins integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_task_wheel_spins_user
  ON public.task_wheel_spins (user_id, created_at DESC);

ALTER TABLE public.task_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_wheel_spins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS task_checkins_select_own ON public.task_checkins;
CREATE POLICY task_checkins_select_own ON public.task_checkins
  FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS task_wheel_spins_select_own ON public.task_wheel_spins;
CREATE POLICY task_wheel_spins_select_own ON public.task_wheel_spins
  FOR SELECT TO authenticated USING (user_id = auth.uid());

GRANT SELECT ON public.task_checkins TO authenticated;
GRANT SELECT ON public.task_wheel_spins TO authenticated;

-- Hide legacy flat sign_in daily task from lists (check-in grid replaces it)
UPDATE public.tasks
SET is_active = false
WHERE key = 'sign_in';

-- ---------------------------------------------------------------------------
-- Newbie seed (coin rewards) — upsert by key
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('newbie_room_3m', 'The room was active for 3 minutes', 'Stay in a voice room', 'newbie', 3, 'coins', 10, '/home'),
      ('newbie_mic_3m', '3 minutes on microphone in the room', 'Speak on a room mic', 'newbie', 3, 'coins', 10, '/home'),
      ('newbie_send_gift', 'Send a gift once in the room', 'Send any gift', 'newbie', 1, 'coins', 10, '/home'),
      ('newbie_follow_3', 'Follow 3 users', 'Follow other users', 'newbie', 3, 'coins', 10, '/home'),
      ('newbie_upload_3', 'Upload 3 photos', 'Add photos to your feed', 'newbie', 3, 'coins', 10, '/trends'),
      ('newbie_link_email', 'Link your email address', 'Bind an email to your account', 'newbie', 1, 'coins', 10, 'claim')
    ) AS v(key, title, description, category, target_count, reward_type, reward_amount, action_route)
  LOOP
    IF EXISTS (SELECT 1 FROM public.tasks t WHERE t.key = r.key) THEN
      UPDATE public.tasks SET
        title = r.title,
        description = r.description,
        category = r.category,
        target_count = r.target_count,
        reward_type = r.reward_type,
        reward_amount = r.reward_amount,
        action_route = r.action_route,
        is_active = true
      WHERE key = r.key;
    ELSE
      INSERT INTO public.tasks (
        key, title, description, category, target_count, reward_type, reward_amount, action_route, is_active
      ) VALUES (
        r.key, r.title, r.description, r.category, r.target_count, r.reward_type, r.reward_amount, r.action_route, true
      );
    END IF;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- Award +1 wheel draw when a task reward is claimed
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._award_task_wheel_draw_on_claim()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
BEGIN
  IF NEW.is_claimed IS TRUE AND COALESCE(OLD.is_claimed, false) IS FALSE THEN
    UPDATE public.users
    SET task_wheel_draws = COALESCE(task_wheel_draws, 0) + 1
    WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_task_claim_wheel_draw ON public.user_task_progress;
CREATE TRIGGER trg_task_claim_wheel_draw
  AFTER UPDATE OF is_claimed ON public.user_task_progress
  FOR EACH ROW
  EXECUTE PROCEDURE public._award_task_wheel_draw_on_claim();

-- ---------------------------------------------------------------------------
-- task_daily_checkin
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.task_daily_checkin()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_row public.task_checkins%ROWTYPE;
  v_today date := (now() AT TIME ZONE 'UTC')::date;
  v_next_day integer;
  v_reward integer;
  v_rewards integer[] := ARRAY[10, 10, 15, 20, 20, 30, 50];
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_row FROM public.task_checkins WHERE user_id = v_user_id FOR UPDATE;

  IF FOUND AND v_row.last_checkin_date = v_today THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Already checked in today',
      'streak_day', v_row.streak_day,
      'consecutive_days', v_row.consecutive_days,
      'checked_today', true
    );
  END IF;

  IF NOT FOUND THEN
    v_next_day := 1;
  ELSIF v_row.last_checkin_date = v_today - 1 THEN
    v_next_day := CASE WHEN v_row.streak_day >= 7 THEN 1 ELSE v_row.streak_day + 1 END;
  ELSE
    -- Missed a day → restart
    v_next_day := 1;
  END IF;

  v_reward := v_rewards[v_next_day];

  INSERT INTO public.task_checkins (user_id, streak_day, consecutive_days, last_checkin_date, updated_at)
  VALUES (
    v_user_id,
    v_next_day,
    CASE
      WHEN NOT FOUND THEN 1
      WHEN v_row.last_checkin_date = v_today - 1 THEN v_row.consecutive_days + 1
      ELSE 1
    END,
    v_today,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    streak_day = EXCLUDED.streak_day,
    consecutive_days = EXCLUDED.consecutive_days,
    last_checkin_date = EXCLUDED.last_checkin_date,
    updated_at = now();

  UPDATE public.users
  SET coins = COALESCE(coins, 0) + v_reward,
      task_wheel_draws = COALESCE(task_wheel_draws, 0) + 1
  WHERE id = v_user_id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  ) VALUES (
    v_user_id, v_reward, 'coin', 'task_checkin', v_user_id
  );

  RETURN json_build_object(
    'success', true,
    'streak_day', v_next_day,
    'consecutive_days', (
      SELECT consecutive_days FROM public.task_checkins WHERE user_id = v_user_id
    ),
    'reward', v_reward,
    'checked_today', true
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- get_task_center_summary
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_task_center_summary()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_streak integer := 0;
  v_consec integer := 0;
  v_last date;
  v_draws integer := 0;
  v_checked boolean := false;
  v_spins json;
  v_today date := (now() AT TIME ZONE 'UTC')::date;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT COALESCE(task_wheel_draws, 0) INTO v_draws
  FROM public.users WHERE id = v_user_id;

  SELECT streak_day, consecutive_days, last_checkin_date
  INTO v_streak, v_consec, v_last
  FROM public.task_checkins WHERE user_id = v_user_id;

  v_streak := COALESCE(v_streak, 0);
  v_consec := COALESCE(v_consec, 0);
  v_checked := (v_last = v_today);

  -- If streak broke (missed yesterday and not today), surface day 0 for UI until they check in
  IF v_last IS NOT NULL AND v_last < v_today - 1 THEN
    v_streak := 0;
    v_consec := 0;
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.created_at DESC), '[]'::json)
  INTO v_spins
  FROM (
    SELECT id, reward_label, reward_coins, created_at
    FROM public.task_wheel_spins
    WHERE user_id = v_user_id
    ORDER BY created_at DESC
    LIMIT 30
  ) t;

  RETURN json_build_object(
    'success', true,
    'streak_day', v_streak,
    'consecutive_days', v_consec,
    'checked_today', v_checked,
    'wheel_draws', v_draws,
    'day_rewards', to_json(ARRAY[10, 10, 15, 20, 20, 30, 50]),
    'spins', v_spins
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- spin_task_wheel
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.spin_task_wheel()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_draws integer;
  v_roll integer;
  v_label text;
  v_coins integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT COALESCE(task_wheel_draws, 0) INTO v_draws
  FROM public.users WHERE id = v_user_id FOR UPDATE;

  IF v_draws <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No draws remaining');
  END IF;

  v_roll := 1 + floor(random() * 8)::integer;
  CASE v_roll
    WHEN 1 THEN v_label := '10'; v_coins := 10;
    WHEN 2 THEN v_label := '100'; v_coins := 100;
    WHEN 3 THEN v_label := '500'; v_coins := 500;
    WHEN 4 THEN v_label := '1K'; v_coins := 1000;
    WHEN 5 THEN v_label := '10K'; v_coins := 10000;
    WHEN 6 THEN v_label := '50K'; v_coins := 50000;
    WHEN 7 THEN v_label := 'Badge'; v_coins := 20;
    ELSE v_label := 'Frame'; v_coins := 30;
  END CASE;

  UPDATE public.users
  SET task_wheel_draws = task_wheel_draws - 1,
      coins = COALESCE(coins, 0) + v_coins
  WHERE id = v_user_id;

  INSERT INTO public.task_wheel_spins (user_id, reward_label, reward_coins)
  VALUES (v_user_id, v_label, v_coins);

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  ) VALUES (
    v_user_id, v_coins, 'coin', 'task_wheel', v_user_id
  );

  RETURN json_build_object(
    'success', true,
    'label', v_label,
    'reward_coins', v_coins,
    'wheel_draws', (SELECT task_wheel_draws FROM public.users WHERE id = v_user_id)
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.task_daily_checkin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_task_center_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.spin_task_wheel() TO authenticated;
