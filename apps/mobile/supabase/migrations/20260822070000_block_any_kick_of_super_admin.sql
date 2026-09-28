-- Nobody (host / admin / super admin) may kick a Super Admin from a room.
-- Also block force-deleting a Super Admin seat row via authenticated client.

CREATE OR REPLACE FUNCTION public.prevent_super_admin_kick_super_admin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_active_super_bd(NEW.user_id) THEN
    RAISE EXCEPTION 'Cannot kick a Super Admin'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_super_admin_kick_super_admin ON public.room_kicks;
CREATE TRIGGER trg_prevent_super_admin_kick_super_admin
  BEFORE INSERT ON public.room_kicks
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_super_admin_kick_super_admin();

CREATE OR REPLACE FUNCTION public.prevent_force_remove_super_admin_seat()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Gateway/service_role often has no auth.uid(); client force-leave does.
  IF auth.uid() IS NOT NULL
     AND auth.uid() IS DISTINCT FROM OLD.user_id
     AND public.is_active_super_bd(OLD.user_id) THEN
    RAISE EXCEPTION 'Cannot remove a Super Admin from seat'
      USING ERRCODE = '42501';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_force_remove_super_admin_seat ON public.room_seats;
CREATE TRIGGER trg_prevent_force_remove_super_admin_seat
  BEFORE DELETE ON public.room_seats
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_force_remove_super_admin_seat();
