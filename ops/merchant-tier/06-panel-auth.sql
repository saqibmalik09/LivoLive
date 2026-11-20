-- ════════════════════════════════════════════════════════════════════
-- Merchant web panel — credentials and sessions
--
-- Merchants are app users, but app accounts may be social logins with no
-- password, and panel access should be grantable and revocable by admin
-- independently of the app account. So admin issues a separate
-- username/password, following the master_panel_operators precedent.
--
-- Sessions are opaque server-side tokens, NOT a descriptive cookie: the
-- cookie carries a random token and the server resolves which merchant it
-- belongs to. A cookie that names its own merchant would let anyone who
-- knows a merchant's id spend that merchant's coins.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS public.merchant_panel_logins (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  username       text NOT NULL UNIQUE,
  -- scrypt$salt$hash, produced by the panel's Node code
  password_hash  text NOT NULL,
  is_active      boolean NOT NULL DEFAULT true,
  must_change_password boolean NOT NULL DEFAULT true,
  last_login_at  timestamptz,
  failed_attempts int NOT NULL DEFAULT 0,
  locked_until   timestamptz,
  created_by     uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT merchant_panel_logins_username_format
    CHECK (username ~ '^[a-z0-9_]{3,32}$')
);

CREATE TABLE IF NOT EXISTS public.merchant_panel_sessions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  login_id     uuid NOT NULL REFERENCES public.merchant_panel_logins(id) ON DELETE CASCADE,
  -- sha256 of the random cookie token; the raw token is never stored
  token_hash   text NOT NULL UNIQUE,
  expires_at   timestamptz NOT NULL,
  revoked_at   timestamptz,
  ip           text,
  user_agent   text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS merchant_panel_sessions_login_idx
  ON public.merchant_panel_sessions (login_id, created_at DESC);
CREATE INDEX IF NOT EXISTS merchant_panel_sessions_live_idx
  ON public.merchant_panel_sessions (expires_at)
  WHERE revoked_at IS NULL;

-- Both tables are reached only by the panels' service_role connections.
-- No end-user policy is granted, so RLS denies everything else outright.
ALTER TABLE public.merchant_panel_logins   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_panel_sessions ENABLE ROW LEVEL SECURITY;

-- Housekeeping: drop sessions that expired or were revoked a while ago.
CREATE OR REPLACE FUNCTION public.prune_merchant_panel_sessions()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $fn$
DECLARE
  v_count integer;
BEGIN
  DELETE FROM public.merchant_panel_sessions
   WHERE (expires_at < now() - interval '7 days')
      OR (revoked_at IS NOT NULL AND revoked_at < now() - interval '7 days');
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$fn$;

COMMIT;
