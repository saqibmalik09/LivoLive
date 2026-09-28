-- When a room reward box is claimed/opened, broadcast a short push to all
-- app users (system_notifications.user_id NULL → FCM topic "all").
-- Tap metadata.room_id opens that room in the app.

CREATE OR REPLACE FUNCTION public.notify_room_reward_box_opened()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_title text;
BEGIN
  -- Soft throttle: at most one broadcast per room per 2 minutes
  IF EXISTS (
    SELECT 1
    FROM public.system_notifications sn
    WHERE sn.type = 'room_reward_box'
      AND sn.user_id IS NULL
      AND sn.metadata->>'room_id' = NEW.room_id::text
      AND sn.created_at > now() - interval '2 minutes'
  ) THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF(trim(r.title), ''), 'this room')
  INTO v_title
  FROM public.rooms r
  WHERE r.id = NEW.room_id;

  IF v_title IS NULL THEN
    v_title := 'this room';
  END IF;

  INSERT INTO public.system_notifications (
    user_id,
    title,
    content,
    type,
    icon_type,
    metadata
  ) VALUES (
    NULL,
    'Hurry up!',
    'Box reward open in ' || v_title,
    'room_reward_box',
    'gift',
    jsonb_build_object(
      'room_id', NEW.room_id::text,
      'room_title', v_title,
      'level', NEW.level
    )
  );

  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- Never block a successful claim because of notification failure
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_notify_room_reward_box_opened ON public.room_reward_claims;
CREATE TRIGGER trg_notify_room_reward_box_opened
  AFTER INSERT ON public.room_reward_claims
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_room_reward_box_opened();
