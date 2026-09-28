-- Salary calculation and payout RPCs

CREATE OR REPLACE FUNCTION public.preview_salary_period(p_period_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_cfg record;
    v_host record;
    v_tier record;
    v_stats record;
    v_base int;
    v_diamonds int;
    v_qualified int := 0;
    v_total_host int := 0;
    v_total_chain int := 0;
    v_lines jsonb := '[]'::jsonb;
    v_agency_owner uuid;
    v_sponsor uuid;
    v_bd_user uuid;
    v_bd_admin_user uuid;
    v_super_bd_user uuid;
    rec record;
BEGIN
    SELECT * INTO v_cfg FROM public.salary_chain_configs WHERE id = 1;
    PERFORM public.ensure_salary_period(p_period_id);

    FOR v_host IN
        SELECT am.user_id AS host_id, am.agency_id, a.owner_id, a.sponsor_staff_id
        FROM public.agency_members am
        JOIN public.agencies a ON a.id = am.agency_id AND a.is_active = true
    LOOP
        SELECT * INTO v_stats FROM public.host_period_stats
        WHERE user_id = v_host.host_id AND period_id = p_period_id;

        IF v_stats.user_id IS NULL THEN
            CONTINUE;
        END IF;

        SELECT * INTO v_tier
        FROM public.salary_tiers
        WHERE is_active = true
          AND diamonds_target <= COALESCE(v_stats.total_diamonds, 0)
          AND hours_target <= (COALESCE(v_stats.total_on_mic_seconds, 0) / 3600)
          AND days_target <= COALESCE(v_stats.valid_days, 0)
        ORDER BY diamonds_target DESC, hours_target DESC, days_target DESC
        LIMIT 1;

        IF v_tier.id IS NULL THEN
            CONTINUE;
        END IF;

        v_qualified := v_qualified + 1;
        v_base := v_tier.reward_amount * COALESCE(v_cfg.diamonds_per_dollar, 1000);
        v_total_host := v_total_host + v_base;

        v_lines := v_lines || jsonb_build_array(jsonb_build_object(
            'role', 'host', 'user_id', v_host.host_id, 'amount', v_base, 'tier', v_tier.tier_name
        ));

        v_agency_owner := v_host.owner_id;
        IF v_agency_owner IS NOT NULL THEN
            v_diamonds := (v_base * COALESCE(v_cfg.agency_salary_pc, 10)) / 100;
            v_total_chain := v_total_chain + v_diamonds;
            v_lines := v_lines || jsonb_build_array(jsonb_build_object(
                'role', 'agency', 'user_id', v_agency_owner, 'amount', v_diamonds, 'source_host_id', v_host.host_id
            ));
        END IF;

        v_bd_user := NULL;
        v_bd_admin_user := NULL;
        v_super_bd_user := NULL;
        v_sponsor := v_host.sponsor_staff_id;

        IF v_sponsor IS NOT NULL THEN
            FOR rec IN
                WITH RECURSIVE chain AS (
                    SELECT id, user_id, role, parent_staff_id
                    FROM public.business_staff
                    WHERE id = v_sponsor AND is_active = true
                    UNION ALL
                    SELECT bs.id, bs.user_id, bs.role, bs.parent_staff_id
                    FROM public.business_staff bs
                    INNER JOIN chain c ON bs.id = c.parent_staff_id
                    WHERE bs.is_active = true
                )
                SELECT * FROM chain
            LOOP
                IF rec.role = 'bd' AND v_bd_user IS NULL THEN v_bd_user := rec.user_id;
                ELSIF rec.role = 'bd_admin' AND v_bd_admin_user IS NULL THEN v_bd_admin_user := rec.user_id;
                ELSIF rec.role = 'super_bd' AND v_super_bd_user IS NULL THEN v_super_bd_user := rec.user_id;
                END IF;
            END LOOP;
        END IF;

        IF v_bd_user IS NOT NULL THEN
            v_diamonds := (v_base * COALESCE(v_cfg.bd_salary_pc, 5)) / 100;
            v_total_chain := v_total_chain + v_diamonds;
            v_lines := v_lines || jsonb_build_array(jsonb_build_object(
                'role', 'bd', 'user_id', v_bd_user, 'amount', v_diamonds, 'source_host_id', v_host.host_id
            ));
        END IF;
        IF v_bd_admin_user IS NOT NULL THEN
            v_diamonds := (v_base * COALESCE(v_cfg.bd_admin_salary_pc, 3)) / 100;
            v_total_chain := v_total_chain + v_diamonds;
            v_lines := v_lines || jsonb_build_array(jsonb_build_object(
                'role', 'bd_admin', 'user_id', v_bd_admin_user, 'amount', v_diamonds, 'source_host_id', v_host.host_id
            ));
        END IF;
        IF v_super_bd_user IS NOT NULL THEN
            v_diamonds := (v_base * COALESCE(v_cfg.super_bd_salary_pc, 2)) / 100;
            v_total_chain := v_total_chain + v_diamonds;
            v_lines := v_lines || jsonb_build_array(jsonb_build_object(
                'role', 'super_bd', 'user_id', v_super_bd_user, 'amount', v_diamonds, 'source_host_id', v_host.host_id
            ));
        END IF;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'period_id', p_period_id,
        'qualified_hosts', v_qualified,
        'total_host_diamonds', v_total_host,
        'total_chain_diamonds', v_total_chain,
        'grand_total', v_total_host + v_total_chain,
        'lines', v_lines
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.calculate_salary_period(p_period_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_period record;
    v_cfg record;
    v_host record;
    v_tier record;
    v_stats record;
    v_base int;
    v_override int;
    v_agency_owner uuid;
    v_sponsor uuid;
    v_bd_user uuid;
    v_bd_admin_user uuid;
    v_super_bd_user uuid;
    rec record;
    v_count int := 0;
BEGIN
    PERFORM public.ensure_salary_period(p_period_id);

    SELECT * INTO v_period FROM public.salary_periods WHERE period_id = p_period_id FOR UPDATE;
    IF v_period.status NOT IN ('open', 'calculated') THEN
        RETURN json_build_object('success', false, 'message', 'Period not open for calculation');
    END IF;

    DELETE FROM public.host_salary_payouts WHERE period_id = p_period_id AND status = 'pending';

    SELECT * INTO v_cfg FROM public.salary_chain_configs WHERE id = 1;

    FOR v_host IN
        SELECT am.user_id AS host_id, am.agency_id, a.owner_id, a.sponsor_staff_id
        FROM public.agency_members am
        JOIN public.agencies a ON a.id = am.agency_id AND a.is_active = true
    LOOP
        SELECT * INTO v_stats FROM public.host_period_stats
        WHERE user_id = v_host.host_id AND period_id = p_period_id;

        IF v_stats.user_id IS NULL THEN CONTINUE; END IF;

        SELECT * INTO v_tier
        FROM public.salary_tiers
        WHERE is_active = true
          AND diamonds_target <= COALESCE(v_stats.total_diamonds, 0)
          AND hours_target <= (COALESCE(v_stats.total_on_mic_seconds, 0) / 3600)
          AND days_target <= COALESCE(v_stats.valid_days, 0)
        ORDER BY diamonds_target DESC, hours_target DESC, days_target DESC
        LIMIT 1;

        IF v_tier.id IS NULL THEN CONTINUE; END IF;

        v_base := v_tier.reward_amount * COALESCE(v_cfg.diamonds_per_dollar, 1000);

        INSERT INTO public.host_salary_payouts (
            period_id, beneficiary_user_id, beneficiary_role, source_host_id, tier_id,
            base_amount, override_amount, total_amount, stats_snapshot, status
        )
        VALUES (
            p_period_id, v_host.host_id, 'host', v_host.host_id, v_tier.id,
            v_base, 0, v_base,
            jsonb_build_object(
                'diamonds', v_stats.total_diamonds,
                'hours', v_stats.total_on_mic_seconds / 3600,
                'valid_days', v_stats.valid_days,
                'tier_name', v_tier.tier_name
            ),
            'pending'
        )
        ON CONFLICT (period_id, beneficiary_user_id, beneficiary_role, source_host_id)
        DO UPDATE SET
            tier_id = EXCLUDED.tier_id,
            base_amount = EXCLUDED.base_amount,
            total_amount = EXCLUDED.total_amount,
            stats_snapshot = EXCLUDED.stats_snapshot,
            status = 'pending';
        v_count := v_count + 1;

        v_agency_owner := v_host.owner_id;
        IF v_agency_owner IS NOT NULL THEN
            v_override := (v_base * COALESCE(v_cfg.agency_salary_pc, 10)) / 100;
            INSERT INTO public.host_salary_payouts (
                period_id, beneficiary_user_id, beneficiary_role, source_host_id,
                base_amount, override_amount, total_amount, status
            )
            VALUES (
                p_period_id, v_agency_owner, 'agency', v_host.host_id,
                v_base, v_override, v_override, 'pending'
            )
            ON CONFLICT (period_id, beneficiary_user_id, beneficiary_role, source_host_id)
            DO UPDATE SET total_amount = EXCLUDED.total_amount, override_amount = EXCLUDED.override_amount, status = 'pending';
        END IF;

        v_bd_user := NULL;
        v_bd_admin_user := NULL;
        v_super_bd_user := NULL;
        IF v_host.sponsor_staff_id IS NOT NULL THEN
            FOR rec IN
                WITH RECURSIVE chain AS (
                    SELECT id, user_id, role, parent_staff_id
                    FROM public.business_staff
                    WHERE id = v_host.sponsor_staff_id AND is_active = true
                    UNION ALL
                    SELECT bs.id, bs.user_id, bs.role, bs.parent_staff_id
                    FROM public.business_staff bs
                    INNER JOIN chain c ON bs.id = c.parent_staff_id
                    WHERE bs.is_active = true
                )
                SELECT * FROM chain
            LOOP
                IF rec.role = 'bd' AND v_bd_user IS NULL THEN v_bd_user := rec.user_id;
                ELSIF rec.role = 'bd_admin' AND v_bd_admin_user IS NULL THEN v_bd_admin_user := rec.user_id;
                ELSIF rec.role = 'super_bd' AND v_super_bd_user IS NULL THEN v_super_bd_user := rec.user_id;
                END IF;
            END LOOP;
        END IF;

        IF v_bd_user IS NOT NULL THEN
            v_override := (v_base * COALESCE(v_cfg.bd_salary_pc, 5)) / 100;
            INSERT INTO public.host_salary_payouts (
                period_id, beneficiary_user_id, beneficiary_role, source_host_id,
                base_amount, override_amount, total_amount, status
            )
            VALUES (p_period_id, v_bd_user, 'bd', v_host.host_id, v_base, v_override, v_override, 'pending')
            ON CONFLICT (period_id, beneficiary_user_id, beneficiary_role, source_host_id)
            DO UPDATE SET total_amount = EXCLUDED.total_amount, status = 'pending';
        END IF;
        IF v_bd_admin_user IS NOT NULL THEN
            v_override := (v_base * COALESCE(v_cfg.bd_admin_salary_pc, 3)) / 100;
            INSERT INTO public.host_salary_payouts (
                period_id, beneficiary_user_id, beneficiary_role, source_host_id,
                base_amount, override_amount, total_amount, status
            )
            VALUES (p_period_id, v_bd_admin_user, 'bd_admin', v_host.host_id, v_base, v_override, v_override, 'pending')
            ON CONFLICT (period_id, beneficiary_user_id, beneficiary_role, source_host_id)
            DO UPDATE SET total_amount = EXCLUDED.total_amount, status = 'pending';
        END IF;
        IF v_super_bd_user IS NOT NULL THEN
            v_override := (v_base * COALESCE(v_cfg.super_bd_salary_pc, 2)) / 100;
            INSERT INTO public.host_salary_payouts (
                period_id, beneficiary_user_id, beneficiary_role, source_host_id,
                base_amount, override_amount, total_amount, status
            )
            VALUES (p_period_id, v_super_bd_user, 'super_bd', v_host.host_id, v_base, v_override, v_override, 'pending')
            ON CONFLICT (period_id, beneficiary_user_id, beneficiary_role, source_host_id)
            DO UPDATE SET total_amount = EXCLUDED.total_amount, status = 'pending';
        END IF;
    END LOOP;

    UPDATE public.salary_periods
    SET status = 'calculated', calculated_at = now()
    WHERE period_id = p_period_id;

    RETURN json_build_object('success', true, 'period_id', p_period_id, 'qualified_hosts', v_count);
END;
$function$;

CREATE OR REPLACE FUNCTION public.execute_salary_payout_batch(p_period_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_row record;
    v_paid int := 0;
    v_withheld int := 0;
    v_total int := 0;
    v_banned boolean;
BEGIN
    PERFORM public.ensure_salary_period(p_period_id);

    FOR v_row IN
        SELECT * FROM public.host_salary_payouts
        WHERE period_id = p_period_id AND status = 'pending'
        FOR UPDATE
    LOOP
        SELECT is_banned INTO v_banned FROM public.users WHERE id = v_row.beneficiary_user_id;
        IF COALESCE(v_banned, false) THEN
            UPDATE public.host_salary_payouts SET status = 'withheld' WHERE id = v_row.id;
            v_withheld := v_withheld + 1;
            CONTINUE;
        END IF;

        IF v_row.total_amount > 0 THEN
            UPDATE public.users
            SET diamonds = diamonds + v_row.total_amount
            WHERE id = v_row.beneficiary_user_id;

            INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
            VALUES (v_row.beneficiary_user_id, v_row.total_amount, 'diamond', 'salary_payout', v_row.id);

            INSERT INTO public.system_notifications (user_id, title, content, type, icon_type)
            VALUES (
                v_row.beneficiary_user_id,
                'Salary Credited',
                format('You received %s diamonds for period %s (%s).',
                    v_row.total_amount, p_period_id, v_row.beneficiary_role),
                'salary', 'wallet'
            );
        END IF;

        UPDATE public.host_salary_payouts
        SET status = 'paid', paid_at = now()
        WHERE id = v_row.id;

        v_paid := v_paid + 1;
        v_total := v_total + v_row.total_amount;
    END LOOP;

    UPDATE public.salary_periods
    SET status = 'paid', paid_at = now()
    WHERE period_id = p_period_id;

    RETURN json_build_object(
        'success', true,
        'period_id', p_period_id,
        'rows_paid', v_paid,
        'rows_withheld', v_withheld,
        'total_diamonds', v_total
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.run_scheduled_salary_payout()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_today date := current_date;
    v_period_id text;
    v_bounds record;
    v_result json;
BEGIN
    IF extract(day FROM v_today) = 15 THEN
        v_period_id := public.get_period_id_for_date(v_today);
    ELSIF v_today = (date_trunc('month', v_today) + interval '1 month - 1 day')::date THEN
        v_period_id := public.get_period_id_for_date(v_today);
    ELSE
        RETURN json_build_object('success', false, 'message', 'Not a payout day');
    END IF;

    SELECT * INTO v_bounds FROM public.get_period_bounds(v_period_id);

    IF v_today < v_bounds.payout_date THEN
        RETURN json_build_object('success', false, 'message', 'Before payout date');
    END IF;

    PERFORM public.calculate_salary_period(v_period_id);
    SELECT public.execute_salary_payout_batch(v_period_id) INTO v_result;
    RETURN v_result;
END;
$function$;
