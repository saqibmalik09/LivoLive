-- Allow authenticated users to update their own profile row.

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users update own profile" ON public.users;
CREATE POLICY "Users update own profile"
  ON public.users
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Public read users" ON public.users;
CREATE POLICY "Public read users"
  ON public.users
  FOR SELECT
  TO public
  USING (true);
