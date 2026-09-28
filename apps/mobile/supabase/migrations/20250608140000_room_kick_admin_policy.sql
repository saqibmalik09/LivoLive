-- Host and room admins can kick users; notify kicked user.

DROP POLICY IF EXISTS "Room admins can manage kicks" ON public.room_kicks;
CREATE POLICY "Room admins can manage kicks"
  ON public.room_kicks FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.room_members rm
      WHERE rm.room_id = room_kicks.room_id
        AND rm.user_id = auth.uid()
        AND rm.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.room_members rm
      WHERE rm.room_id = room_kicks.room_id
        AND rm.user_id = auth.uid()
        AND rm.role = 'admin'
    )
  );

CREATE OR REPLACE FUNCTION public.notify_user_room_kick()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_room_title text;
  v_admin_name text;
BEGIN
  SELECT COALESCE(title, 'Room') INTO v_room_title FROM public.rooms WHERE id = NEW.room_id;
  SELECT COALESCE(username, 'Admin') INTO v_admin_name FROM public.users WHERE id = NEW.admin_id;

  INSERT INTO public.system_notifications (user_id, title, content, type, icon_type, metadata)
  VALUES (
    NEW.user_id,
    'Kicked from Room',
    format('You were removed from "%s" by %s.', v_room_title, v_admin_name),
    'room_kick',
    'warning',
    jsonb_build_object('room_id', NEW.room_id, 'kick_id', NEW.id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_room_kick_notify ON public.room_kicks;
CREATE TRIGGER on_room_kick_notify
  AFTER INSERT ON public.room_kicks
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_user_room_kick();
