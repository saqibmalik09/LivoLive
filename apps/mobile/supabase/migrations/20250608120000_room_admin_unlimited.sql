-- Unlimited room sub-admins: no count cap.
-- Host and existing room admins can promote members to admin.

CREATE TABLE IF NOT EXISTS public.room_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  inviter_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'admin',
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT room_invitations_role_check CHECK (role IN ('admin')),
  CONSTRAINT room_invitations_status_check CHECK (status IN ('pending', 'accepted', 'rejected'))
);

CREATE UNIQUE INDEX IF NOT EXISTS room_invitations_one_pending_per_user
  ON public.room_invitations (room_id, invitee_id)
  WHERE status = 'pending';

ALTER TABLE public.room_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Invitee can view own room invitations" ON public.room_invitations;
CREATE POLICY "Invitee can view own room invitations"
  ON public.room_invitations FOR SELECT TO authenticated
  USING (invitee_id = auth.uid());

DROP POLICY IF EXISTS "Host or room admin can send invitations" ON public.room_invitations;
CREATE POLICY "Host or room admin can send invitations"
  ON public.room_invitations FOR INSERT TO authenticated
  WITH CHECK (
    inviter_id = auth.uid()
    AND (
      EXISTS (
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

DROP POLICY IF EXISTS "Invitee can respond to invitations" ON public.room_invitations;
CREATE POLICY "Invitee can respond to invitations"
  ON public.room_invitations FOR UPDATE TO authenticated
  USING (invitee_id = auth.uid())
  WITH CHECK (invitee_id = auth.uid());

-- Room admins (not only host) may update member roles in their room.
DROP POLICY IF EXISTS "Room admins can promote members" ON public.room_members;
CREATE POLICY "Room admins can promote members"
  ON public.room_members FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.room_members mgr
      WHERE mgr.room_id = room_members.room_id
        AND mgr.user_id = auth.uid()
        AND mgr.role = 'admin'
    )
  )
  WITH CHECK (role IN ('member', 'admin'));

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
BEGIN
  IF TG_OP <> 'UPDATE' OR OLD.role IS NOT DISTINCT FROM NEW.role THEN
    RETURN NEW;
  END IF;

  SELECT host_id INTO v_room_host FROM public.rooms WHERE id = NEW.room_id;
  v_is_host := (auth.uid() = v_room_host);
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
  IF v_is_room_admin AND NOT v_is_host THEN
    IF NOT (OLD.role = 'member' AND NEW.role = 'admin') THEN
      RAISE EXCEPTION 'Room admins can only promote members to sub-admin'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS room_members_role_change ON public.room_members;
CREATE TRIGGER room_members_role_change
  BEFORE UPDATE OF role ON public.room_members
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_room_member_role_change();
