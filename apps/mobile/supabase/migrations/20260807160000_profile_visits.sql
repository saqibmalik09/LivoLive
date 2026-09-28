-- Profile visit tracking: who viewed whose profile (unique pair + visit_count).

CREATE TABLE IF NOT EXISTS public.profile_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  visitor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  visit_count integer NOT NULL DEFAULT 1 CHECK (visit_count > 0),
  last_visited_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT profile_visits_not_self CHECK (profile_id <> visitor_id),
  CONSTRAINT profile_visits_unique_pair UNIQUE (profile_id, visitor_id)
);

CREATE INDEX IF NOT EXISTS profile_visits_profile_id_idx
  ON public.profile_visits (profile_id);

CREATE INDEX IF NOT EXISTS profile_visits_visitor_id_idx
  ON public.profile_visits (visitor_id);

ALTER TABLE public.profile_visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profile_visits_select_own ON public.profile_visits;
CREATE POLICY profile_visits_select_own ON public.profile_visits
  FOR SELECT TO authenticated
  USING (profile_id = auth.uid() OR visitor_id = auth.uid());

DROP POLICY IF EXISTS profile_visits_insert_self ON public.profile_visits;
CREATE POLICY profile_visits_insert_self ON public.profile_visits
  FOR INSERT TO authenticated
  WITH CHECK (visitor_id = auth.uid() AND profile_id <> auth.uid());

DROP POLICY IF EXISTS profile_visits_update_self ON public.profile_visits;
CREATE POLICY profile_visits_update_self ON public.profile_visits
  FOR UPDATE TO authenticated
  USING (visitor_id = auth.uid())
  WITH CHECK (visitor_id = auth.uid());

GRANT SELECT, INSERT, UPDATE ON public.profile_visits TO authenticated;
GRANT ALL ON public.profile_visits TO service_role;

-- Record a visit (upsert). No-op for self / anon.
CREATE OR REPLACE FUNCTION public.record_profile_visit(p_profile_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR p_profile_id IS NULL OR v_uid = p_profile_id THEN
    RETURN;
  END IF;

  INSERT INTO public.profile_visits (profile_id, visitor_id, visit_count, last_visited_at)
  VALUES (p_profile_id, v_uid, 1, now())
  ON CONFLICT (profile_id, visitor_id) DO UPDATE
    SET visit_count = public.profile_visits.visit_count + 1,
        last_visited_at = now();
END;
$$;

-- Total visit events for a profile (sum of visit_count).
CREATE OR REPLACE FUNCTION public.get_profile_visit_count(p_profile_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(visit_count), 0)::integer
  FROM public.profile_visits
  WHERE profile_id = p_profile_id;
$$;

GRANT EXECUTE ON FUNCTION public.record_profile_visit(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_profile_visit_count(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_profile_visit(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_profile_visit_count(uuid) TO service_role;
