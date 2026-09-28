-- Master Panel operators: username/password assigned from official admin (sklive-admin).
-- Coolify apply:
--   docker exec -i "$COOLIFY_DB_CONTAINER" psql -U postgres -d postgres < supabase/migrations/20260914170000_master_panel_operators.sql

CREATE TABLE IF NOT EXISTS public.master_panel_operators (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  username text NOT NULL,
  password_hash text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_by_user_id uuid NULL REFERENCES public.users(id) ON DELETE SET NULL,
  last_login_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT master_panel_operators_username_format
    CHECK (username ~ '^[a-zA-Z0-9_]{3,32}$'),
  CONSTRAINT master_panel_operators_user_unique UNIQUE (user_id),
  CONSTRAINT master_panel_operators_username_unique UNIQUE (username)
);

CREATE INDEX IF NOT EXISTS idx_master_panel_operators_active
  ON public.master_panel_operators (is_active)
  WHERE is_active = true;

COMMENT ON TABLE public.master_panel_operators IS
  'Login accounts for sklive-master-pannel. Created/managed from sklive-admin.';

ALTER TABLE public.master_panel_operators ENABLE ROW LEVEL SECURITY;

-- No public/anon policies: only service_role (admin panels) may read/write.
REVOKE ALL ON public.master_panel_operators FROM PUBLIC;
GRANT ALL ON public.master_panel_operators TO service_role;
GRANT SELECT ON public.master_panel_operators TO postgres;
