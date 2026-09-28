-- Bi-monthly salary system: period tables, stats, chain config, payout audit

-- ---------------------------------------------------------------------------
-- 1. Extend salary_tiers
-- ---------------------------------------------------------------------------
ALTER TABLE public.salary_tiers
    ADD COLUMN IF NOT EXISTS tier_name text,
    ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 0;

-- ---------------------------------------------------------------------------
-- 2. salary_periods
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.salary_periods (
    period_id text PRIMARY KEY,
    start_date date NOT NULL,
    end_date date NOT NULL,
    payout_date date NOT NULL,
    status text NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'calculated', 'paid')),
    calculated_at timestamptz,
    paid_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 3. salary_chain_configs (singleton)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.salary_chain_configs (
    id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    agency_salary_pc integer NOT NULL DEFAULT 10,
    bd_salary_pc integer NOT NULL DEFAULT 5,
    bd_admin_salary_pc integer NOT NULL DEFAULT 3,
    super_bd_salary_pc integer NOT NULL DEFAULT 2,
    min_valid_day_seconds integer NOT NULL DEFAULT 7200,
    on_mic_only boolean NOT NULL DEFAULT true,
    diamonds_per_dollar integer NOT NULL DEFAULT 1000,
    updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.salary_chain_configs (id)
VALUES (1)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. host_period_stats
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.host_period_stats (
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    period_id text NOT NULL REFERENCES public.salary_periods(period_id) ON DELETE CASCADE,
    total_diamonds integer NOT NULL DEFAULT 0,
    total_on_mic_seconds integer NOT NULL DEFAULT 0,
    valid_days integer NOT NULL DEFAULT 0,
    daily_seconds jsonb NOT NULL DEFAULT '{}'::jsonb,
    last_active_date date,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, period_id)
);

CREATE INDEX IF NOT EXISTS host_period_stats_period_idx ON public.host_period_stats(period_id);

-- ---------------------------------------------------------------------------
-- 5. host_salary_payouts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.host_salary_payouts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    period_id text NOT NULL REFERENCES public.salary_periods(period_id) ON DELETE CASCADE,
    beneficiary_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    beneficiary_role text NOT NULL
        CHECK (beneficiary_role IN ('host', 'agency', 'bd', 'bd_admin', 'super_bd')),
    source_host_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    tier_id uuid REFERENCES public.salary_tiers(id) ON DELETE SET NULL,
    base_amount integer NOT NULL DEFAULT 0,
    override_amount integer NOT NULL DEFAULT 0,
    total_amount integer NOT NULL DEFAULT 0,
    stats_snapshot jsonb,
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'withheld', 'skipped')),
    paid_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (period_id, beneficiary_user_id, beneficiary_role, source_host_id)
);

CREATE INDEX IF NOT EXISTS host_salary_payouts_period_idx ON public.host_salary_payouts(period_id);
CREATE INDEX IF NOT EXISTS host_salary_payouts_user_idx ON public.host_salary_payouts(beneficiary_user_id);

-- ---------------------------------------------------------------------------
-- 6. Period helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_period_id_for_date(p_date date DEFAULT current_date)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $function$
DECLARE
    v_year text;
    v_month text;
BEGIN
    v_year := to_char(p_date, 'YYYY');
    v_month := to_char(p_date, 'MM');
    IF extract(day FROM p_date) <= 15 THEN
        RETURN v_year || '-' || v_month || '-A';
    END IF;
    RETURN v_year || '-' || v_month || '-B';
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_period_bounds(p_period_id text)
RETURNS TABLE(start_date date, end_date date, payout_date date)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_year int;
    v_month int;
    v_suffix text;
BEGIN
    v_year := split_part(p_period_id, '-', 1)::int;
    v_month := split_part(p_period_id, '-', 2)::int;
    v_suffix := split_part(p_period_id, '-', 3);

    IF v_suffix = 'A' THEN
        start_date := make_date(v_year, v_month, 1);
        end_date := make_date(v_year, v_month, 15);
        payout_date := make_date(v_year, v_month, 15);
    ELSE
        start_date := make_date(v_year, v_month, 16);
        end_date := (date_trunc('month', make_date(v_year, v_month, 1)) + interval '1 month - 1 day')::date;
        payout_date := end_date;
    END IF;
    RETURN NEXT;
END;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_salary_period(p_period_id text)
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    b record;
BEGIN
    SELECT * INTO b FROM public.get_period_bounds(p_period_id);
    INSERT INTO public.salary_periods (period_id, start_date, end_date, payout_date, status)
    VALUES (p_period_id, b.start_date, b.end_date, b.payout_date, 'open')
    ON CONFLICT (period_id) DO NOTHING;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_current_period_info()
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_period_id text;
    b record;
BEGIN
    v_period_id := public.get_period_id_for_date(current_date);
    PERFORM public.ensure_salary_period(v_period_id);
    SELECT * INTO b FROM public.get_period_bounds(v_period_id);
    RETURN json_build_object(
        'period_id', v_period_id,
        'start_date', b.start_date,
        'end_date', b.end_date,
        'payout_date', b.payout_date
    );
END;
$function$;

-- Auto-ensure current period on first stats write
CREATE OR REPLACE FUNCTION public.upsert_host_period_diamonds(
    p_user_id uuid,
    p_diamond_amount integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_period_id text;
BEGIN
    IF p_diamond_amount IS NULL OR p_diamond_amount <= 0 THEN
        RETURN;
    END IF;
    v_period_id := public.get_period_id_for_date(current_date);
    PERFORM public.ensure_salary_period(v_period_id);
    INSERT INTO public.host_period_stats (user_id, period_id, total_diamonds)
    VALUES (p_user_id, v_period_id, p_diamond_amount)
    ON CONFLICT (user_id, period_id) DO UPDATE SET
        total_diamonds = public.host_period_stats.total_diamonds + p_diamond_amount,
        updated_at = now();
END;
$function$;

-- ---------------------------------------------------------------------------
-- 7. RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.salary_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.host_period_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.host_salary_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salary_chain_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone read salary periods" ON public.salary_periods;
CREATE POLICY "Anyone read salary periods" ON public.salary_periods
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users read own period stats" ON public.host_period_stats;
CREATE POLICY "Users read own period stats" ON public.host_period_stats
    FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users read own salary payouts" ON public.host_salary_payouts;
CREATE POLICY "Users read own salary payouts" ON public.host_salary_payouts
    FOR SELECT TO authenticated USING (beneficiary_user_id = auth.uid());

DROP POLICY IF EXISTS "Authenticated read salary chain config" ON public.salary_chain_configs;
CREATE POLICY "Authenticated read salary chain config" ON public.salary_chain_configs
    FOR SELECT TO authenticated USING (true);
