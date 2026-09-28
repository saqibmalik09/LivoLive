-- Super Admin (business_staff.role = super_bd) gets host-level room control:
-- locked-room entry, manage RPCs, kicks, seats, room settings updates.
-- Does NOT change rooms.host_id / economic ownership.

CREATE OR REPLACE FUNCTION public.is_active_super_bd(p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.business_staff bs
    WHERE bs.user_id = p_user_id
      AND bs.is_active = true
      AND bs.role = 'super_bd'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_active_super_bd(uuid) TO authenticated, anon, service_role;

-- Manage helper used by PK and other room RPCs.
CREATE OR REPLACE FUNCTION public.user_can_manage_room(p_room_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rooms r
    WHERE r.id = p_room_id AND r.host_id = p_user_id
  )
  OR EXISTS (
    SELECT 1 FROM public.room_members rm
    WHERE rm.room_id = p_room_id
      AND rm.user_id = p_user_id
      AND rm.role = 'admin'
  )
  OR public.is_active_super_bd(p_user_id);
$$;

-- Locked room PIN bypass for Super Admin (same as host/admin).
CREATE OR REPLACE FUNCTION public.verify_room_password(
  p_room_id uuid,
  p_password text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_host uuid;
  v_locked boolean;
  v_pass text;
BEGIN
  SELECT host_id, is_locked, room_password
  INTO v_host, v_locked, v_pass
  FROM public.rooms
  WHERE id = p_room_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_uid IS NOT NULL AND v_uid = v_host THEN
    RETURN true;
  END IF;

  IF v_uid IS NOT NULL AND EXISTS (
    SELECT 1
    FROM public.room_members rm
    WHERE rm.room_id = p_room_id
      AND rm.user_id = v_uid
      AND COALESCE(rm.role, '') IN ('admin', 'co_host', 'host')
  ) THEN
    RETURN true;
  END IF;

  IF v_uid IS NOT NULL AND public.is_active_super_bd(v_uid) THEN
    RETURN true;
  END IF;

  IF COALESCE(v_locked, false) = false THEN
    RETURN true;
  END IF;

  RETURN COALESCE(v_pass, '') <> ''
    AND COALESCE(v_pass, '') = COALESCE(trim(p_password), '');
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_room_password(uuid, text)
  TO authenticated, anon, service_role;

-- YouTube control: use shared manage helper (includes Super Admin).
CREATE OR REPLACE FUNCTION public.update_room_youtube_state(
  p_room_id uuid,
  p_youtube_state jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.rooms WHERE id = p_room_id AND is_active = true
  ) THEN
    RAISE EXCEPTION 'Room not found' USING ERRCODE = 'P0002';
  END IF;

  IF NOT public.user_can_manage_room(p_room_id, v_user_id) THEN
    RAISE EXCEPTION 'Only host or room admin can control YouTube'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.rooms
  SET youtube_state = p_youtube_state
  WHERE id = p_room_id;

  RETURN p_youtube_state;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_room_youtube_state(uuid, jsonb) TO authenticated;

-- Clear chat: require manage rights (fixes open SECURITY DEFINER + Super Admin).
CREATE OR REPLACE FUNCTION public.clear_room_chat(p_room_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT public.user_can_manage_room(p_room_id, auth.uid()) THEN
    RAISE EXCEPTION 'Only host or room admin can clear chat'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.rooms
  SET chat_cleared_at = NOW()
  WHERE id = p_room_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.clear_room_chat(UUID) TO authenticated;

-- Room settings updates (lock, admin_only_chat, etc.) — Super Admin can update any room.
DROP POLICY IF EXISTS "Super Admin can update any room" ON public.rooms;
CREATE POLICY "Super Admin can update any room"
  ON public.rooms FOR UPDATE TO authenticated
  USING (public.is_active_super_bd(auth.uid()))
  WITH CHECK (public.is_active_super_bd(auth.uid()));

-- Seat manage for Super Admin (host/admin/self covered by existing policies).
DROP POLICY IF EXISTS "Super Admin can manage seats" ON public.room_seats;
CREATE POLICY "Super Admin can manage seats"
  ON public.room_seats FOR ALL TO authenticated
  USING (public.is_active_super_bd(auth.uid()))
  WITH CHECK (public.is_active_super_bd(auth.uid()));

-- Kick insert for Super Admin.
DROP POLICY IF EXISTS "Super Admin can manage kicks" ON public.room_kicks;
CREATE POLICY "Super Admin can manage kicks"
  ON public.room_kicks FOR ALL TO authenticated
  USING (public.is_active_super_bd(auth.uid()))
  WITH CHECK (public.is_active_super_bd(auth.uid()));

-- Room admin invitations — Super Admin may send.
DROP POLICY IF EXISTS "Host or room admin can send invitations" ON public.room_invitations;
CREATE POLICY "Host or room admin can send invitations"
  ON public.room_invitations FOR INSERT TO authenticated
  WITH CHECK (
    inviter_id = auth.uid()
    AND (
      public.is_active_super_bd(auth.uid())
      OR EXISTS (
        SELECT 1 FROM public.rooms r
        WHERE r.id = room_id AND r.host_id = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM public.room_members rm
        WHERE rm.room_id = room_invitations.room_id
          AND rm.user_id = auth.uid()
          AND rm.role = 'admin'
      )
    )
  );

-- Room member promote — Super Admin may update roles (non-host).
DROP POLICY IF EXISTS "Room admins can promote members" ON public.room_members;
CREATE POLICY "Room admins can promote members"
  ON public.room_members FOR UPDATE TO authenticated
  USING (
    public.is_active_super_bd(auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.room_members mgr
      WHERE mgr.room_id = room_members.room_id
        AND mgr.user_id = auth.uid()
        AND mgr.role = 'admin'
    )
    OR EXISTS (
      SELECT 1 FROM public.rooms r
      WHERE r.id = room_members.room_id AND r.host_id = auth.uid()
    )
  )
  WITH CHECK (role IN ('member', 'admin'));

-- Allow Super Admin in role-change trigger (treat like host for promote rules).
CREATE OR REPLACE FUNCTION public.enforce_room_member_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_room_host uuid;
  v_is_host boolean;
  v_is_room_admin boolean;
  v_is_super_bd boolean;
BEGIN
  IF TG_OP <> 'UPDATE' OR OLD.role IS NOT DISTINCT FROM NEW.role THEN
    RETURN NEW;
  END IF;

  SELECT host_id INTO v_room_host FROM public.rooms WHERE id = NEW.room_id;
  v_is_host := (auth.uid() = v_room_host);
  v_is_super_bd := public.is_active_super_bd(auth.uid());
  v_is_room_admin := EXISTS (
    SELECT 1 FROM public.room_members rm
    WHERE rm.room_id = NEW.room_id
      AND rm.user_id = auth.uid()
      AND rm.role = 'admin'
  );

  IF NEW.user_id = v_room_host OR OLD.role = 'host' OR NEW.role = 'host' THEN
    RAISE EXCEPTION 'Cannot change the host role' USING ERRCODE = '42501';
  END IF;

  -- Sub-admins: only promote member -> admin (no cap on how many admins)
  IF v_is_room_admin AND NOT v_is_host AND NOT v_is_super_bd THEN
    IF NOT (OLD.role = 'member' AND NEW.role = 'admin') THEN
      RAISE EXCEPTION 'Room admins can only promote members to sub-admin'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
