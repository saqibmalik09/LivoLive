-- Real Name Verification (KYC) flow

-- ---------------------------------------------------------------------------
-- Expand transactions for security deposit
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
      'task_reward'::text,
      'cash_exchange_self'::text,
      'cash_exchange_other_out'::text,
      'cash_exchange_other_in'::text,
      'withdrawal_hold'::text,
      'withdrawal_refund'::text,
      'real_name_deposit'::text
    ]));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'transactions check update skipped: %', SQLERRM;
END $$;

-- ---------------------------------------------------------------------------
-- Deposit / role packages
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.real_name_deposit_packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  package_key text NOT NULL UNIQUE,
  title text NOT NULL,
  price_coins bigint NOT NULL CHECK (price_coins > 0),
  kind text NOT NULL DEFAULT 'deposit'
    CHECK (kind IN ('deposit', 'role')),
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.real_name_deposit_packages (package_key, title, price_coins, kind, sort_order)
VALUES
  ('super_country_admin', 'Super Country Admin', 300000000, 'deposit', 1),
  ('country_admin', 'Country Admin', 50000000, 'deposit', 2),
  ('country_assistant', 'Country Assistant', 30000000, 'deposit', 3),
  ('super_coin_seller', 'Super Coin Seller', 300000000, 'deposit', 4),
  ('role_country_admin', 'Country Admin', 50000000, 'role', 1),
  ('role_country_assistant', 'Country Assistant', 30000000, 'role', 2),
  ('role_super_coin_seller', 'Super Coin Seller', 300000000, 'role', 3),
  ('role_country_coin_seller', 'Country Coin Seller', 30000000, 'role', 4)
ON CONFLICT (package_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Applications (one row per user)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.real_name_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'pending', 'approved', 'rejected')),

  -- STEP1 personal
  step1_done boolean NOT NULL DEFAULT false,
  country text,
  telephone text,
  whatsapp text,
  age int,
  years_of_work text,
  how_know_app text,
  proof_external_app_url text,
  proof_work_account_url text,
  proof_work_results_url text,

  -- STEP2 identity
  step2_done boolean NOT NULL DEFAULT false,
  legal_name text,
  residential_address text,
  document_number text,
  id_photo_front_url text,
  id_photo_back_url text,

  -- STEP3 video
  step3_done boolean NOT NULL DEFAULT false,
  video_auth_url text,

  -- STEP4 deposit
  step4_done boolean NOT NULL DEFAULT false,
  deposit_package_id uuid REFERENCES public.real_name_deposit_packages(id),
  deposit_coins bigint,
  deposit_paid_at timestamptz,

  -- STEP5 role
  step5_done boolean NOT NULL DEFAULT false,
  role_package_id uuid REFERENCES public.real_name_deposit_packages(id),

  reviewed_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  reject_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_real_name_applications_status
  ON public.real_name_applications (status, updated_at DESC);

ALTER TABLE public.real_name_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.real_name_deposit_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own real_name app" ON public.real_name_applications;
CREATE POLICY "Users read own real_name app"
  ON public.real_name_applications FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Public read real_name packages" ON public.real_name_deposit_packages;
CREATE POLICY "Public read real_name packages"
  ON public.real_name_deposit_packages FOR SELECT TO public USING (is_active = true);

-- Storage bucket (public read for admin/app simplicity)
INSERT INTO storage.buckets (id, name, public)
VALUES ('real_name_kyc', 'real_name_kyc', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Auth upload real_name_kyc" ON storage.objects;
CREATE POLICY "Auth upload real_name_kyc"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'real_name_kyc' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Auth update real_name_kyc" ON storage.objects;
CREATE POLICY "Auth update real_name_kyc"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'real_name_kyc' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Public read real_name_kyc" ON storage.objects;
CREATE POLICY "Public read real_name_kyc"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'real_name_kyc');

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._ensure_real_name_application(p_uid uuid)
RETURNS public.real_name_applications
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_row public.real_name_applications%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM public.real_name_applications WHERE user_id = p_uid;
  IF FOUND THEN
    RETURN v_row;
  END IF;
  INSERT INTO public.real_name_applications (user_id)
  VALUES (p_uid)
  RETURNING * INTO v_row;
  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_real_name_application()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.real_name_applications%ROWTYPE;
  v_user record;
  v_packages json;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  v_row := public._ensure_real_name_application(v_uid);

  SELECT id, username, short_id, avatar_url, coins, phone
  INTO v_user
  FROM public.users WHERE id = v_uid;

  SELECT COALESCE(json_agg(row_to_json(p) ORDER BY p.kind, p.sort_order), '[]'::json)
  INTO v_packages
  FROM public.real_name_deposit_packages p
  WHERE p.is_active;

  RETURN json_build_object(
    'success', true,
    'user', json_build_object(
      'id', v_user.id,
      'username', v_user.username,
      'short_id', v_user.short_id,
      'avatar_url', v_user.avatar_url,
      'coins', COALESCE(v_user.coins, 0),
      'phone', v_user.phone
    ),
    'application', row_to_json(v_row),
    'packages', v_packages
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_real_name_step(
  p_step text,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.real_name_applications%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  v_row := public._ensure_real_name_application(v_uid);

  IF v_row.status IN ('pending', 'approved') THEN
    RETURN json_build_object('success', false, 'message', 'Application locked');
  END IF;

  IF p_step = 'step1_personal' THEN
    UPDATE public.real_name_applications SET
      country = COALESCE(NULLIF(p_payload->>'country', ''), country),
      telephone = COALESCE(NULLIF(p_payload->>'telephone', ''), telephone),
      whatsapp = COALESCE(NULLIF(p_payload->>'whatsapp', ''), whatsapp),
      age = COALESCE((p_payload->>'age')::int, age),
      years_of_work = COALESCE(NULLIF(p_payload->>'years_of_work', ''), years_of_work),
      how_know_app = COALESCE(NULLIF(p_payload->>'how_know_app', ''), how_know_app),
      updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_row;

  ELSIF p_step = 'step1_proofs' THEN
    IF NULLIF(p_payload->>'proof_external_app_url', '') IS NULL
       OR NULLIF(p_payload->>'proof_work_account_url', '') IS NULL
       OR NULLIF(p_payload->>'proof_work_results_url', '') IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'All proof images required');
    END IF;
    UPDATE public.real_name_applications SET
      proof_external_app_url = p_payload->>'proof_external_app_url',
      proof_work_account_url = p_payload->>'proof_work_account_url',
      proof_work_results_url = p_payload->>'proof_work_results_url',
      step1_done = true,
      updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_row;

  ELSIF p_step = 'step2_identity' THEN
    IF NULLIF(p_payload->>'legal_name', '') IS NULL
       OR NULLIF(p_payload->>'residential_address', '') IS NULL
       OR NULLIF(p_payload->>'document_number', '') IS NULL
       OR NULLIF(p_payload->>'id_photo_front_url', '') IS NULL
       OR NULLIF(p_payload->>'id_photo_back_url', '') IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'All identity fields required');
    END IF;
    UPDATE public.real_name_applications SET
      legal_name = p_payload->>'legal_name',
      residential_address = p_payload->>'residential_address',
      document_number = p_payload->>'document_number',
      id_photo_front_url = p_payload->>'id_photo_front_url',
      id_photo_back_url = p_payload->>'id_photo_back_url',
      step2_done = true,
      updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_row;

  ELSIF p_step = 'step3_video' THEN
    IF NULLIF(p_payload->>'video_auth_url', '') IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Video required');
    END IF;
    UPDATE public.real_name_applications SET
      video_auth_url = p_payload->>'video_auth_url',
      step3_done = true,
      updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_row;

  ELSIF p_step = 'step5_role' THEN
    IF (p_payload->>'role_package_id')::uuid IS NULL THEN
      RETURN json_build_object('success', false, 'message', 'Select a role package');
    END IF;
    UPDATE public.real_name_applications SET
      role_package_id = (p_payload->>'role_package_id')::uuid,
      step5_done = true,
      updated_at = now()
    WHERE user_id = v_uid
    RETURNING * INTO v_row;

  ELSE
    RETURN json_build_object('success', false, 'message', 'Unknown step');
  END IF;

  RETURN json_build_object('success', true, 'application', row_to_json(v_row));
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_real_name_deposit(p_package_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.real_name_applications%ROWTYPE;
  v_pkg public.real_name_deposit_packages%ROWTYPE;
  v_coins bigint;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  v_row := public._ensure_real_name_application(v_uid);

  IF v_row.status IN ('pending', 'approved') THEN
    RETURN json_build_object('success', false, 'message', 'Application locked');
  END IF;

  IF v_row.step4_done THEN
    RETURN json_build_object('success', false, 'message', 'Deposit already paid');
  END IF;

  SELECT * INTO v_pkg
  FROM public.real_name_deposit_packages
  WHERE id = p_package_id AND is_active AND kind = 'deposit';
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Invalid package');
  END IF;

  SELECT COALESCE(coins, 0) INTO v_coins FROM public.users WHERE id = v_uid FOR UPDATE;
  IF v_coins < v_pkg.price_coins THEN
    RETURN json_build_object('success', false, 'message', 'Insufficient balance');
  END IF;

  UPDATE public.users
  SET coins = coins - v_pkg.price_coins
  WHERE id = v_uid;

  INSERT INTO public.transactions (
    user_id, amount, transaction_type, currency_type, reference_id, description
  ) VALUES (
    v_uid, v_pkg.price_coins, 'real_name_deposit', 'coin', v_row.id::text,
    'Real name security deposit: ' || v_pkg.title
  );

  UPDATE public.real_name_applications SET
    deposit_package_id = v_pkg.id,
    deposit_coins = v_pkg.price_coins,
    deposit_paid_at = now(),
    step4_done = true,
    updated_at = now()
  WHERE user_id = v_uid
  RETURNING * INTO v_row;

  RETURN json_build_object(
    'success', true,
    'application', row_to_json(v_row),
    'coins_left', v_coins - v_pkg.price_coins
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_real_name_for_review()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.real_name_applications%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_row FROM public.real_name_applications WHERE user_id = v_uid;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'No application');
  END IF;

  IF NOT (v_row.step1_done AND v_row.step2_done AND v_row.step3_done
           AND v_row.step4_done AND v_row.step5_done) THEN
    RETURN json_build_object('success', false, 'message', 'Complete all steps first');
  END IF;

  UPDATE public.real_name_applications SET
    status = 'pending',
    reject_reason = null,
    updated_at = now()
  WHERE user_id = v_uid
  RETURNING * INTO v_row;

  RETURN json_build_object('success', true, 'application', row_to_json(v_row));
END;
$$;

CREATE OR REPLACE FUNCTION public.review_real_name_application(
  p_application_id uuid,
  p_approve boolean,
  p_reject_reason text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.real_name_applications%ROWTYPE;
BEGIN
  -- Service role / admin panel uses supabaseAdmin; allow authenticated caller
  -- (admin Next.js uses service role which bypasses RLS; this RPC is for completeness)
  IF p_approve THEN
    UPDATE public.real_name_applications SET
      status = 'approved',
      reviewed_by = v_uid,
      reviewed_at = now(),
      reject_reason = null,
      updated_at = now()
    WHERE id = p_application_id
    RETURNING * INTO v_row;
  ELSE
    UPDATE public.real_name_applications SET
      status = 'rejected',
      reviewed_by = v_uid,
      reviewed_at = now(),
      reject_reason = COALESCE(p_reject_reason, 'Rejected'),
      updated_at = now()
    WHERE id = p_application_id
    RETURNING * INTO v_row;
  END IF;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Not found');
  END IF;

  RETURN json_build_object('success', true, 'application', row_to_json(v_row));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_real_name_application() TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_real_name_step(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_real_name_deposit(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_real_name_for_review() TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_real_name_application(uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_real_name_application(uuid, boolean, text) TO service_role;
