-- Agency salary policy:
--   calculate every member host's level independently, then sum host salaries.
-- Safety:
--   one canonical cron, a shared period lock, and settlement claim before cash.

CREATE OR REPLACE FUNCTION public.calculate_agency_period_salary_per_host(
  p_agency_id uuid,
  p_period_id text
)
RETURNS TABLE (
  total_charm bigint,
  achieved_level integer,
  charm_salary_usd numeric,
  agent_salary_usd numeric,
  total_usd numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $function$
  WITH member_salary AS (
    SELECT
      COALESCE(hps.charm_points, 0)::bigint AS host_charm,
      COALESCE(m.level, 0)::integer AS host_level,
      COALESCE(m.charm_salary_usd, 0)::numeric AS host_charm_usd,
      COALESCE(m.agent_salary_usd, 0)::numeric AS host_agent_usd
    FROM public.agency_members am
    LEFT JOIN public.host_period_stats hps
      ON hps.user_id = am.user_id
     AND hps.period_id = p_period_id
    LEFT JOIN LATERAL public.match_agency_salary_level(
      COALESCE(hps.charm_points, 0)::bigint
    ) m ON true
    WHERE am.agency_id = p_agency_id
  )
  SELECT
    COALESCE(SUM(host_charm), 0)::bigint,
    COALESCE(MAX(host_level), 0)::integer,
    COALESCE(SUM(host_charm_usd), 0)::numeric(12, 2),
    COALESCE(SUM(host_agent_usd), 0)::numeric(12, 2),
    COALESCE(SUM(host_charm_usd + host_agent_usd), 0)::numeric(12, 2)
  FROM member_salary;
$function$;

ALTER FUNCTION public.calculate_agency_period_salary_per_host(uuid, text)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.calculate_agency_period_salary_per_host(uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.calculate_agency_period_salary_per_host(uuid, text)
  TO service_role;

CREATE OR REPLACE FUNCTION public.execute_agency_period_payout(p_period_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $function$
DECLARE
  r record;
  v_calc record;
  v_paid integer := 0;
  v_owner uuid;
  v_credited numeric;
BEGIN
  IF p_period_id IS NULL
     OR p_period_id !~ '^\d{4}-\d{2}-(A|B)$' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid period; expected YYYY-MM-A or YYYY-MM-B'
    );
  END IF;

  -- Shared by bulk, manual single-agency, and cron payouts.
  PERFORM pg_advisory_xact_lock(
    87201401,
    hashtext(p_period_id)
  );

  FOR r IN
    SELECT id, owner_id
    FROM public.agencies
    WHERE is_active = true
      AND owner_id IS NOT NULL
    ORDER BY id
  LOOP
    IF EXISTS (
      SELECT 1
      FROM public.agency_period_settlements
      WHERE agency_id = r.id
        AND period_id = p_period_id
        AND status = 'paid'
    ) THEN
      CONTINUE;
    END IF;

    SELECT *
    INTO v_calc
    FROM public.calculate_agency_period_salary_per_host(r.id, p_period_id);

    IF COALESCE(v_calc.total_usd, 0) <= 0 THEN
      CONTINUE;
    END IF;

    v_owner := NULL;
    v_credited := NULL;

    -- This row is the idempotency claim. Cash is credited only if this
    -- statement inserted/transitioned the settlement to paid.
    INSERT INTO public.agency_period_settlements (
      agency_id,
      period_id,
      total_charm,
      achieved_level,
      charm_salary_usd,
      agent_salary_usd,
      total_usd,
      owner_user_id,
      status,
      paid_at
    ) VALUES (
      r.id,
      p_period_id,
      v_calc.total_charm,
      v_calc.achieved_level,
      v_calc.charm_salary_usd,
      v_calc.agent_salary_usd,
      v_calc.total_usd,
      r.owner_id,
      'paid',
      now()
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
    RETURNING owner_user_id, total_usd
    INTO v_owner, v_credited;

    IF v_owner IS NULL THEN
      CONTINUE;
    END IF;

    UPDATE public.users
    SET cash_balance = COALESCE(cash_balance, 0) + v_credited
    WHERE id = v_owner;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Agency owner % no longer exists', v_owner;
    END IF;

    INSERT INTO public.transactions (
      user_id,
      amount,
      currency_type,
      transaction_type,
      reference_id,
      description
    ) VALUES (
      v_owner,
      GREATEST(1, ROUND(v_credited)::bigint),
      'cash',
      'salary_payout',
      r.id,
      format(
        'Agency per-host period salary $%s for %s',
        v_credited,
        p_period_id
      )
    );

    v_paid := v_paid + 1;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'period_id', p_period_id,
    'calculation', 'per_host_level_sum',
    'agencies_paid', v_paid
  );
END;
$function$;

ALTER FUNCTION public.execute_agency_period_payout(text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.execute_agency_period_payout(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.execute_agency_period_payout(text)
  TO service_role;

CREATE OR REPLACE FUNCTION public.execute_one_agency_period_payout(
  p_period_id text,
  p_agency_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
SET row_security TO off
AS $function$
DECLARE
  r record;
  v_calc record;
  v_owner uuid;
  v_credited numeric;
BEGIN
  IF p_period_id IS NULL
     OR p_period_id !~ '^\d{4}-\d{2}-(A|B)$' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid period; expected YYYY-MM-A or YYYY-MM-B'
    );
  END IF;

  IF p_agency_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'agency_id required'
    );
  END IF;

  -- Same lock as the bulk/cron function prevents cross-path races.
  PERFORM pg_advisory_xact_lock(
    87201401,
    hashtext(p_period_id)
  );

  SELECT id, owner_id
  INTO r
  FROM public.agencies
  WHERE id = p_agency_id
    AND is_active = true
    AND owner_id IS NOT NULL;

  IF r.id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Agency not found or inactive'
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.agency_period_settlements
    WHERE agency_id = r.id
      AND period_id = p_period_id
      AND status = 'paid'
  ) THEN
    RETURN json_build_object(
      'success', true,
      'already_paid', true,
      'period_id', p_period_id,
      'agency_id', p_agency_id
    );
  END IF;

  SELECT *
  INTO v_calc
  FROM public.calculate_agency_period_salary_per_host(r.id, p_period_id);

  IF COALESCE(v_calc.total_usd, 0) <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'No payable agency salary for this period'
    );
  END IF;

  INSERT INTO public.agency_period_settlements (
    agency_id,
    period_id,
    total_charm,
    achieved_level,
    charm_salary_usd,
    agent_salary_usd,
    total_usd,
    owner_user_id,
    status,
    paid_at
  ) VALUES (
    r.id,
    p_period_id,
    v_calc.total_charm,
    v_calc.achieved_level,
    v_calc.charm_salary_usd,
    v_calc.agent_salary_usd,
    v_calc.total_usd,
    r.owner_id,
    'paid',
    now()
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
  RETURNING owner_user_id, total_usd
  INTO v_owner, v_credited;

  IF v_owner IS NULL THEN
    RETURN json_build_object(
      'success', true,
      'already_paid', true,
      'period_id', p_period_id,
      'agency_id', p_agency_id
    );
  END IF;

  UPDATE public.users
  SET cash_balance = COALESCE(cash_balance, 0) + v_credited
  WHERE id = v_owner;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Agency owner % no longer exists', v_owner;
  END IF;

  INSERT INTO public.transactions (
    user_id,
    amount,
    currency_type,
    transaction_type,
    reference_id,
    description
  ) VALUES (
    v_owner,
    GREATEST(1, ROUND(v_credited)::bigint),
    'cash',
    'salary_payout',
    r.id,
    format(
      'Agency per-host period salary $%s for %s',
      v_credited,
      p_period_id
    )
  );

  RETURN json_build_object(
    'success', true,
    'period_id', p_period_id,
    'agency_id', p_agency_id,
    'calculation', 'per_host_level_sum',
    'total_usd', v_credited,
    'owner_user_id', v_owner
  );
END;
$function$;

ALTER FUNCTION public.execute_one_agency_period_payout(text, uuid)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.execute_one_agency_period_payout(text, uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.execute_one_agency_period_payout(text, uuid)
  TO service_role;

-- Remove every agency payout cron path and recreate exactly one daily guard.
-- The wrapper itself no-ops except local day 1 or 16.
DO $cron$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_extension
    WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname IN (
      'agency-payout-period-a',
      'agency-payout-period-b',
      'agency-payout-daily-check'
    )
       OR lower(command) LIKE '%execute_agency_period_payout%'
       OR lower(command) LIKE '%run_scheduled_agency_period_payouts%';

    PERFORM cron.schedule(
      'agency-payout-daily-check',
      '5 21 * * *',
      'SELECT public.run_scheduled_agency_period_payouts();'
    );
  END IF;
END;
$cron$;

NOTIFY pgrst, 'reload schema';
