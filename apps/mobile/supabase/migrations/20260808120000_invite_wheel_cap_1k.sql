-- Cap invite lucky-wheel rewards at 1000 coins (same bands as task wheel).
-- Reuses public._pick_task_wheel_reward(); keeps a small "AGAIN" redraw chance.

CREATE OR REPLACE FUNCTION public.spin_invite_wheel()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_draws integer;
  v_label text;
  v_coins integer := 0;
  v_pick record;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT COALESCE(invite_wheel_draws, 0) INTO v_draws
  FROM public.users WHERE id = v_user_id FOR UPDATE;

  IF v_draws <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'No draws remaining');
  END IF;

  -- ~12.5% AGAIN (same share as old 1-of-8 slot); otherwise task-wheel tiers (max 1K).
  IF random() < 0.125 THEN
    v_label := 'AGAIN';
    v_coins := 0;
  ELSE
    SELECT p.out_label, p.out_coins
    INTO v_pick
    FROM public._pick_task_wheel_reward() p
    LIMIT 1;

    v_label := COALESCE(v_pick.out_label, '100-300');
    v_coins := LEAST(GREATEST(COALESCE(v_pick.out_coins, 100), 0), 1000);
  END IF;

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

GRANT EXECUTE ON FUNCTION public.spin_invite_wheel() TO authenticated;
