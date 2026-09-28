-- Track hosts who left or were removed from an agency

CREATE TABLE IF NOT EXISTS public.agency_member_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id uuid NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type = ANY (ARRAY['left'::text, 'removed'::text])),
  actor_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agency_member_events_agency_created
  ON public.agency_member_events(agency_id, created_at DESC);

ALTER TABLE public.agency_member_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner admin read agency member events" ON public.agency_member_events;
CREATE POLICY "Owner admin read agency member events"
  ON public.agency_member_events FOR SELECT TO authenticated
  USING (public.is_agency_owner_or_admin(agency_id));

DROP POLICY IF EXISTS "Insert agency member events" ON public.agency_member_events;
CREATE POLICY "Insert agency member events"
  ON public.agency_member_events FOR INSERT TO authenticated
  WITH CHECK (
    (
      event_type = 'left'
      AND user_id = auth.uid()
      AND public.is_agency_member(agency_id)
    )
    OR public.is_agency_owner_or_admin(agency_id)
  );

-- Leave agency: log event then delete membership
CREATE OR REPLACE FUNCTION public.leave_my_agency()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_agency_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT agency_id INTO v_agency_id
  FROM public.agency_members
  WHERE user_id = v_uid
  LIMIT 1;

  IF v_agency_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not in an agency');
  END IF;

  -- Owners cannot leave via this path
  IF EXISTS (
    SELECT 1 FROM public.agencies WHERE id = v_agency_id AND owner_id = v_uid
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Owner cannot leave agency');
  END IF;

  INSERT INTO public.agency_member_events (agency_id, user_id, event_type, actor_id)
  VALUES (v_agency_id, v_uid, 'left', v_uid);

  DELETE FROM public.agency_members
  WHERE agency_id = v_agency_id AND user_id = v_uid;

  RETURN json_build_object('success', true, 'agency_id', v_agency_id);
END;
$function$;

-- Remove host: log event then delete membership
CREATE OR REPLACE FUNCTION public.remove_agency_host(
  p_agency_id uuid,
  p_user_id uuid
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

  IF NOT public.is_agency_owner_or_admin(p_agency_id) THEN
    RETURN json_build_object('success', false, 'message', 'Not allowed');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.agencies WHERE id = p_agency_id AND owner_id = p_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Cannot remove agency owner');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.agency_members
    WHERE agency_id = p_agency_id AND user_id = p_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Host not found');
  END IF;

  INSERT INTO public.agency_member_events (agency_id, user_id, event_type, actor_id)
  VALUES (p_agency_id, p_user_id, 'removed', v_uid);

  DELETE FROM public.agency_members
  WHERE agency_id = p_agency_id AND user_id = p_user_id;

  RETURN json_build_object('success', true);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.leave_my_agency() TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_agency_host(uuid, uuid) TO authenticated;
