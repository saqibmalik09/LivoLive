-- Invite & Earn: referral linking, milestones, wheel draws, coin credits.

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
      'invite_recharge_bonus'::text
    ]));
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'transactions check constraint update skipped: %', SQLERRM;
END $$;

-- ---------------------------------------------------------------------------
-- Users columns
-- ---------------------------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS referred_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS invite_accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS invite_wheel_draws integer NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_users_referred_by ON public.users (referred_by)
  WHERE referred_by IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Referral ledger
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invite_referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inviter_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invite_code text NOT NULL,
  register_bonus_coins integer NOT NULL DEFAULT 0,
  wheel_draws_awarded integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (invitee_id)
);

CREATE INDEX IF NOT EXISTS idx_invite_referrals_inviter_created
  ON public.invite_referrals (inviter_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.invite_milestone_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invites_needed integer NOT NULL CHECK (invites_needed > 0),
  reward_coins integer NOT NULL CHECK (reward_coins > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, invites_needed)
);

CREATE TABLE IF NOT EXISTS public.invite_wheel_spins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  reward_label text NOT NULL,
  reward_coins integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invite_wheel_spins_user
  ON public.invite_wheel_spins (user_id, created_at DESC);

ALTER TABLE public.invite_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invite_milestone_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invite_wheel_spins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS invite_referrals_select_own ON public.invite_referrals;
CREATE POLICY invite_referrals_select_own ON public.invite_referrals
  FOR SELECT TO authenticated
  USING (inviter_id = auth.uid() OR invitee_id = auth.uid());

DROP POLICY IF EXISTS invite_milestone_claims_select_own ON public.invite_milestone_claims;
CREATE POLICY invite_milestone_claims_select_own ON public.invite_milestone_claims
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS invite_wheel_spins_select_own ON public.invite_wheel_spins;
CREATE POLICY invite_wheel_spins_select_own ON public.invite_wheel_spins
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

GRANT SELECT ON public.invite_referrals TO authenticated;
GRANT SELECT ON public.invite_milestone_claims TO authenticated;
GRANT SELECT ON public.invite_wheel_spins TO authenticated;

-- ---------------------------------------------------------------------------
-- accept_invite_code: bind invitee → inviter once (call after profile setup)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_invite_code(p_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_inviter public.users%ROWTYPE;
  v_me public.users%ROWTYPE;
  v_code text := trim(COALESCE(p_code, ''));
  v_register_bonus integer := 100;
  v_welcome_bonus integer := 50;
  v_draws integer := 0;
  v_week_start timestamptz := date_trunc('week', now() AT TIME ZONE 'UTC');
  v_week_invites integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF v_code = '' OR v_code !~ '^[0-9]+$' THEN
    RETURN json_build_object('success', false, 'message', 'Invalid invitation code');
  END IF;

  SELECT * INTO v_me FROM public.users WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Profile not found');
  END IF;

  IF v_me.referred_by IS NOT NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invite already applied');
  END IF;

  SELECT * INTO v_inviter
  FROM public.users
  WHERE short_id = v_code::integer
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Invitation code not found');
  END IF;

  IF v_inviter.id = v_user_id THEN
    RETURN json_build_object('success', false, 'message', 'You cannot use your own code');
  END IF;

  -- Weekly wheel draw cap: first 10 invites this week give +2 draws each
  SELECT COUNT(*)::integer INTO v_week_invites
  FROM public.invite_referrals
  WHERE inviter_id = v_inviter.id
    AND created_at >= v_week_start;

  IF v_week_invites < 10 THEN
    v_draws := 2;
  END IF;

  UPDATE public.users
  SET referred_by = v_inviter.id,
      invite_accepted_at = now()
  WHERE id = v_user_id;

  INSERT INTO public.invite_referrals (
    inviter_id, invitee_id, invite_code, register_bonus_coins, wheel_draws_awarded
  ) VALUES (
    v_inviter.id, v_user_id, v_code, v_register_bonus, v_draws
  );

  -- Inviter: registration bonus
  UPDATE public.users
  SET coins = COALESCE(coins, 0) + v_register_bonus,
      invite_wheel_draws = COALESCE(invite_wheel_draws, 0) + v_draws
  WHERE id = v_inviter.id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  ) VALUES (
    v_inviter.id, v_register_bonus, 'coin', 'invite_register_bonus', v_user_id
  );

  -- Invitee: small welcome bonus
  UPDATE public.users
  SET coins = COALESCE(coins, 0) + v_welcome_bonus
  WHERE id = v_user_id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  ) VALUES (
    v_user_id, v_welcome_bonus, 'coin', 'invite_welcome_bonus', v_inviter.id
  );

  RETURN json_build_object(
    'success', true,
    'message', 'Invitation applied',
    'inviter_id', v_inviter.id,
    'register_bonus', v_register_bonus,
    'welcome_bonus', v_welcome_bonus,
    'wheel_draws_awarded', v_draws
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- get_invite_earn_summary
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_invite_earn_summary()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_short_id integer;
  v_draws integer;
  v_total integer;
  v_week integer;
  v_week_start timestamptz := date_trunc('week', now() AT TIME ZONE 'UTC');
  v_claimed int[];
  v_records json;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT short_id, COALESCE(invite_wheel_draws, 0)
  INTO v_short_id, v_draws
  FROM public.users WHERE id = v_user_id;

  SELECT COUNT(*)::integer INTO v_total
  FROM public.invite_referrals WHERE inviter_id = v_user_id;

  SELECT COUNT(*)::integer INTO v_week
  FROM public.invite_referrals
  WHERE inviter_id = v_user_id AND created_at >= v_week_start;

  SELECT COALESCE(array_agg(invites_needed ORDER BY invites_needed), ARRAY[]::int[])
  INTO v_claimed
  FROM public.invite_milestone_claims
  WHERE user_id = v_user_id;

  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.created_at DESC), '[]'::json)
  INTO v_records
  FROM (
    SELECT
      r.id,
      r.invitee_id,
      r.created_at,
      r.register_bonus_coins,
      u.username,
      u.avatar_url,
      u.short_id
    FROM public.invite_referrals r
    JOIN public.users u ON u.id = r.invitee_id
    WHERE r.inviter_id = v_user_id
    ORDER BY r.created_at DESC
    LIMIT 50
  ) t;

  RETURN json_build_object(
    'success', true,
    'short_id', v_short_id,
    'wheel_draws', v_draws,
    'total_invites', v_total,
    'week_invites', v_week,
    'claimed_milestones', to_json(v_claimed),
    'records', v_records
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- claim_invite_milestone
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_invite_milestone(p_invites_needed integer)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_total integer;
  v_reward integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  v_reward := CASE p_invites_needed
    WHEN 1 THEN 500
    WHEN 3 THEN 1000
    WHEN 5 THEN 3000
    WHEN 10 THEN 8000
    WHEN 20 THEN 20000
    WHEN 50 THEN 50000
    WHEN 100 THEN 100000
    WHEN 200 THEN 500000
    ELSE NULL
  END;

  IF v_reward IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid milestone');
  END IF;

  SELECT COUNT(*)::integer INTO v_total
  FROM public.invite_referrals WHERE inviter_id = v_user_id;

  IF v_total < p_invites_needed THEN
    RETURN json_build_object('success', false, 'message', 'Not enough invites yet');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.invite_milestone_claims
    WHERE user_id = v_user_id AND invites_needed = p_invites_needed
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Milestone already claimed');
  END IF;

  INSERT INTO public.invite_milestone_claims (user_id, invites_needed, reward_coins)
  VALUES (v_user_id, p_invites_needed, v_reward);

  UPDATE public.users
  SET coins = COALESCE(coins, 0) + v_reward
  WHERE id = v_user_id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  ) VALUES (
    v_user_id, v_reward, 'coin', 'invite_milestone', v_user_id
  );

  RETURN json_build_object(
    'success', true,
    'reward_coins', v_reward,
    'invites_needed', p_invites_needed
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- spin_invite_wheel
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.spin_invite_wheel()
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

  SELECT COALESCE(invite_wheel_draws, 0) INTO v_draws
  FROM public.users WHERE id = v_user_id FOR UPDATE;

  IF v_draws <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No draws remaining');
  END IF;

  v_roll := 1 + floor(random() * 8)::integer;
  CASE v_roll
    WHEN 1 THEN v_label := '100'; v_coins := 100;
    WHEN 2 THEN v_label := '500'; v_coins := 500;
    WHEN 3 THEN v_label := '1K'; v_coins := 1000;
    WHEN 4 THEN v_label := '5K'; v_coins := 5000;
    WHEN 5 THEN v_label := '10K'; v_coins := 10000;
    WHEN 6 THEN v_label := '50K'; v_coins := 50000;
    WHEN 7 THEN v_label := '1M'; v_coins := 1000000;
    ELSE v_label := 'AGAIN'; v_coins := 0;
  END CASE;

  UPDATE public.users
  SET invite_wheel_draws = invite_wheel_draws - 1,
      coins = COALESCE(coins, 0) + v_coins
  WHERE id = v_user_id;

  IF v_label = 'AGAIN' THEN
    UPDATE public.users
    SET invite_wheel_draws = invite_wheel_draws + 1
    WHERE id = v_user_id;
  END IF;

  INSERT INTO public.invite_wheel_spins (user_id, reward_label, reward_coins)
  VALUES (v_user_id, v_label, v_coins);

  IF v_coins > 0 THEN
    INSERT INTO public.transactions (
      user_id, amount, currency_type, transaction_type, reference_id
    ) VALUES (
      v_user_id, v_coins, 'coin', 'invite_wheel', v_user_id
    );
  END IF;

  RETURN json_build_object(
    'success', true,
    'label', v_label,
    'reward_coins', v_coins,
    'wheel_draws', (SELECT invite_wheel_draws FROM public.users WHERE id = v_user_id)
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- apply_invite_recharge_bonus: call from recharge success path
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.apply_invite_recharge_bonus(
  p_invitee_id uuid,
  p_recharge_coins integer
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_inviter_id uuid;
  v_bonus integer;
  v_is_first boolean;
  v_rate numeric;
  v_caller uuid := auth.uid();
BEGIN
  IF p_invitee_id IS NULL OR COALESCE(p_recharge_coins, 0) <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'Invalid recharge');
  END IF;

  -- Caller must be the invitee (client IAP path) or service role (auth.uid null).
  IF v_caller IS NOT NULL AND v_caller <> p_invitee_id THEN
    RETURN json_build_object('success', false, 'message', 'Forbidden');
  END IF;

  SELECT referred_by INTO v_inviter_id
  FROM public.users WHERE id = p_invitee_id;

  IF v_inviter_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'No inviter');
  END IF;

  SELECT NOT EXISTS (
    SELECT 1 FROM public.transactions
    WHERE user_id = v_inviter_id
      AND transaction_type = 'invite_first_recharge'
      AND reference_id = p_invitee_id
  ) INTO v_is_first;

  IF v_is_first THEN
    v_rate := 0.03;
  ELSE
    v_rate := 0.01;
  END IF;

  v_bonus := GREATEST(1, floor(p_recharge_coins * v_rate)::integer);

  UPDATE public.users
  SET coins = COALESCE(coins, 0) + v_bonus
  WHERE id = v_inviter_id;

  INSERT INTO public.transactions (
    user_id, amount, currency_type, transaction_type, reference_id
  ) VALUES (
    v_inviter_id,
    v_bonus,
    'coin',
    CASE WHEN v_is_first THEN 'invite_first_recharge' ELSE 'invite_recharge_bonus' END,
    p_invitee_id
  );

  RETURN json_build_object(
    'success', true,
    'bonus', v_bonus,
    'is_first', v_is_first,
    'inviter_id', v_inviter_id
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.accept_invite_code(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_invite_earn_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_invite_milestone(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.spin_invite_wheel() TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_invite_recharge_bonus(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_invite_recharge_bonus(uuid, integer) TO service_role;
