CREATE OR REPLACE FUNCTION public.purchase_vip(
    p_user_id UUID,
    p_plan_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_price BIGINT;
    v_duration INT;
    v_level INT;
    v_current_coins BIGINT;
    v_current_vip_until TIMESTAMPTZ;
    v_new_vip_until TIMESTAMPTZ;
BEGIN
    -- 1. Get plan details
    SELECT price_coins, duration_days, level INTO v_price, v_duration, v_level
    FROM public.vip_plans WHERE id = p_plan_id;

    IF v_price IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Plan not found');
    END IF;

    -- 2. Get user current status
    SELECT coins, vip_until INTO v_current_coins, v_current_vip_until
    FROM public.users WHERE id = p_user_id FOR UPDATE;

    IF v_current_coins < v_price THEN
        RETURN json_build_object('success', false, 'message', 'Insufficient coins');
    END IF;

    -- 3. Calculate new expiry (Stacking logic)
    IF v_current_vip_until IS NOT NULL AND v_current_vip_until > NOW() THEN
        -- If already active, add to existing time
        v_new_vip_until := v_current_vip_until + (v_duration || ' days')::INTERVAL;
    ELSE
        -- If expired or none, start from now
        v_new_vip_until := NOW() + (v_duration || ' days')::INTERVAL;
    END IF;

    -- 4. Update user
    UPDATE public.users SET
        coins = coins - v_price,
        vip_level = v_level,
        vip_until = v_new_vip_until
    WHERE id = p_user_id;

    -- 5. Log transaction
    INSERT INTO public.transactions (user_id, amount, transaction_type, currency_type, description)
    VALUES (p_user_id, v_price, 'purchase', 'coin', 'Purchase VIP Level ' || v_level);

    -- 6. Provision VIP Assets (syncs inventory expiry to vip_until; see migration 20250610250000)
    PERFORM public.provision_user_assets(p_user_id);

    RETURN json_build_object(
        'success', true,
        'new_vip_level', v_level,
        'new_vip_until', v_new_vip_until
    );
END;
$$;
