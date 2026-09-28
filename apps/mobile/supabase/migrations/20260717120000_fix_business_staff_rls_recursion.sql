-- Fix: infinite recursion in business_staff RLS
-- Cause: "Staff read direct children" SELECT-subqueries business_staff inside its own policy.
-- "Public read staff code lookup" already allows SELECT of all active staff rows.

DROP POLICY IF EXISTS "Staff read direct children" ON public.business_staff;

-- Safer helper if we ever need parent-scoped reads without opening all rows.
CREATE OR REPLACE FUNCTION public.my_active_staff_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT id
  FROM public.business_staff
  WHERE user_id = auth.uid()
    AND is_active = true;
$$;

REVOKE ALL ON FUNCTION public.my_active_staff_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.my_active_staff_ids() TO authenticated;

-- Optional non-recursive children policy (only needed if public-active policy is removed later).
-- Kept inactive intentionally: public active SELECT policy already covers team reads.
-- Uncomment only after dropping "Public read staff code lookup":
-- CREATE POLICY "Staff read direct children" ON public.business_staff
--   FOR SELECT TO authenticated
--   USING (parent_staff_id IN (SELECT public.my_active_staff_ids()));
