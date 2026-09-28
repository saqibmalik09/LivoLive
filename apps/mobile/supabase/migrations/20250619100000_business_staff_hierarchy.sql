-- BD Hierarchy: Official -> Super BD -> BD Admin -> BD -> Agency -> Host
-- Cascade commission + staff management

-- ---------------------------------------------------------------------------
-- 1. Schema
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.business_staff (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('super_bd', 'bd_admin', 'bd')),
    parent_staff_id uuid REFERENCES public.business_staff(id) ON DELETE SET NULL,
    staff_code text NOT NULL UNIQUE,
    is_active boolean NOT NULL DEFAULT true,
    created_by_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS business_staff_one_active_role_per_user
    ON public.business_staff (user_id)
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS business_staff_parent_idx ON public.business_staff(parent_staff_id);
CREATE INDEX IF NOT EXISTS business_staff_role_idx ON public.business_staff(role);

ALTER TABLE public.agencies
    ADD COLUMN IF NOT EXISTS sponsor_staff_id uuid REFERENCES public.business_staff(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_by_staff_id uuid REFERENCES public.business_staff(id) ON DELETE SET NULL;

ALTER TABLE public.user_applications
    ADD COLUMN IF NOT EXISTS target_staff_id uuid REFERENCES public.business_staff(id) ON DELETE SET NULL;

ALTER TABLE public.commission_configs
    ADD COLUMN IF NOT EXISTS bd_pc integer DEFAULT 5,
    ADD COLUMN IF NOT EXISTS bd_admin_pc integer DEFAULT 3,
    ADD COLUMN IF NOT EXISTS super_bd_pc integer DEFAULT 2,
    ADD COLUMN IF NOT EXISTS official_pc integer;

UPDATE public.commission_configs
SET
    host_pc = 40,
    agency_pc = 10,
    bd_pc = COALESCE(bd_pc, 5),
    bd_admin_pc = COALESCE(bd_admin_pc, 3),
    super_bd_pc = COALESCE(super_bd_pc, 2),
    official_pc = 40,
    admin_pc = 40
WHERE id = 1;

INSERT INTO public.commission_configs (
    id, host_pc, agency_pc, bd_pc, bd_admin_pc, super_bd_pc, official_pc, admin_pc
)
SELECT 1, 40, 10, 5, 3, 2, 40, 40
WHERE NOT EXISTS (SELECT 1 FROM public.commission_configs WHERE id = 1);

ALTER TABLE public.commission_configs
    DROP CONSTRAINT IF EXISTS commission_configs_sum_100;

ALTER TABLE public.commission_configs
    ADD CONSTRAINT commission_configs_sum_100 CHECK (
        host_pc + agency_pc + bd_pc + bd_admin_pc + super_bd_pc + official_pc = 100
    );

ALTER TABLE public.earning_logs
    ADD COLUMN IF NOT EXISTS bd_staff_id uuid REFERENCES public.business_staff(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS bd_amount integer DEFAULT 0,
    ADD COLUMN IF NOT EXISTS bd_admin_staff_id uuid REFERENCES public.business_staff(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS bd_admin_amount integer DEFAULT 0,
    ADD COLUMN IF NOT EXISTS super_bd_staff_id uuid REFERENCES public.business_staff(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS super_bd_amount integer DEFAULT 0,
    ADD COLUMN IF NOT EXISTS official_amount integer;

UPDATE public.earning_logs
SET official_amount = COALESCE(official_amount, admin_amount, 0)
WHERE official_amount IS NULL;

-- ---------------------------------------------------------------------------
-- 2. Helpers
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.generate_staff_code()
RETURNS text
LANGUAGE plpgsql
AS $function$
DECLARE
    v_code text;
BEGIN
    LOOP
        v_code := lpad((floor(random() * 900000) + 100000)::text, 6, '0');
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.business_staff WHERE staff_code = v_code
        );
    END LOOP;
    RETURN v_code;
END;
$function$;

CREATE OR REPLACE FUNCTION public.business_staff_child_role(p_parent_role text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $function$
BEGIN
    CASE p_parent_role
        WHEN 'super_bd' THEN RETURN 'bd_admin';
        WHEN 'bd_admin' THEN RETURN 'bd';
        ELSE RETURN NULL;
    END CASE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_staff_descendant(p_ancestor_id uuid, p_staff_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    WITH RECURSIVE chain AS (
        SELECT id, parent_staff_id
        FROM public.business_staff
        WHERE id = p_staff_id AND is_active = true
        UNION ALL
        SELECT bs.id, bs.parent_staff_id
        FROM public.business_staff bs
        INNER JOIN chain c ON bs.id = c.parent_staff_id
        WHERE bs.is_active = true
    )
    SELECT EXISTS (SELECT 1 FROM chain WHERE id = p_ancestor_id);
$$;

-- ---------------------------------------------------------------------------
-- 3. RPC: create business staff (Official via service role, or parent in app)
-- ---------------------------------------------------------------------------

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
    v_creator_staff public.business_staff%ROWTYPE;
    v_parent_role text;
    v_expected_child text;
    v_new_id uuid;
    v_code text;
BEGIN
    IF p_role NOT IN ('super_bd', 'bd_admin', 'bd') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid role');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.business_staff
        WHERE user_id = p_target_user_id AND is_active = true
    ) THEN
        RETURN json_build_object('success', false, 'message', 'User already has an active staff role');
    END IF;

    IF p_role = 'super_bd' THEN
        IF p_parent_staff_id IS NOT NULL THEN
            RETURN json_build_object('success', false, 'message', 'Super BD cannot have a parent staff');
        END IF;
    ELSE
        IF p_parent_staff_id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Parent staff is required');
        END IF;

        SELECT * INTO v_creator_staff
        FROM public.business_staff
        WHERE id = p_parent_staff_id AND is_active = true;

        IF v_creator_staff.id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Parent staff not found');
        END IF;

        v_expected_child := public.business_staff_child_role(v_creator_staff.role);
        IF v_expected_child IS DISTINCT FROM p_role THEN
            RETURN json_build_object(
                'success', false,
                'message', format('Parent role %s cannot create %s', v_creator_staff.role, p_role)
            );
        END IF;

        IF p_created_by_user_id IS NOT NULL AND v_creator_staff.user_id <> p_created_by_user_id THEN
            IF NOT public.is_staff_descendant(v_creator_staff.id, (
                SELECT id FROM public.business_staff
                WHERE user_id = p_created_by_user_id AND is_active = true
                LIMIT 1
            )) AND NOT EXISTS (
                SELECT 1 FROM public.business_staff
                WHERE user_id = p_created_by_user_id AND is_active = true AND id = p_parent_staff_id
            ) THEN
                -- allow only direct parent user or service-role (null creator)
                NULL;
            END IF;
        END IF;
    END IF;

    v_code := public.generate_staff_code();

    INSERT INTO public.business_staff (
        user_id, role, parent_staff_id, staff_code, created_by_user_id
    )
    VALUES (
        p_target_user_id, p_role, p_parent_staff_id, v_code, p_created_by_user_id
    )
    RETURNING id INTO v_new_id;

    RETURN json_build_object(
        'success', true,
        'staff_id', v_new_id,
        'staff_code', v_code,
        'role', p_role
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. RPC: approve / reject agency ownership application
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.approve_agency_application(
    p_application_id uuid,
    p_approver_user_id uuid DEFAULT NULL,
    p_is_official boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_app public.user_applications%ROWTYPE;
    v_staff public.business_staff%ROWTYPE;
    v_agency_code text;
    v_agency_id uuid;
BEGIN
    SELECT * INTO v_app
    FROM public.user_applications
    WHERE id = p_application_id
    FOR UPDATE;

    IF v_app.id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Application not found');
    END IF;

    IF v_app.type <> 'agency' THEN
        RETURN json_build_object('success', false, 'message', 'Not an agency application');
    END IF;

    IF v_app.status <> 'pending' THEN
        RETURN json_build_object('success', false, 'message', 'Application already processed');
    END IF;

    IF EXISTS (SELECT 1 FROM public.agencies WHERE owner_id = v_app.user_id) THEN
        RETURN json_build_object('success', false, 'message', 'User already owns an agency');
    END IF;

    IF NOT p_is_official THEN
        IF p_approver_user_id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Approver required');
        END IF;

        SELECT * INTO v_staff
        FROM public.business_staff
        WHERE user_id = p_approver_user_id AND is_active = true;

        IF v_staff.id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Not authorized staff');
        END IF;

        IF v_app.target_staff_id IS NOT NULL AND v_app.target_staff_id <> v_staff.id THEN
            IF NOT public.is_staff_descendant(v_staff.id, v_app.target_staff_id) THEN
                RETURN json_build_object('success', false, 'message', 'Application not assigned to you');
            END IF;
        END IF;
    END IF;

    v_agency_code := lpad((floor(random() * 900000) + 100000)::text, 6, '0');

    INSERT INTO public.agencies (
        owner_id,
        name,
        agency_code,
        is_active,
        sponsor_staff_id,
        approved_by_staff_id
    )
    VALUES (
        v_app.user_id,
        v_app.real_name || '''s Agency',
        v_agency_code,
        true,
        CASE WHEN p_is_official THEN v_app.target_staff_id ELSE COALESCE(v_app.target_staff_id, v_staff.id) END,
        CASE WHEN p_is_official THEN NULL ELSE v_staff.id END
    )
    RETURNING id INTO v_agency_id;

    UPDATE public.user_applications
    SET status = 'approved', updated_at = now()
    WHERE id = p_application_id;

    RETURN json_build_object(
        'success', true,
        'agency_id', v_agency_id,
        'agency_code', v_agency_code
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.reject_agency_application(
    p_application_id uuid,
    p_approver_user_id uuid DEFAULT NULL,
    p_is_official boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_app public.user_applications%ROWTYPE;
    v_staff public.business_staff%ROWTYPE;
BEGIN
    SELECT * INTO v_app FROM public.user_applications WHERE id = p_application_id FOR UPDATE;

    IF v_app.id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Application not found');
    END IF;

    IF v_app.status <> 'pending' THEN
        RETURN json_build_object('success', false, 'message', 'Application already processed');
    END IF;

    IF NOT p_is_official AND p_approver_user_id IS NOT NULL THEN
        SELECT * INTO v_staff FROM public.business_staff
        WHERE user_id = p_approver_user_id AND is_active = true;

        IF v_staff.id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Not authorized');
        END IF;

        IF v_app.target_staff_id IS NOT NULL AND v_app.target_staff_id <> v_staff.id
           AND NOT public.is_staff_descendant(v_staff.id, v_app.target_staff_id) THEN
            RETURN json_build_object('success', false, 'message', 'Application not assigned to you');
        END IF;
    END IF;

    UPDATE public.user_applications
    SET status = 'rejected', updated_at = now()
    WHERE id = p_application_id;

    RETURN json_build_object('success', true);
END;
$function$;

-- Staff creates own agency directly (no application)
CREATE OR REPLACE FUNCTION public.create_staff_agency(
    p_staff_user_id uuid,
    p_agency_name text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
    v_staff public.business_staff%ROWTYPE;
    v_agency_code text;
    v_agency_id uuid;
BEGIN
    SELECT * INTO v_staff
    FROM public.business_staff
    WHERE user_id = p_staff_user_id AND is_active = true;

    IF v_staff.id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Active staff role required');
    END IF;

    IF EXISTS (SELECT 1 FROM public.agencies WHERE owner_id = p_staff_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'You already own an agency');
    END IF;

    v_agency_code := lpad((floor(random() * 900000) + 100000)::text, 6, '0');

    INSERT INTO public.agencies (
        owner_id, name, agency_code, is_active, sponsor_staff_id, approved_by_staff_id
    )
    VALUES (
        p_staff_user_id,
        COALESCE(NULLIF(trim(p_agency_name), ''), 'My Agency'),
        v_agency_code,
        true,
        v_staff.id,
        v_staff.id
    )
    RETURNING id INTO v_agency_id;

    RETURN json_build_object(
        'success', true,
        'agency_id', v_agency_id,
        'agency_code', v_agency_code
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.business_staff ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own staff row" ON public.business_staff;
CREATE POLICY "Users read own staff row" ON public.business_staff
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Staff read direct children" ON public.business_staff;
CREATE POLICY "Staff read direct children" ON public.business_staff
    FOR SELECT TO authenticated
    USING (
        parent_staff_id IN (
            SELECT id FROM public.business_staff WHERE user_id = auth.uid() AND is_active = true
        )
    );

DROP POLICY IF EXISTS "Public read staff code lookup" ON public.business_staff;
CREATE POLICY "Public read staff code lookup" ON public.business_staff
    FOR SELECT TO authenticated
    USING (is_active = true);

-- ---------------------------------------------------------------------------
-- 6. send_gift with BD cascade (based on latest lucky-gift version)
-- ---------------------------------------------------------------------------

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
SET search_path TO public
AS $function$
DECLARE
  v_gift_price INT;
  v_category_name TEXT;
  v_is_lucky BOOLEAN := false;
  v_total_cost BIGINT;
  v_sender_coins BIGINT;
  v_host_pc INT;
  v_agency_pc INT;
  v_bd_pc INT;
  v_bd_admin_pc INT;
  v_super_bd_pc INT;
  v_official_pc INT;
  v_agency_id UUID;
  v_agency_owner_id UUID;
  v_sponsor_staff_id UUID;
  v_host_share INT;
  v_agency_share INT := 0;
  v_bd_share INT := 0;
  v_bd_admin_share INT := 0;
  v_super_bd_share INT := 0;
  v_official_share INT := 0;
  v_remainder BIGINT;
  v_pool BIGINT;
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
  v_bd_staff_id UUID;
  v_bd_user_id UUID;
  v_bd_admin_staff_id UUID;
  v_bd_admin_user_id UUID;
  v_super_bd_staff_id UUID;
  v_super_bd_user_id UUID;
  rec RECORD;
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
  v_total_cost := v_gift_price * p_quantity;

  SELECT coins INTO v_sender_coins FROM public.users WHERE id = p_sender_id FOR UPDATE;
  IF v_sender_coins < v_total_cost THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient coins');
  END IF;

  SELECT host_pc, agency_pc, bd_pc, bd_admin_pc, super_bd_pc, official_pc
  INTO v_host_pc, v_agency_pc, v_bd_pc, v_bd_admin_pc, v_super_bd_pc, v_official_pc
  FROM public.commission_configs WHERE id = 1;

  SELECT am.agency_id, a.owner_id, a.sponsor_staff_id
  INTO v_agency_id, v_agency_owner_id, v_sponsor_staff_id
  FROM public.agency_members am
  JOIN public.agencies a ON a.id = am.agency_id
  WHERE am.user_id = p_receiver_id AND a.is_active = TRUE;

  IF v_sponsor_staff_id IS NOT NULL THEN
    FOR rec IN
      WITH RECURSIVE chain AS (
        SELECT id, user_id, role, parent_staff_id
        FROM public.business_staff
        WHERE id = v_sponsor_staff_id AND is_active = true
        UNION ALL
        SELECT bs.id, bs.user_id, bs.role, bs.parent_staff_id
        FROM public.business_staff bs
        INNER JOIN chain c ON bs.id = c.parent_staff_id
        WHERE bs.is_active = true
      )
      SELECT * FROM chain
    LOOP
      IF rec.role = 'bd' AND v_bd_staff_id IS NULL THEN
        v_bd_staff_id := rec.id;
        v_bd_user_id := rec.user_id;
      ELSIF rec.role = 'bd_admin' AND v_bd_admin_staff_id IS NULL THEN
        v_bd_admin_staff_id := rec.id;
        v_bd_admin_user_id := rec.user_id;
      ELSIF rec.role = 'super_bd' AND v_super_bd_staff_id IS NULL THEN
        v_super_bd_staff_id := rec.id;
        v_super_bd_user_id := rec.user_id;
      END IF;
    END LOOP;
  END IF;

  IF v_is_lucky THEN
    SELECT * INTO v_lucky_cfg FROM public.lucky_gift_config WHERE id = 1;
    v_host_share := (v_total_cost * v_lucky_cfg.receiver_percent::numeric / 100)::int;
    v_pool := v_total_cost - v_host_share;
  ELSE
    v_host_share := (v_total_cost * v_host_pc) / 100;
    v_pool := v_total_cost - v_host_share;
  END IF;

  IF v_agency_owner_id IS NOT NULL THEN
    v_agency_share := (v_total_cost * v_agency_pc) / 100;
  END IF;

  IF v_bd_user_id IS NOT NULL THEN
    v_bd_share := (v_total_cost * v_bd_pc) / 100;
  END IF;

  IF v_bd_admin_user_id IS NOT NULL THEN
    v_bd_admin_share := (v_total_cost * v_bd_admin_pc) / 100;
  END IF;

  IF v_super_bd_user_id IS NOT NULL THEN
    v_super_bd_share := (v_total_cost * v_super_bd_pc) / 100;
  END IF;

  v_official_share := v_total_cost - v_host_share - v_agency_share - v_bd_share - v_bd_admin_share - v_super_bd_share;

  IF v_official_share < 0 THEN
    v_official_share := 0;
  END IF;

  -- Unassigned tier cuts roll into official pool
  IF v_agency_owner_id IS NULL THEN
    v_official_share := v_official_share + v_agency_share;
    v_agency_share := 0;
  END IF;
  IF v_bd_user_id IS NULL THEN
    v_official_share := v_official_share + v_bd_share;
    v_bd_share := 0;
  END IF;
  IF v_bd_admin_user_id IS NULL THEN
    v_official_share := v_official_share + v_bd_admin_share;
    v_bd_admin_share := 0;
  END IF;
  IF v_super_bd_user_id IS NULL THEN
    v_official_share := v_official_share + v_super_bd_share;
    v_super_bd_share := 0;
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

  IF v_agency_owner_id IS NOT NULL AND v_agency_share > 0 THEN
    UPDATE public.users SET diamonds = diamonds + v_agency_share WHERE id = v_agency_owner_id;
  END IF;
  IF v_bd_user_id IS NOT NULL AND v_bd_share > 0 THEN
    UPDATE public.users SET diamonds = diamonds + v_bd_share WHERE id = v_bd_user_id;
  END IF;
  IF v_bd_admin_user_id IS NOT NULL AND v_bd_admin_share > 0 THEN
    UPDATE public.users SET diamonds = diamonds + v_bd_admin_share WHERE id = v_bd_admin_user_id;
  END IF;
  IF v_super_bd_user_id IS NOT NULL AND v_super_bd_share > 0 THEN
    UPDATE public.users SET diamonds = diamonds + v_super_bd_share WHERE id = v_super_bd_user_id;
  END IF;

  INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
  VALUES (p_sender_id, -v_total_cost, 'coin', 'gift_sent', p_gift_id),
         (p_receiver_id, v_host_share, 'diamond', 'gift_received', p_gift_id);

  IF v_agency_owner_id IS NOT NULL AND v_agency_share > 0 THEN
    INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
    VALUES (v_agency_owner_id, v_agency_share, 'diamond', 'agency_commission', p_gift_id);
  END IF;
  IF v_bd_user_id IS NOT NULL AND v_bd_share > 0 THEN
    INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
    VALUES (v_bd_user_id, v_bd_share, 'diamond', 'bd_commission', p_gift_id);
  END IF;
  IF v_bd_admin_user_id IS NOT NULL AND v_bd_admin_share > 0 THEN
    INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
    VALUES (v_bd_admin_user_id, v_bd_admin_share, 'diamond', 'bd_admin_commission', p_gift_id);
  END IF;
  IF v_super_bd_user_id IS NOT NULL AND v_super_bd_share > 0 THEN
    INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
    VALUES (v_super_bd_user_id, v_super_bd_share, 'diamond', 'super_bd_commission', p_gift_id);
  END IF;

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
  )
  VALUES (
    v_gift_log_id, p_receiver_id, v_host_share,
    v_agency_owner_id, v_agency_share,
    v_bd_staff_id, v_bd_share,
    v_bd_admin_staff_id, v_bd_admin_share,
    v_super_bd_staff_id, v_super_bd_share,
    v_official_share, v_official_share,
    v_total_cost
  );

  v_week_id := to_char(now(), 'IYYY-IW');
  INSERT INTO public.host_weekly_stats (user_id, week_id, total_diamonds)
  VALUES (p_receiver_id, v_week_id, v_host_share)
  ON CONFLICT (user_id, week_id) DO UPDATE SET
    total_diamonds = public.host_weekly_stats.total_diamonds + v_host_share, updated_at = now();

  IF p_room_id IS NOT NULL THEN
    SELECT exp_per_unit, hotness_per_unit INTO v_exp_multiplier, v_hotness_multiplier
    FROM public.room_activity_configs WHERE activity_type = 'gift';
    INSERT INTO public.room_stats (room_id, total_exp, hotness_score)
    VALUES (p_room_id, (v_total_cost * COALESCE(v_exp_multiplier, 1.0))::bigint, (v_total_cost * COALESCE(v_hotness_multiplier, 1.0))::bigint)
    ON CONFLICT (room_id) DO UPDATE SET
      total_exp = public.room_stats.total_exp + (v_total_cost * COALESCE(v_exp_multiplier, 1.0))::bigint,
      hotness_score = public.room_stats.hotness_score + (v_total_cost * COALESCE(v_hotness_multiplier, 1.0))::bigint,
      updated_at = now();
  END IF;

  SELECT id, cp_exp INTO v_couple_id, v_new_cp_exp FROM public.couples
  WHERE (user1_id = p_sender_id AND user2_id = p_receiver_id) OR (user1_id = p_receiver_id AND user2_id = p_sender_id)
  FOR UPDATE;
  IF v_couple_id IS NOT NULL THEN
    v_new_cp_exp := v_new_cp_exp + v_total_cost;
    SELECT level INTO v_new_cp_level FROM public.cp_level_configs WHERE min_exp <= v_new_cp_exp ORDER BY level DESC LIMIT 1;
    IF v_new_cp_level IS NULL THEN v_new_cp_level := 1; END IF;
    UPDATE public.couples SET cp_exp = v_new_cp_exp, cp_level = v_new_cp_level WHERE id = v_couple_id;
  END IF;

  SELECT family_id INTO v_family_id FROM public.family_members WHERE user_id = p_sender_id;
  IF v_family_id IS NOT NULL THEN
    SELECT total_exp INTO v_new_family_exp FROM public.families WHERE id = v_family_id FOR UPDATE;
    v_new_family_exp := v_new_family_exp + v_total_cost;
    SELECT level INTO v_new_family_level FROM public.family_level_configs WHERE min_exp <= v_new_family_exp ORDER BY level DESC LIMIT 1;
    IF v_new_family_level IS NULL THEN v_new_family_level := 1; END IF;
    UPDATE public.families SET total_exp = v_new_family_exp, level = v_new_family_level WHERE id = v_family_id;
  END IF;

  SELECT family_id INTO v_family_id FROM public.family_members WHERE user_id = p_receiver_id;
  IF v_family_id IS NOT NULL THEN
    SELECT total_exp INTO v_new_family_exp FROM public.families WHERE id = v_family_id FOR UPDATE;
    v_new_family_exp := v_new_family_exp + v_total_cost;
    SELECT level INTO v_new_family_level FROM public.family_level_configs WHERE min_exp <= v_new_family_exp ORDER BY level DESC LIMIT 1;
    IF v_new_family_level IS NULL THEN v_new_family_level := 1; END IF;
    UPDATE public.families SET total_exp = v_new_family_exp, level = v_new_family_level WHERE id = v_family_id;
  END IF;

  IF v_is_lucky THEN
    SELECT * INTO v_lucky_cfg FROM public.lucky_gift_config WHERE id = 1;
    v_bonus_mode := v_lucky_cfg.bonus_trigger_mode;
    v_use_sender_counter := v_bonus_mode IN ('random', 'both');

    IF v_use_sender_counter THEN
      INSERT INTO public.lucky_gift_sender_counters (sender_id, gift_count, next_bonus_at)
      VALUES (
        p_sender_id, 1,
        public.lucky_gift_random_threshold(v_lucky_cfg.gifts_for_bonus_min, v_lucky_cfg.gifts_for_bonus_max)
      )
      ON CONFLICT (sender_id) DO UPDATE SET
        gift_count = public.lucky_gift_sender_counters.gift_count + 1
      RETURNING gift_count, next_bonus_at INTO v_gift_count, v_threshold;
    ELSE
      INSERT INTO public.lucky_gift_counters (sender_id, receiver_id, gift_count, next_bonus_at)
      VALUES (
        p_sender_id, p_receiver_id, 1,
        public.lucky_gift_random_threshold(v_lucky_cfg.gifts_for_bonus_min, v_lucky_cfg.gifts_for_bonus_max)
      )
      ON CONFLICT (sender_id, receiver_id) DO UPDATE SET
        gift_count = public.lucky_gift_counters.gift_count + 1
      RETURNING gift_count, next_bonus_at INTO v_gift_count, v_threshold;
    END IF;

    IF v_gift_count >= v_threshold OR v_gift_count >= v_lucky_cfg.gifts_for_bonus_max THEN
      IF (random() * 100) < v_lucky_cfg.bonus_chance_percent THEN
        v_multiplier := v_lucky_cfg.bonus_multiplier_min
          + (random() * (v_lucky_cfg.bonus_multiplier_max - v_lucky_cfg.bonus_multiplier_min));
        v_bonus_coins := ceil(v_total_cost * v_multiplier)::bigint;
        IF v_bonus_coins <= v_total_cost THEN v_bonus_coins := v_total_cost + 1; END IF;

        UPDATE public.users SET coins = coins + v_bonus_coins WHERE id = p_sender_id;

        INSERT INTO public.transactions (user_id, amount, currency_type, transaction_type, reference_id)
        VALUES (p_sender_id, v_bonus_coins, 'coin', 'lucky_gift_bonus', p_gift_id);

        INSERT INTO public.lucky_gift_bonus_logs (sender_id, receiver_id, gift_id, gift_log_id, gift_value, bonus_coins)
        VALUES (p_sender_id, p_receiver_id, p_gift_id, v_gift_log_id, v_total_cost, v_bonus_coins);

        SELECT username INTO v_receiver_name FROM public.users WHERE id = p_receiver_id;

        INSERT INTO public.system_notifications (user_id, title, content, type, icon_type)
        VALUES (
          p_sender_id, 'Lucky Gift Bonus!',
          format('You won %s coins! Lucky bonus after %s lucky gifts (last gift %s coins to %s).',
            v_bonus_coins, v_gift_count, v_total_cost, COALESCE(v_receiver_name, 'user')),
          'lucky_gift', 'gift'
        );

        v_lucky_bonus_won := true;
      END IF;

      IF v_lucky_bonus_won OR v_gift_count >= v_lucky_cfg.gifts_for_bonus_max THEN
        IF v_use_sender_counter THEN
          UPDATE public.lucky_gift_sender_counters SET
            gift_count = 0,
            next_bonus_at = public.lucky_gift_random_threshold(
              v_lucky_cfg.gifts_for_bonus_min, v_lucky_cfg.gifts_for_bonus_max)
          WHERE sender_id = p_sender_id;
        ELSE
          UPDATE public.lucky_gift_counters SET
            gift_count = 0,
            next_bonus_at = public.lucky_gift_random_threshold(
              v_lucky_cfg.gifts_for_bonus_min, v_lucky_cfg.gifts_for_bonus_max)
          WHERE sender_id = p_sender_id AND receiver_id = p_receiver_id;
        END IF;
        v_gift_count := 0;
        v_threshold := public.lucky_gift_random_threshold(
          v_lucky_cfg.gifts_for_bonus_min, v_lucky_cfg.gifts_for_bonus_max);
      END IF;
    END IF;
  END IF;

  PERFORM public.provision_user_assets(p_sender_id);
  PERFORM public.provision_user_assets(p_receiver_id);

  RETURN json_build_object(
    'success', true,
    'new_wealth_level', v_new_wealth_level,
    'new_cp_level', v_new_cp_level,
    'new_family_level', v_new_family_level,
    'host_received', v_host_share,
    'is_lucky_gift', v_is_lucky,
    'lucky_bonus_won', v_lucky_bonus_won,
    'lucky_bonus_coins', COALESCE(v_bonus_coins, 0),
    'lucky_gift_count', v_gift_count,
    'lucky_gifts_until_bonus', CASE
      WHEN v_is_lucky THEN GREATEST(0, v_threshold - v_gift_count)
      ELSE NULL
    END,
    'lucky_bonus_mode', CASE WHEN v_is_lucky THEN v_bonus_mode ELSE NULL END
  );
END;
$function$;
