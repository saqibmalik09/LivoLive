-- Prevent double agency salary cash credit when overlapping crons/manual runs race.
-- 1) Serialize with advisory lock
-- 2) Claim settlement row before crediting cash (RETURNING only when newly paid)
-- 3) Log salary_payout tx (allowed enum) instead of agency_period_salary

CREATE OR REPLACE FUNCTION public.execute_agency_period_payout(p_period_id text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  r record;
  v_matched public.agency_salary_level_configs%ROWTYPE;
  v_total_charm bigint;
  v_paid int := 0;
  v_charm_usd numeric;
  v_agent_usd numeric;
  v_sum numeric;
  v_owner uuid;
  v_credited numeric;
BEGIN
  PERFORM pg_advisory_xact_lock(87201401, hashtext(COALESCE(p_period_id, '')));

  FOR r IN SELECT id, owner_id FROM public.agencies WHERE is_active = true AND owner_id IS NOT NULL
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.agency_period_settlements
      WHERE agency_id = r.id AND period_id = p_period_id AND status = 'paid'
    ) THEN
      CONTINUE;
    END IF;

    SELECT COALESCE(SUM(hps.charm_points), 0) INTO v_total_charm
    FROM public.agency_members am
    JOIN public.host_period_stats hps ON hps.user_id = am.user_id AND hps.period_id = p_period_id
    WHERE am.agency_id = r.id;

    SELECT * INTO v_matched FROM public.match_agency_salary_level(v_total_charm);
    v_charm_usd := COALESCE(v_matched.charm_salary_usd, 0);
    v_agent_usd := COALESCE(v_matched.agent_salary_usd, 0);
    v_sum := v_charm_usd + v_agent_usd;

    IF v_sum <= 0 THEN
      CONTINUE;
    END IF;

    INSERT INTO public.agency_period_settlements (
      agency_id, period_id, total_charm, achieved_level,
      charm_salary_usd, agent_salary_usd, total_usd, owner_user_id, status, paid_at
    ) VALUES (
      r.id, p_period_id, v_total_charm, COALESCE(v_matched.level, 0),
      v_charm_usd, v_agent_usd, v_sum, r.owner_id, 'paid', now()
    )
    ON CONFLICT (agency_id, period_id) DO UPDATE SET
      total_charm = EXCLUDED.total_charm,
      achieved_level = EXCLUDED.achieved_level,
      charm_salary_usd = EXCLUDED.charm_salary_usd,
      agent_salary_usd = EXCLUDED.agent_salary_usd,
      total_usd = EXCLUDED.total_usd,
      owner_user_id = EXCLUDED.owner_user_id,
      status = 'paid',
      paid_at = now()
    WHERE public.agency_period_settlements.status IS DISTINCT FROM 'paid'
    RETURNING owner_user_id, total_usd INTO v_owner, v_credited;

    IF v_owner IS NULL THEN
      CONTINUE;
    END IF;

    UPDATE public.users
    SET cash_balance = COALESCE(cash_balance, 0) + v_credited
    WHERE id = v_owner;

    BEGIN
      INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, description)
      VALUES (
        v_owner,
        GREATEST(1, ROUND(v_credited)::bigint),
        'cash',
        'salary_payout',
        format('Agency period salary $%s for %s', v_credited, p_period_id)
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    v_paid := v_paid + 1;
  END LOOP;

  RETURN json_build_object('success', true, 'period_id', p_period_id, 'agencies_paid', v_paid);
END;
$function$;

-- Overlapping crons caused double credit (period-a/b + daily-check same second).
-- Keep daily-check only; it already pays on local day 1 / 16.
DO $$
BEGIN
  PERFORM cron.unschedule('agency-payout-period-b');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  PERFORM cron.unschedule('agency-payout-period-a');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
