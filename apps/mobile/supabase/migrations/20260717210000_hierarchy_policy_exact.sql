-- Hierarchy + Policy Exact (Agency 2026/06 + BD 2026/06)
-- Roles, gift host-30% only, 15-day periods, agency/BD salary tables, RPCs

-- =============================================================================
-- 0. ROLES: county_admin (+ alias bd_admin), assistant, customer_service
-- =============================================================================

ALTER TABLE public.business_staff DROP CONSTRAINT IF EXISTS business_staff_role_check;

UPDATE public.business_staff
SET role = 'county_admin'
WHERE role = 'bd_admin';

ALTER TABLE public.business_staff
  ADD CONSTRAINT business_staff_role_check
  CHECK (role IN (
    'super_bd',
    'county_admin',
    'bd_admin', -- legacy alias accepted for reads; new writes use county_admin
    'bd',
    'assistant',
    'customer_service'
  ));

CREATE OR REPLACE FUNCTION public.normalize_staff_role(p_role text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_role = 'bd_admin' THEN 'county_admin'
    ELSE p_role
  END;
$$;

CREATE OR REPLACE FUNCTION public.business_staff_child_role(p_parent_role text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $function$
BEGIN
  CASE public.normalize_staff_role(p_parent_role)
    WHEN 'super_bd' THEN RETURN 'county_admin'; -- default create path; assistant/CS via explicit role
    WHEN 'county_admin' THEN RETURN 'bd';
    WHEN 'bd_admin' THEN RETURN 'bd';
    ELSE RETURN NULL;
  END CASE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_business_staff(
  p_target_user_id uuid,
  p_role text,
  p_parent_staff_id uuid DEFAULT NULL,
  p_created_by_user_id uuid DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_parent public.business_staff%ROWTYPE;
  v_role text := public.normalize_staff_role(p_role);
  v_parent_role text;
  v_new_id uuid;
  v_code text;
  v_count int;
BEGIN
  IF v_role NOT IN ('super_bd', 'county_admin', 'bd', 'assistant', 'customer_service') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid role');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.business_staff
    WHERE user_id = p_target_user_id AND is_active = true
  ) THEN
    RETURN json_build_object('success', false, 'message', 'User already has an active staff role');
  END IF;

  IF v_role = 'super_bd' THEN
    IF p_parent_staff_id IS NOT NULL THEN
      RETURN json_build_object('success', false, 'message', 'Super Admin cannot have a parent staff');
    END IF;
  ELSE
    IF p_parent_staff_id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Parent staff is required');
    END IF;

    SELECT * INTO v_parent
    FROM public.business_staff
    WHERE id = p_parent_staff_id AND is_active = true;

    IF v_parent.id IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Parent staff not found');
    END IF;

    v_parent_role := public.normalize_staff_role(v_parent.role);

    IF v_parent_role = 'super_bd' THEN
      IF v_role NOT IN ('county_admin', 'assistant', 'customer_service') THEN
        RETURN json_build_object('success', false, 'message', 'Super Admin can only create County Admin, Assistant, or Customer Service');
      END IF;
      SELECT COUNT(*) INTO v_count FROM public.business_staff
      WHERE parent_staff_id = v_parent.id AND is_active = true AND public.normalize_staff_role(role) = v_role;
      IF v_role = 'county_admin' AND v_count >= 2 THEN
        RETURN json_build_object('success', false, 'message', 'Max 2 County Admins per Super Admin');
      END IF;
      IF v_role = 'assistant' AND v_count >= 2 THEN
        RETURN json_build_object('success', false, 'message', 'Max 2 Assistants per Super Admin');
      END IF;
      IF v_role = 'customer_service' AND v_count >= 4 THEN
        RETURN json_build_object('success', false, 'message', 'Max 4 Customer Service per Super Admin');
      END IF;
    ELSIF v_parent_role = 'county_admin' THEN
      IF v_role <> 'bd' THEN
        RETURN json_build_object('success', false, 'message', 'County Admin can only create BD');
      END IF;
    ELSE
      RETURN json_build_object('success', false, 'message', 'This role cannot create staff');
    END IF;
  END IF;

  v_code := public.generate_staff_code();

  INSERT INTO public.business_staff (user_id, role, parent_staff_id, staff_code, created_by_user_id)
  VALUES (p_target_user_id, v_role, p_parent_staff_id, v_code, p_created_by_user_id)
  RETURNING id INTO v_new_id;

  RETURN json_build_object(
    'success', true,
    'staff_id', v_new_id,
    'staff_code', v_code,
    'role', v_role
  );
END;
$function$;

-- =============================================================================
-- 1. GIFT: host 30% diamonds only (no upline diamond cut)
-- =============================================================================

UPDATE public.commission_configs
SET host_pc = 30, agency_pc = 0, bd_pc = 0, bd_admin_pc = 0, super_bd_pc = 0, official_pc = 70, admin_pc = 70
WHERE id = 1;

ALTER TABLE public.commission_configs DROP CONSTRAINT IF EXISTS commission_configs_sum_100;
ALTER TABLE public.commission_configs
  ADD CONSTRAINT commission_configs_sum_100 CHECK (
    host_pc + agency_pc + bd_pc + bd_admin_pc + super_bd_pc + official_pc = 100
  );

CREATE TABLE IF NOT EXISTS public.policy_gift_settings (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  host_gift_percent int NOT NULL DEFAULT 30,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.policy_gift_settings (id, host_gift_percent)
VALUES (1, 30)
ON CONFLICT (id) DO NOTHING;

-- Track period charm (gift coins = charm points per Agency Policy)
ALTER TABLE public.host_period_stats
  ADD COLUMN IF NOT EXISTS charm_points bigint NOT NULL DEFAULT 0;

-- =============================================================================
-- 2. PERIOD BOUNDS: day 15 ends 15:00 conceptually; payout 16 / next 1st
-- =============================================================================

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

  IF v_suffix IN ('A', 'H1') THEN
    start_date := make_date(v_year, v_month, 1);
    end_date := make_date(v_year, v_month, 15);
    payout_date := make_date(v_year, v_month, 16);
  ELSE
    start_date := make_date(v_year, v_month, 16);
    end_date := (date_trunc('month', make_date(v_year, v_month, 1)) + interval '1 month - 1 day')::date;
    payout_date := (date_trunc('month', make_date(v_year, v_month, 1)) + interval '1 month')::date;
  END IF;
  RETURN NEXT;
END;
$function$;

-- =============================================================================
-- 3. AGENCY SALARY LEVELS LV1-25
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.agency_salary_level_configs (
  level int PRIMARY KEY CHECK (level BETWEEN 1 AND 25),
  charm_target bigint NOT NULL,
  charm_salary_usd numeric(12, 2) NOT NULL DEFAULT 0,
  agent_salary_usd numeric(12, 2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.agency_salary_level_configs (level, charm_target, charm_salary_usd, agent_salary_usd) VALUES
  (1, 500000, 2.5, 1),
  (2, 1000000, 5, 2),
  (3, 2000000, 10, 4),
  (4, 4000000, 18, 8),
  (5, 6000000, 27, 12),
  (6, 8000000, 36, 16),
  (7, 10000000, 45, 20),
  (8, 12500000, 56, 25),
  (9, 15000000, 70, 32),
  (10, 20000000, 86, 40),
  (11, 25000000, 110, 50),
  (12, 30000000, 135, 62),
  (13, 40000000, 175, 80),
  (14, 50000000, 210, 100),
  (15, 60000000, 252, 120),
  (16, 80000000, 340, 160),
  (17, 100000000, 430, 200),
  (18, 150000000, 650, 300),
  (19, 200000000, 900, 420),
  (20, 300000000, 1340, 600),
  (21, 500000000, 2200, 1000),
  (22, 800000000, 3600, 1600),
  (23, 1200000000, 5500, 2400),
  (24, 2000000000, 9000, 4000),
  (25, 3000000000, 15000, 6000)
ON CONFLICT (level) DO UPDATE SET
  charm_target = EXCLUDED.charm_target,
  charm_salary_usd = EXCLUDED.charm_salary_usd,
  agent_salary_usd = EXCLUDED.agent_salary_usd;

ALTER TABLE public.agency_salary_level_configs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read agency salary levels" ON public.agency_salary_level_configs;
CREATE POLICY "Public read agency salary levels"
  ON public.agency_salary_level_configs FOR SELECT TO public USING (true);

-- =============================================================================
-- 4. BD LEVEL CONFIGS LV1-10 + settings
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.bd_center_settings (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  timezone text NOT NULL DEFAULT 'UTC+3',
  settlement_day_of_month int NOT NULL DEFAULT 15,
  new_bd_window_months int NOT NULL DEFAULT 3,
  work_days_required int NOT NULL DEFAULT 15,
  work_hours_required numeric(6, 1) NOT NULL DEFAULT 30,
  basic_salary_desc text,
  commission_desc text,
  new_bd_desc text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.bd_center_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.bd_level_configs (
  level int PRIMARY KEY CHECK (level BETWEEN 0 AND 10),
  agency_target_usd numeric(12, 2) NOT NULL DEFAULT 0,
  basic_salary_usd numeric(12, 2) NOT NULL DEFAULT 0,
  commission_usd numeric(12, 2) NOT NULL DEFAULT 0,
  new_bd_commission_usd numeric(12, 2) NOT NULL DEFAULT 0,
  work_days int NOT NULL DEFAULT 15,
  work_hours numeric(6, 1) NOT NULL DEFAULT 30,
  badge_url text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.bd_level_configs (
  level, agency_target_usd, basic_salary_usd, commission_usd, new_bd_commission_usd
) VALUES
  (0, 0, 0, 0, 0),
  (1, 100, 0, 3, 2),
  (2, 200, 0, 6, 4),
  (3, 300, 3, 9, 6),
  (4, 500, 5, 15, 10),
  (5, 1000, 10, 30, 20),
  (6, 3000, 30, 90, 60),
  (7, 5000, 50, 150, 100),
  (8, 10000, 100, 300, 200),
  (9, 15000, 150, 450, 300),
  (10, 20000, 200, 600, 400)
ON CONFLICT (level) DO UPDATE SET
  agency_target_usd = EXCLUDED.agency_target_usd,
  basic_salary_usd = EXCLUDED.basic_salary_usd,
  commission_usd = EXCLUDED.commission_usd,
  new_bd_commission_usd = EXCLUDED.new_bd_commission_usd;

ALTER TABLE public.bd_level_configs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read bd levels" ON public.bd_level_configs;
CREATE POLICY "Public read bd levels"
  ON public.bd_level_configs FOR SELECT TO public USING (true);

ALTER TABLE public.bd_center_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read bd settings" ON public.bd_center_settings;
CREATE POLICY "Public read bd settings"
  ON public.bd_center_settings FOR SELECT TO public USING (true);

CREATE TABLE IF NOT EXISTS public.bd_staff_monthly_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL REFERENCES public.business_staff(id) ON DELETE CASCADE,
  period_yyyy_mm text NOT NULL,
  agency_target_usd numeric(14, 2) NOT NULL DEFAULT 0,
  work_days int NOT NULL DEFAULT 0,
  work_hours numeric(8, 1) NOT NULL DEFAULT 0,
  new_agencies int NOT NULL DEFAULT 0,
  achieved_level int NOT NULL DEFAULT 0,
  est_basic_usd numeric(12, 2) NOT NULL DEFAULT 0,
  est_commission_usd numeric(12, 2) NOT NULL DEFAULT 0,
  est_new_bd_usd numeric(12, 2) NOT NULL DEFAULT 0,
  est_total_usd numeric(12, 2) NOT NULL DEFAULT 0,
  in_new_bd_window boolean NOT NULL DEFAULT false,
  last_calculated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (staff_id, period_yyyy_mm)
);

CREATE TABLE IF NOT EXISTS public.bd_staff_settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL REFERENCES public.business_staff(id) ON DELETE CASCADE,
  period_yyyy_mm text NOT NULL,
  achieved_level int NOT NULL DEFAULT 0,
  basic_usd numeric(12, 2) NOT NULL DEFAULT 0,
  commission_usd numeric(12, 2) NOT NULL DEFAULT 0,
  new_bd_usd numeric(12, 2) NOT NULL DEFAULT 0,
  total_usd numeric(12, 2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled')),
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (staff_id, period_yyyy_mm)
);

CREATE TABLE IF NOT EXISTS public.agency_period_settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id uuid NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE,
  period_id text NOT NULL,
  total_charm bigint NOT NULL DEFAULT 0,
  achieved_level int NOT NULL DEFAULT 0,
  charm_salary_usd numeric(12, 2) NOT NULL DEFAULT 0,
  agent_salary_usd numeric(12, 2) NOT NULL DEFAULT 0,
  total_usd numeric(12, 2) NOT NULL DEFAULT 0,
  owner_user_id uuid REFERENCES public.users(id),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled')),
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (agency_id, period_id)
);

-- =============================================================================
-- 5. send_gift: host percent from policy; zero upline diamonds; track charm_points
-- =============================================================================

CREATE OR REPLACE FUNCTION public.send_gift(
  p_sender_id uuid,
  p_receiver_id uuid,
  p_gift_id uuid,
  p_room_id uuid,
  p_quantity integer DEFAULT 1
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_gift_price INT;
  v_category_name TEXT;
  v_is_lucky BOOLEAN := false;
  v_is_lucky_pro BOOLEAN := false;
  v_lucky_pro_bonus_won BOOLEAN := false;
  v_lucky_pro_bonus_coins BIGINT := 0;
  v_bonus_result JSON;
  v_total_cost BIGINT;
  v_sender_coins BIGINT;
  v_host_pc INT := 30;
  v_agency_id UUID;
  v_agency_owner_id UUID;
  v_sponsor_staff_id UUID;
  v_host_share INT;
  v_official_share INT := 0;
  v_new_wealth_value BIGINT;
  v_new_wealth_level INT;
  v_new_charm_value BIGINT;
  v_new_charm_level INT;
  v_exp_multiplier FLOAT;
  v_hotness_multiplier FLOAT;
  v_gift_log_id UUID;
  v_week_id TEXT;
  v_couple_id UUID;
  v_new_cp_exp BIGINT;
  v_new_cp_level INT;
  v_family_id UUID;
  v_new_family_exp BIGINT;
  v_new_family_level INT;
  v_lucky_cfg RECORD;
  v_gift_count INT := 0;
  v_threshold INT := 0;
  v_bonus_coins BIGINT;
  v_multiplier NUMERIC;
  v_lucky_bonus_won BOOLEAN := false;
  v_use_sender_counter BOOLEAN := false;
  v_receiver_name TEXT;
  v_bonus_mode TEXT;
  v_period_id text;
BEGIN
  SELECT si.price_coins, lower(sc.name)
  INTO v_gift_price, v_category_name
  FROM public.shop_items si
  LEFT JOIN public.shop_categories sc ON sc.id = si.category_id
  WHERE si.id = p_gift_id AND si.is_active = TRUE;

  IF v_gift_price IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Gift not found or inactive');
  END IF;

  v_is_lucky := (v_category_name IN ('lucky', 'luck'));
  v_is_lucky_pro := (v_category_name IN ('lucky pro', 'lucky_pro', 'luckypro'));
  v_total_cost := v_gift_price * p_quantity;

  SELECT coins INTO v_sender_coins FROM public.users WHERE id = p_sender_id FOR UPDATE;
  IF v_sender_coins < v_total_cost THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  SELECT COALESCE(host_gift_percent, 30) INTO v_host_pc FROM public.policy_gift_settings WHERE id = 1;
  IF v_host_pc IS NULL THEN v_host_pc := 30; END IF;

  SELECT am.agency_id, a.owner_id, a.sponsor_staff_id
  INTO v_agency_id, v_agency_owner_id, v_sponsor_staff_id
  FROM public.agency_members am
  JOIN public.agencies a ON a.id = am.agency_id
  WHERE am.user_id = p_receiver_id AND a.is_active = TRUE;

  IF v_is_lucky THEN
    SELECT * INTO v_lucky_cfg FROM public.lucky_gift_config WHERE id = 1;
    v_host_share := (v_total_cost * v_lucky_cfg.receiver_percent::numeric / 100)::int;
  ELSIF v_is_lucky_pro THEN
    SELECT * INTO v_lucky_cfg FROM public.lucky_pro_gift_config WHERE id = 1;
    v_host_share := (v_total_cost * v_lucky_cfg.receiver_percent::numeric / 100)::int;
  ELSE
    v_host_share := (v_total_cost * v_host_pc) / 100;
  END IF;

  v_official_share := v_total_cost - v_host_share;
  IF v_official_share < 0 THEN v_official_share := 0; END IF;

  -- Agency gate: non-agency receivers get no gift diamonds
  IF v_agency_id IS NULL AND v_host_share > 0 THEN
    v_official_share := v_official_share + v_host_share;
    v_host_share := 0;
  END IF;

  SELECT (wealth_value + v_total_cost) INTO v_new_wealth_value FROM public.users WHERE id = p_sender_id;
  SELECT level INTO v_new_wealth_level FROM public.level_configs
    WHERE category = 'wealth' AND min_exp <= v_new_wealth_value ORDER BY level DESC LIMIT 1;
  IF v_new_wealth_level IS NULL THEN v_new_wealth_level := 1; END IF;

  UPDATE public.users SET coins = coins - v_total_cost, wealth_value = v_new_wealth_value, wealth_level = v_new_wealth_level
  WHERE id = p_sender_id;

  SELECT (charm_value + v_total_cost) INTO v_new_charm_value FROM public.users WHERE id = p_receiver_id;
  SELECT level INTO v_new_charm_level FROM public.level_configs
    WHERE category = 'charm' AND min_exp <= v_new_charm_value ORDER BY level DESC LIMIT 1;
  IF v_new_charm_level IS NULL THEN v_new_charm_level := 1; END IF;

  UPDATE public.users SET diamonds = diamonds + v_host_share, charm_value = v_new_charm_value, charm_level = v_new_charm_level
  WHERE id = p_receiver_id;

  IF v_host_share > 0 THEN
    INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
    VALUES (p_receiver_id, v_host_share, 'diamond', 'gift_received', p_gift_id);
  END IF;

  INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
  VALUES (p_sender_id, -v_total_cost, 'coin', 'gift_sent', p_gift_id);

  -- Period charm = gift coins (Agency Policy: gold ≈ charm)
  BEGIN
    v_period_id := public.get_period_id_for_date(current_date);
    PERFORM public.ensure_salary_period(v_period_id);
    INSERT INTO public.host_period_stats (user_id, period_id, total_diamonds, charm_points)
    VALUES (p_receiver_id, v_period_id, v_host_share, v_total_cost)
    ON CONFLICT (user_id, period_id) DO UPDATE SET
      total_diamonds = public.host_period_stats.total_diamonds + EXCLUDED.total_diamonds,
      charm_points = public.host_period_stats.charm_points + EXCLUDED.charm_points;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  INSERT INTO public.gift_logs (sender_id, receiver_id, gift_id, room_id, amount)
  VALUES (p_sender_id, p_receiver_id, p_gift_id, p_room_id, v_total_cost)
  RETURNING id INTO v_gift_log_id;

  INSERT INTO public.earning_logs (
    gift_log_id, host_id, host_amount,
    agency_owner_id, agency_amount,
    bd_staff_id, bd_amount,
    bd_admin_staff_id, bd_admin_amount,
    super_bd_staff_id, super_bd_amount,
    official_amount, admin_amount,
    total_gift_value
  ) VALUES (
    v_gift_log_id, p_receiver_id, v_host_share,
    v_agency_owner_id, 0,
    NULL, 0,
    NULL, 0,
    NULL, 0,
    v_official_share, v_official_share,
    v_total_cost
  );

  -- Room / CP / family / lucky bonus (keep existing behavior where functions exist)
  BEGIN
    SELECT exp_multiplier, hotness_multiplier INTO v_exp_multiplier, v_hotness_multiplier
    FROM public.gifts WHERE id = p_gift_id;
  EXCEPTION WHEN OTHERS THEN
    v_exp_multiplier := 1; v_hotness_multiplier := 1;
  END;

  BEGIN
    PERFORM public.add_room_exp(p_room_id, (v_total_cost * COALESCE(v_exp_multiplier, 1))::bigint);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    PERFORM public.add_room_hotness(p_room_id, (v_total_cost * COALESCE(v_hotness_multiplier, 1))::bigint);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  IF v_is_lucky OR v_is_lucky_pro THEN
    BEGIN
      v_bonus_result := public.process_gift_category_bonus(
        CASE WHEN v_is_lucky_pro THEN 'lucky_pro' ELSE 'lucky' END,
        p_sender_id,
        p_receiver_id,
        p_gift_id,
        v_gift_log_id,
        v_total_cost
      );
      IF v_bonus_result IS NOT NULL THEN
        IF v_is_lucky_pro THEN
          v_lucky_pro_bonus_won := COALESCE((v_bonus_result->>'bonus_won')::boolean, false);
          v_lucky_pro_bonus_coins := COALESCE((v_bonus_result->>'bonus_coins')::bigint, 0);
          v_bonus_coins := COALESCE((v_bonus_result->>'bonus_coins')::bigint, 0);
        ELSE
          v_lucky_bonus_won := COALESCE((v_bonus_result->>'bonus_won')::boolean, false);
          v_bonus_coins := COALESCE((v_bonus_result->>'bonus_coins')::bigint, 0);
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'lucky bonus failed: %', SQLERRM;
    END;
  END IF;

  SELECT username INTO v_receiver_name FROM public.users WHERE id = p_receiver_id;

  RETURN json_build_object(
    'success', true,
    'host_share', v_host_share,
    'agency_share', 0,
    'bd_share', 0,
    'official_share', v_official_share,
    'receiver_name', v_receiver_name,
    'is_lucky_gift', v_is_lucky,
    'is_lucky_pro_gift', v_is_lucky_pro,
    'lucky_bonus_won', v_lucky_bonus_won,
    'lucky_bonus_coins', CASE WHEN v_lucky_bonus_won THEN COALESCE(v_bonus_coins, 0) ELSE 0 END,
    'lucky_pro_bonus_won', v_lucky_pro_bonus_won,
    'lucky_pro_bonus_coins', v_lucky_pro_bonus_coins,
    'bonus_coins', COALESCE(v_bonus_coins, 0),
    'gift_log_id', v_gift_log_id
  );
END;
$function$;

-- =============================================================================
-- 6. RPCs: host/agency dashboard, BD dashboard, activate, settlements
-- =============================================================================

CREATE OR REPLACE FUNCTION public.match_agency_salary_level(p_charm bigint)
RETURNS public.agency_salary_level_configs
LANGUAGE sql
STABLE
AS $$
  SELECT * FROM public.agency_salary_level_configs
  WHERE is_active AND charm_target <= p_charm
  ORDER BY level DESC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.get_host_period_target(p_period_id text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_period text;
  v_charm bigint := 0;
  v_matched public.agency_salary_level_configs%ROWTYPE;
  v_next public.agency_salary_level_configs%ROWTYPE;
  b record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  v_period := COALESCE(p_period_id, public.get_period_id_for_date(current_date));
  PERFORM public.ensure_salary_period(v_period);
  SELECT * INTO b FROM public.get_period_bounds(v_period);

  SELECT COALESCE(charm_points, 0) INTO v_charm
  FROM public.host_period_stats
  WHERE user_id = v_uid AND period_id = v_period;

  SELECT * INTO v_matched FROM public.match_agency_salary_level(COALESCE(v_charm, 0));
  SELECT * INTO v_next FROM public.agency_salary_level_configs
  WHERE is_active AND (v_matched.level IS NULL OR level > v_matched.level)
  ORDER BY level ASC LIMIT 1;

  RETURN json_build_object(
    'success', true,
    'period_id', v_period,
    'start_date', b.start_date,
    'end_date', b.end_date,
    'payout_date', b.payout_date,
    'charm_points', COALESCE(v_charm, 0),
    'achieved_level', COALESCE(v_matched.level, 0),
    'charm_salary_usd', COALESCE(v_matched.charm_salary_usd, 0),
    'agent_salary_usd', COALESCE(v_matched.agent_salary_usd, 0),
    'estimated_salary_usd', COALESCE(v_matched.charm_salary_usd, 0),
    'note', 'Period salary is paid to the agency owner wallet. Host receives offline cash from agency.',
    'next_level', CASE WHEN v_next.level IS NULL THEN NULL ELSE json_build_object(
      'level', v_next.level,
      'charm_target', v_next.charm_target,
      'charm_salary_usd', v_next.charm_salary_usd,
      'remaining', GREATEST(v_next.charm_target - COALESCE(v_charm, 0), 0)
    ) END
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_agency_period_targets(p_agency_id uuid, p_period_id text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_period text;
  v_total_charm bigint := 0;
  v_matched public.agency_salary_level_configs%ROWTYPE;
  v_hosts json;
  b record;
  v_owner uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT owner_id INTO v_owner FROM public.agencies WHERE id = p_agency_id;
  IF v_owner IS DISTINCT FROM v_uid AND NOT EXISTS (
    SELECT 1 FROM public.agency_members
    WHERE agency_id = p_agency_id AND user_id = v_uid AND role IN ('owner', 'admin')
  ) THEN
    RETURN json_build_object('success', false, 'message', 'No access');
  END IF;

  v_period := COALESCE(p_period_id, public.get_period_id_for_date(current_date));
  SELECT * INTO b FROM public.get_period_bounds(v_period);

  SELECT COALESCE(SUM(hps.charm_points), 0) INTO v_total_charm
  FROM public.agency_members am
  JOIN public.host_period_stats hps ON hps.user_id = am.user_id AND hps.period_id = v_period
  WHERE am.agency_id = p_agency_id;

  SELECT * INTO v_matched FROM public.match_agency_salary_level(v_total_charm);

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_hosts
  FROM (
    SELECT
      am.user_id,
      u.username,
      u.short_id,
      u.avatar_url,
      COALESCE(hps.charm_points, 0) AS charm_points,
      COALESCE(m.level, 0) AS achieved_level,
      COALESCE(m.charm_salary_usd, 0) AS estimated_charm_salary_usd
    FROM public.agency_members am
    JOIN public.users u ON u.id = am.user_id
    LEFT JOIN public.host_period_stats hps ON hps.user_id = am.user_id AND hps.period_id = v_period
    LEFT JOIN LATERAL (
      SELECT * FROM public.match_agency_salary_level(COALESCE(hps.charm_points, 0))
    ) m ON true
    WHERE am.agency_id = p_agency_id
    ORDER BY COALESCE(hps.charm_points, 0) DESC
  ) t;

  RETURN json_build_object(
    'success', true,
    'period_id', v_period,
    'start_date', b.start_date,
    'end_date', b.end_date,
    'payout_date', b.payout_date,
    'total_charm', v_total_charm,
    'achieved_level', COALESCE(v_matched.level, 0),
    'charm_salary_usd', COALESCE(v_matched.charm_salary_usd, 0),
    'agent_salary_usd', COALESCE(v_matched.agent_salary_usd, 0),
    'total_usd', COALESCE(v_matched.charm_salary_usd, 0) + COALESCE(v_matched.agent_salary_usd, 0),
    'owner_user_id', v_owner,
    'hosts', v_hosts
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.refresh_bd_monthly_stats(p_staff_id uuid, p_period_yyyy_mm text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_period text := COALESCE(p_period_yyyy_mm, to_char(current_date, 'YYYY-MM'));
  v_staff public.business_staff%ROWTYPE;
  v_target numeric := 0;
  v_level int := 0;
  v_cfg public.bd_level_configs%ROWTYPE;
  v_settings public.bd_center_settings%ROWTYPE;
  v_in_window boolean := false;
  v_basic numeric := 0;
  v_comm numeric := 0;
  v_new_bd numeric := 0;
  v_new_agencies int := 0;
  v_month_start date;
  v_month_end date;
BEGIN
  SELECT * INTO v_staff FROM public.business_staff WHERE id = p_staff_id AND is_active;
  IF v_staff.id IS NULL OR public.normalize_staff_role(v_staff.role) <> 'bd' THEN
    RETURN json_build_object('success', false, 'message', 'BD staff not found');
  END IF;

  SELECT * INTO v_settings FROM public.bd_center_settings WHERE id = 1;
  v_month_start := (v_period || '-01')::date;
  v_month_end := (date_trunc('month', v_month_start) + interval '1 month - 1 day')::date;

  v_in_window := (v_staff.created_at >= (v_month_start - make_interval(months => COALESCE(v_settings.new_bd_window_months, 3))));

  -- Agency USD target proxy: sum of agency period charm converted via rough rate
  -- Use settled / live period charm across both half-months, exclude BD-owned agencies
  SELECT COALESCE(SUM(COALESCE(hps.charm_points, 0)), 0)::numeric / 68000.0 INTO v_target
  FROM public.agencies a
  JOIN public.agency_members am ON am.agency_id = a.id
  JOIN public.host_period_stats hps ON hps.user_id = am.user_id
    AND hps.period_id LIKE (v_period || '-%')
  WHERE a.sponsor_staff_id = p_staff_id
    AND a.is_active = true
    AND a.owner_id IS DISTINCT FROM v_staff.user_id;

  SELECT COUNT(*) INTO v_new_agencies
  FROM public.agencies a
  WHERE a.sponsor_staff_id = p_staff_id
    AND a.owner_id IS DISTINCT FROM v_staff.user_id
    AND a.created_at::date BETWEEN v_month_start AND v_month_end;

  SELECT * INTO v_cfg FROM public.bd_level_configs
  WHERE is_active AND agency_target_usd <= COALESCE(v_target, 0)
  ORDER BY level DESC LIMIT 1;

  v_level := COALESCE(v_cfg.level, 0);
  v_comm := COALESCE(v_cfg.commission_usd, 0);
  v_new_bd := CASE WHEN v_in_window THEN COALESCE(v_cfg.new_bd_commission_usd, 0) ELSE 0 END;
  -- Basic requires level + attendance; attendance checked at payout (default grant estimate if level>=3)
  v_basic := COALESCE(v_cfg.basic_salary_usd, 0);

  INSERT INTO public.bd_staff_monthly_stats AS s (
    staff_id, period_yyyy_mm, agency_target_usd, new_agencies, achieved_level,
    est_basic_usd, est_commission_usd, est_new_bd_usd, est_total_usd, in_new_bd_window, last_calculated_at
  ) VALUES (
    p_staff_id, v_period, COALESCE(v_target, 0), v_new_agencies, v_level,
    v_basic, v_comm, v_new_bd, v_basic + v_comm + v_new_bd, v_in_window, now()
  )
  ON CONFLICT (staff_id, period_yyyy_mm) DO UPDATE SET
    agency_target_usd = EXCLUDED.agency_target_usd,
    new_agencies = EXCLUDED.new_agencies,
    achieved_level = EXCLUDED.achieved_level,
    est_basic_usd = EXCLUDED.est_basic_usd,
    est_commission_usd = EXCLUDED.est_commission_usd,
    est_new_bd_usd = EXCLUDED.est_new_bd_usd,
    est_total_usd = EXCLUDED.est_total_usd,
    in_new_bd_window = EXCLUDED.in_new_bd_window,
    last_calculated_at = now();

  RETURN json_build_object(
    'success', true,
    'period', v_period,
    'agency_target_usd', COALESCE(v_target, 0),
    'achieved_level', v_level,
    'est_total_usd', v_basic + v_comm + v_new_bd
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_bd_center(p_period_yyyy_mm text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_staff public.business_staff%ROWTYPE;
  v_period text := COALESCE(p_period_yyyy_mm, to_char(current_date, 'YYYY-MM'));
  v_stats public.bd_staff_monthly_stats%ROWTYPE;
  v_settings public.bd_center_settings%ROWTYPE;
  v_next public.bd_level_configs%ROWTYPE;
  v_agencies json;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_staff FROM public.business_staff
  WHERE user_id = v_uid AND is_active = true
  ORDER BY created_at DESC LIMIT 1;

  IF v_staff.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'No staff role');
  END IF;

  IF public.normalize_staff_role(v_staff.role) = 'bd' THEN
    PERFORM public.refresh_bd_monthly_stats(v_staff.id, v_period);
  END IF;

  SELECT * INTO v_stats FROM public.bd_staff_monthly_stats
  WHERE staff_id = v_staff.id AND period_yyyy_mm = v_period;

  SELECT * INTO v_settings FROM public.bd_center_settings WHERE id = 1;

  SELECT * INTO v_next FROM public.bd_level_configs
  WHERE is_active AND level > COALESCE(v_stats.achieved_level, 0)
  ORDER BY level ASC LIMIT 1;

  SELECT COALESCE(json_agg(row_to_json(a)), '[]'::json) INTO v_agencies
  FROM (
    SELECT id, name, agency_code, is_active, owner_id, created_at
    FROM public.agencies
    WHERE sponsor_staff_id = v_staff.id AND is_active = true
      AND owner_id IS DISTINCT FROM v_staff.user_id
    ORDER BY created_at DESC
  ) a;

  RETURN json_build_object(
    'success', true,
    'staff', json_build_object(
      'id', v_staff.id,
      'role', public.normalize_staff_role(v_staff.role),
      'staff_code', v_staff.staff_code
    ),
    'period', v_period,
    'settlement_day', COALESCE(v_settings.settlement_day_of_month, 15),
    'timezone', COALESCE(v_settings.timezone, 'UTC+3'),
    'stats', CASE WHEN v_stats.id IS NULL THEN NULL ELSE json_build_object(
      'agency_target_usd', v_stats.agency_target_usd,
      'achieved_level', v_stats.achieved_level,
      'est_basic_usd', v_stats.est_basic_usd,
      'est_commission_usd', v_stats.est_commission_usd,
      'est_new_bd_usd', v_stats.est_new_bd_usd,
      'est_total_usd', v_stats.est_total_usd,
      'new_agencies', v_stats.new_agencies,
      'in_new_bd_window', v_stats.in_new_bd_window,
      'work_days', v_stats.work_days,
      'work_hours', v_stats.work_hours
    ) END,
    'next_level', CASE WHEN v_next.level IS NULL THEN NULL ELSE json_build_object(
      'level', v_next.level,
      'agency_target_usd', v_next.agency_target_usd,
      'remaining_usd', GREATEST(v_next.agency_target_usd - COALESCE(v_stats.agency_target_usd, 0), 0)
    ) END,
    'agencies', v_agencies,
    'levels', (SELECT COALESCE(json_agg(row_to_json(l) ORDER BY l.level), '[]'::json) FROM public.bd_level_configs l WHERE l.is_active)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.county_admin_activate_bd(
  p_target_user_id uuid,
  p_admin_staff_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_admin public.business_staff%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_admin FROM public.business_staff
  WHERE staff_code = trim(p_admin_staff_code) AND is_active = true
    AND public.normalize_staff_role(role) = 'county_admin';

  IF v_admin.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid County Admin ID');
  END IF;

  IF v_admin.user_id IS DISTINCT FROM v_uid THEN
    RETURN json_build_object('success', false, 'message', 'Admin ID must match your account');
  END IF;

  RETURN public.create_business_staff(p_target_user_id, 'bd', v_admin.id, v_uid);
END;
$function$;

CREATE OR REPLACE FUNCTION public.county_admin_activate_agency(
  p_agency_id uuid,
  p_bd_staff_code text,
  p_admin_staff_code text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_admin public.business_staff%ROWTYPE;
  v_bd public.business_staff%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_admin FROM public.business_staff
  WHERE staff_code = trim(p_admin_staff_code) AND is_active = true
    AND public.normalize_staff_role(role) = 'county_admin';

  IF v_admin.id IS NULL OR v_admin.user_id IS DISTINCT FROM v_uid THEN
    RETURN json_build_object('success', false, 'message', 'Invalid County Admin ID');
  END IF;

  SELECT * INTO v_bd FROM public.business_staff
  WHERE staff_code = trim(p_bd_staff_code) AND is_active = true
    AND public.normalize_staff_role(role) = 'bd';

  IF v_bd.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid BD ID');
  END IF;

  IF v_bd.parent_staff_id IS DISTINCT FROM v_admin.id THEN
    RETURN json_build_object('success', false, 'message', 'BD is not under this County Admin');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.agencies
    WHERE id = p_agency_id AND sponsor_staff_id IS NOT NULL AND sponsor_staff_id IS DISTINCT FROM v_bd.id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Agency already bound to another BD');
  END IF;

  UPDATE public.agencies
  SET sponsor_staff_id = v_bd.id,
      approved_by_staff_id = v_admin.id,
      is_active = true
  WHERE id = p_agency_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Agency not found');
  END IF;

  RETURN json_build_object('success', true, 'agency_id', p_agency_id, 'bd_staff_id', v_bd.id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.execute_agency_period_payout(p_period_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  r record;
  v_matched public.agency_salary_level_configs%ROWTYPE;
  v_total_charm bigint;
  v_paid int := 0;
  v_charm_usd numeric;
  v_agent_usd numeric;
  v_sum numeric;
BEGIN
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

    UPDATE public.users
    SET cash_balance = COALESCE(cash_balance, 0) + v_sum
    WHERE id = r.owner_id;

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
      status = 'paid',
      paid_at = now();

    BEGIN
      INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
      VALUES (r.owner_id, (v_sum * 100)::bigint, 'cash', 'agency_period_salary', NULL);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    v_paid := v_paid + 1;
  END LOOP;

  RETURN json_build_object('success', true, 'period_id', p_period_id, 'agencies_paid', v_paid);
END;
$function$;

CREATE OR REPLACE FUNCTION public.execute_bd_monthly_payout(p_period_yyyy_mm text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  r record;
  v_stats public.bd_staff_monthly_stats%ROWTYPE;
  v_paid int := 0;
  v_total numeric;
BEGIN
  FOR r IN
    SELECT * FROM public.business_staff
    WHERE is_active AND public.normalize_staff_role(role) = 'bd'
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.bd_staff_settlements
      WHERE staff_id = r.id AND period_yyyy_mm = p_period_yyyy_mm AND status = 'paid'
    ) THEN
      CONTINUE;
    END IF;

    PERFORM public.refresh_bd_monthly_stats(r.id, p_period_yyyy_mm);
    SELECT * INTO v_stats FROM public.bd_staff_monthly_stats
    WHERE staff_id = r.id AND period_yyyy_mm = p_period_yyyy_mm;

    IF v_stats.id IS NULL THEN CONTINUE; END IF;

    v_total := COALESCE(v_stats.est_total_usd, 0);
    -- Basic salary requires attendance; if work_days < required, zero basic
    IF COALESCE(v_stats.work_days, 0) < 15 OR COALESCE(v_stats.work_hours, 0) < 30 THEN
      v_total := COALESCE(v_stats.est_commission_usd, 0) + COALESCE(v_stats.est_new_bd_usd, 0);
    END IF;

    IF v_total <= 0 THEN CONTINUE; END IF;

    UPDATE public.users
    SET cash_balance = COALESCE(cash_balance, 0) + v_total
    WHERE id = r.user_id;

    INSERT INTO public.bd_staff_settlements (
      staff_id, period_yyyy_mm, achieved_level,
      basic_usd, commission_usd, new_bd_usd, total_usd, status, paid_at
    ) VALUES (
      r.id, p_period_yyyy_mm, v_stats.achieved_level,
      CASE WHEN COALESCE(v_stats.work_days, 0) >= 15 AND COALESCE(v_stats.work_hours, 0) >= 30
        THEN v_stats.est_basic_usd ELSE 0 END,
      v_stats.est_commission_usd,
      v_stats.est_new_bd_usd,
      v_total, 'paid', now()
    )
    ON CONFLICT (staff_id, period_yyyy_mm) DO UPDATE SET
      achieved_level = EXCLUDED.achieved_level,
      basic_usd = EXCLUDED.basic_usd,
      commission_usd = EXCLUDED.commission_usd,
      new_bd_usd = EXCLUDED.new_bd_usd,
      total_usd = EXCLUDED.total_usd,
      status = 'paid',
      paid_at = now();

    v_paid := v_paid + 1;
  END LOOP;

  RETURN json_build_object('success', true, 'period', p_period_yyyy_mm, 'bds_paid', v_paid);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_county_admin_center()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_staff public.business_staff%ROWTYPE;
  v_bds json;
  v_agencies json;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_staff FROM public.business_staff
  WHERE user_id = v_uid AND is_active = true
    AND public.normalize_staff_role(role) = 'county_admin'
  LIMIT 1;

  IF v_staff.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'County Admin only');
  END IF;

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_bds
  FROM (
    SELECT bs.id, bs.staff_code, bs.role, u.username, u.short_id, u.avatar_url
    FROM public.business_staff bs
    JOIN public.users u ON u.id = bs.user_id
    WHERE bs.parent_staff_id = v_staff.id AND bs.is_active
      AND public.normalize_staff_role(bs.role) = 'bd'
    ORDER BY bs.created_at DESC
  ) t;

  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_agencies
  FROM (
    SELECT a.id, a.name, a.agency_code, a.is_active, a.sponsor_staff_id, bs.staff_code AS bd_code
    FROM public.agencies a
    JOIN public.business_staff bs ON bs.id = a.sponsor_staff_id
    WHERE bs.parent_staff_id = v_staff.id AND a.is_active
    ORDER BY a.created_at DESC
  ) t;

  RETURN json_build_object(
    'success', true,
    'staff', json_build_object(
      'id', v_staff.id,
      'staff_code', v_staff.staff_code,
      'role', 'county_admin'
    ),
    'bds', v_bds,
    'agencies', v_agencies
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_host_period_target(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_agency_period_targets(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_bd_center(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_county_admin_center() TO authenticated;
GRANT EXECUTE ON FUNCTION public.county_admin_activate_bd(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.county_admin_activate_agency(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_bd_monthly_stats(uuid, text) TO authenticated;
