-- Agency Center menu: announcement, member roles, notices

ALTER TABLE public.agencies
  ADD COLUMN IF NOT EXISTS announcement text;

ALTER TABLE public.agency_members
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'host';

DO $$
BEGIN
  ALTER TABLE public.agency_members DROP CONSTRAINT IF EXISTS agency_members_role_check;
  ALTER TABLE public.agency_members
    ADD CONSTRAINT agency_members_role_check
    CHECK (role = ANY (ARRAY['host'::text, 'admin'::text]));
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'agency_members role check skipped: %', SQLERRM;
END $$;

CREATE TABLE IF NOT EXISTS public.agency_notices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id uuid NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agency_notices_agency_created
  ON public.agency_notices(agency_id, created_at DESC);

ALTER TABLE public.agency_notices ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_agency_owner_or_admin(p_agency_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.agencies a
    WHERE a.id = p_agency_id AND a.owner_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.agency_members m
    WHERE m.agency_id = p_agency_id
      AND m.user_id = auth.uid()
      AND m.role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_agency_member(p_agency_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.agencies a
    WHERE a.id = p_agency_id AND a.owner_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.agency_members m
    WHERE m.agency_id = p_agency_id AND m.user_id = auth.uid()
  );
$$;

DROP POLICY IF EXISTS "Members read agency notices" ON public.agency_notices;
CREATE POLICY "Members read agency notices"
  ON public.agency_notices FOR SELECT TO authenticated
  USING (public.is_agency_member(agency_id));

DROP POLICY IF EXISTS "Owner admin insert agency notices" ON public.agency_notices;
CREATE POLICY "Owner admin insert agency notices"
  ON public.agency_notices FOR INSERT TO authenticated
  WITH CHECK (public.is_agency_owner_or_admin(agency_id) AND author_id = auth.uid());

DROP POLICY IF EXISTS "Owner admin delete agency notices" ON public.agency_notices;
CREATE POLICY "Owner admin delete agency notices"
  ON public.agency_notices FOR DELETE TO authenticated
  USING (public.is_agency_owner_or_admin(agency_id));

-- Resolve agency access for current user (owner or admin member)
CREATE OR REPLACE FUNCTION public.get_my_agency_center()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_agency public.agencies%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_agency FROM public.agencies WHERE owner_id = v_uid LIMIT 1;
  IF FOUND THEN
    RETURN json_build_object(
      'success', true,
      'access_role', 'owner',
      'agency', row_to_json(v_agency)
    );
  END IF;

  SELECT a.*
  INTO v_agency
  FROM public.agency_members m
  JOIN public.agencies a ON a.id = m.agency_id
  WHERE m.user_id = v_uid AND m.role = 'admin'
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'No agency access');
  END IF;

  RETURN json_build_object(
    'success', true,
    'access_role', 'admin',
    'agency', row_to_json(v_agency)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_agency_member_role(
  p_agency_id uuid,
  p_user_id uuid,
  p_role text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF p_role IS NULL OR p_role NOT IN ('host', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid role');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.agencies WHERE id = p_agency_id AND owner_id = v_uid
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Only owner can change roles');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.agencies WHERE id = p_agency_id AND owner_id = p_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Cannot change owner role');
  END IF;

  UPDATE public.agency_members
  SET role = p_role
  WHERE agency_id = p_agency_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Member not found');
  END IF;

  RETURN json_build_object('success', true, 'message', 'Role updated', 'role', p_role);
END;
$function$;

CREATE OR REPLACE FUNCTION public.post_agency_notice(
  p_agency_id uuid,
  p_title text,
  p_body text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  IF NOT public.is_agency_owner_or_admin(p_agency_id) THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  IF p_title IS NULL OR trim(p_title) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Title required');
  END IF;

  INSERT INTO public.agency_notices (agency_id, author_id, title, body)
  VALUES (p_agency_id, v_uid, trim(p_title), COALESCE(p_body, ''))
  RETURNING id INTO v_id;

  RETURN json_build_object('success', true, 'id', v_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.is_agency_owner_or_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_agency_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_agency_center() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_agency_member_role(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.post_agency_notice(uuid, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
