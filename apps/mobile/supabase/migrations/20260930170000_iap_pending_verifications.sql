BEGIN;

CREATE TABLE IF NOT EXISTS public.iap_pending_verifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  product_id      text NOT NULL,
  purchase_id     text,
  purchase_token  text NOT NULL,
  stage           text NOT NULL,
  http_status     integer,
  error_reason    text,
  error_message   text,
  attempts        integer NOT NULL DEFAULT 1,
  resolved_at     timestamptz,
  resolution      text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_attempt_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS iap_pending_verifications_token_uidx
  ON public.iap_pending_verifications (purchase_token);
CREATE INDEX IF NOT EXISTS iap_pending_verifications_open_idx
  ON public.iap_pending_verifications (created_at DESC) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS iap_pending_verifications_user_idx
  ON public.iap_pending_verifications (user_id, created_at DESC);

-- Holds live Google Play purchase tokens: service_role only.
-- RLS on with zero policies => anon/authenticated get nothing.
ALTER TABLE public.iap_pending_verifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.iap_pending_verifications FROM anon, authenticated;

-- Record a failed/unverified purchase so it can be reconciled later.
CREATE OR REPLACE FUNCTION public.record_iap_verification_failure(
  p_user_id uuid,
  p_product_id text,
  p_purchase_id text,
  p_purchase_token text,
  p_stage text,
  p_http_status integer DEFAULT NULL,
  p_error_reason text DEFAULT NULL,
  p_error_message text DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_token text := nullif(trim(coalesce(p_purchase_token, '')), '');
  v_id uuid;
BEGIN
  IF coalesce(auth.jwt() ->> 'role', '') <> 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Forbidden');
  END IF;
  IF p_user_id IS NULL OR v_token IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'user_id and purchase_token required');
  END IF;

  INSERT INTO public.iap_pending_verifications AS t (
    user_id, product_id, purchase_id, purchase_token,
    stage, http_status, error_reason, error_message
  ) VALUES (
    p_user_id, coalesce(p_product_id, ''), nullif(trim(coalesce(p_purchase_id,'')), ''), v_token,
    coalesce(p_stage, 'unknown'), p_http_status, p_error_reason, p_error_message
  )
  ON CONFLICT (purchase_token) DO UPDATE
    SET attempts        = t.attempts + 1,
        last_attempt_at = now(),
        stage           = EXCLUDED.stage,
        http_status     = EXCLUDED.http_status,
        error_reason    = EXCLUDED.error_reason,
        error_message   = EXCLUDED.error_message,
        purchase_id     = coalesce(EXCLUDED.purchase_id, t.purchase_id)
  RETURNING t.id INTO v_id;

  RETURN json_build_object('success', true, 'id', v_id);
END;
$fn$;

REVOKE ALL ON FUNCTION public.record_iap_verification_failure(uuid,text,text,text,text,integer,text,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_iap_verification_failure(uuid,text,text,text,text,integer,text,text) TO service_role;

-- Mark one resolved (credited / refunded / invalid / manual).
CREATE OR REPLACE FUNCTION public.resolve_iap_verification(
  p_purchase_token text,
  p_resolution text
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_n integer;
BEGIN
  IF coalesce(auth.jwt() ->> 'role', '') <> 'service_role' THEN
    RETURN json_build_object('success', false, 'message', 'Forbidden');
  END IF;
  UPDATE public.iap_pending_verifications
     SET resolved_at = now(), resolution = coalesce(p_resolution, 'manual')
   WHERE purchase_token = p_purchase_token AND resolved_at IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN json_build_object('success', true, 'updated', v_n);
END;
$fn$;

COMMIT;
