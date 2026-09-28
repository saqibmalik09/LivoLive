-- Master Panel audit source documentation / optional CHECK extension
--
-- Coolify apply:
--   docker exec -i "$COOLIFY_DB_CONTAINER" psql -U postgres -d postgres < supabase/migrations/20260914120000_master_panel_audit_source.sql
--
-- The Master Panel (`sklive-master-pannel`) writes admin_audit_logs via the
-- service role client and uses existing RPCs such as create_business_staff,
-- equip_user_asset, and provision_user_assets. No schema change is required
-- when admin_audit_logs.source is unconstrained TEXT (Coolify current dump).
--
-- If a CHECK constraint on source exists in a given environment, extend it
-- to allow 'sklive-master-pannel'. The DO block below is a no-op when no
-- matching CHECK is present.

DO $$
DECLARE
  r record;
  def text;
BEGIN
  FOR r IN
    SELECT c.conname, pg_get_constraintdef(c.oid) AS definition
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname = 'admin_audit_logs'
      AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%source%'
  LOOP
    def := r.definition;
    IF def ILIKE '%sklive-master-pannel%' THEN
      RAISE NOTICE 'Constraint % already allows sklive-master-pannel', r.conname;
      CONTINUE;
    END IF;

    -- Best-effort: drop and recreate only if definition looks like an IN/ANY list of sources.
    IF def ~* 'source.*=.*ANY' OR def ~* 'source.*IN\s*\(' THEN
      EXECUTE format('ALTER TABLE public.admin_audit_logs DROP CONSTRAINT %I', r.conname);
      -- Rebuild a permissive source check including known panels + master panel.
      EXECUTE $sql$
        ALTER TABLE public.admin_audit_logs
        ADD CONSTRAINT admin_audit_logs_source_check
        CHECK (
          source = ANY (
            ARRAY[
              'sklive-admin'::text,
              'sklive-super-admin'::text,
              'sklive-flutter'::text,
              'sklive-master-pannel'::text
            ]
          )
        )
      $sql$;
      RAISE NOTICE 'Replaced % with admin_audit_logs_source_check including sklive-master-pannel', r.conname;
    ELSE
      RAISE NOTICE 'Skipping non-list source constraint %: %', r.conname, def;
    END IF;
  END LOOP;
END $$;

COMMENT ON TABLE public.admin_audit_logs IS
  'Audit trail for platform admin, staff portal, and master panel (sklive-master-pannel) actions.';
