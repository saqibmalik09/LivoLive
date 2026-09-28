-- Super Admin cannot kick another Super Admin from a room.

CREATE OR REPLACE FUNCTION public.prevent_super_admin_kick_super_admin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_active_super_bd(NEW.admin_id)
     AND public.is_active_super_bd(NEW.user_id) THEN
    RAISE EXCEPTION 'Super Admin cannot kick another Super Admin'
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
