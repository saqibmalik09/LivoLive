-- Admin ban note shown on the user's full-screen ban gate.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS ban_reason text,
  ADD COLUMN IF NOT EXISTS banned_at timestamptz;

COMMENT ON COLUMN public.users.ban_reason IS
  'Optional note from admin shown to the banned user in-app.';
COMMENT ON COLUMN public.users.banned_at IS
  'When the account was last banned.';

-- Refresh realtime so ban_reason / banned_at are delivered to clients.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime DROP TABLE public.users;
    EXCEPTION WHEN undefined_object THEN
      NULL;
    END;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  END IF;
END $$;

-- Super Admin ban RPC: optional note (cleared on unban).
DROP FUNCTION IF EXISTS public.super_bd_set_user_banned(uuid, boolean);

CREATE OR REPLACE FUNCTION public.super_bd_set_user_banned(
  p_target_user_id uuid,
  p_banned boolean,
  p_ban_reason text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_staff public.business_staff%ROWTYPE;
  v_in_subtree boolean := false;
  v_note text := NULLIF(trim(COALESCE(p_ban_reason, '')), '');
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT * INTO v_staff FROM public.business_staff
  WHERE user_id = v_uid AND is_active AND role = 'super_bd'
  LIMIT 1;

  IF v_staff.id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Super Admin only');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.business_staff bs
    WHERE bs.user_id = p_target_user_id AND bs.is_active
      AND (
        bs.parent_staff_id = v_staff.id
        OR public.is_staff_descendant(v_staff.id, bs.id)
      )
  ) THEN
    v_in_subtree := true;
  END IF;

  IF NOT v_in_subtree AND EXISTS (
    SELECT 1
    FROM public.agency_members am
    JOIN public.agencies a ON a.id = am.agency_id
    JOIN public.business_staff bd ON bd.id = a.sponsor_staff_id
    WHERE am.user_id = p_target_user_id
      AND (
        bd.parent_staff_id IN (
          SELECT id FROM public.business_staff WHERE parent_staff_id = v_staff.id AND is_active
        )
        OR bd.id IN (
          SELECT id FROM public.business_staff WHERE parent_staff_id = v_staff.id AND is_active
        )
        OR public.is_staff_descendant(v_staff.id, bd.id)
      )
  ) THEN
    v_in_subtree := true;
  END IF;

  IF NOT v_in_subtree THEN
    RETURN json_build_object('success', false, 'message', 'User not in your team subtree');
  END IF;

  IF p_banned THEN
    UPDATE public.users
    SET
      is_banned = true,
      ban_reason = v_note,
      banned_at = now()
    WHERE id = p_target_user_id;
  ELSE
    UPDATE public.users
    SET
      is_banned = false,
      ban_reason = NULL,
      banned_at = NULL
    WHERE id = p_target_user_id;
  END IF;

  RETURN json_build_object(
    'success', true,
    'user_id', p_target_user_id,
    'is_banned', p_banned,
    'ban_reason', v_note
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.super_bd_set_user_banned(uuid, boolean, text) TO authenticated;
