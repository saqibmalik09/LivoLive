-- Gate profile visitors list (who visited me) by active VIP level >= 1.
-- Requirement: profile_id = auth.uid() branch should be readable only when
-- users.vip_level >= 1 AND users.vip_until > now().

DROP POLICY IF EXISTS profile_visits_select_own ON public.profile_visits;

CREATE POLICY profile_visits_select_own ON public.profile_visits
  FOR SELECT TO authenticated
  USING (
    (
      profile_id = auth.uid()
      AND EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = auth.uid()
          AND COALESCE(u.vip_level, 0) >= 1
          AND u.vip_until IS NOT NULL
          AND u.vip_until > now()
      )
    )
    OR (visitor_id = auth.uid())
  );

