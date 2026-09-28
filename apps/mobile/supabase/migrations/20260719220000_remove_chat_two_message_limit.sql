-- Remove 2-message lock until recipient accepts. Users may message freely.
-- Keep block enforcement only.

CREATE OR REPLACE FUNCTION public.enforce_chat_limit()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_status TEXT;
BEGIN
  SELECT status INTO v_status FROM public.conversations WHERE id = NEW.conversation_id;

  IF v_status = 'blocked' THEN
    RAISE EXCEPTION 'This conversation is blocked.';
  END IF;

  -- Auto-open pending threads so either side can keep chatting without accept.
  IF v_status = 'pending' THEN
    UPDATE public.conversations
    SET status = 'accepted'
    WHERE id = NEW.conversation_id;
  END IF;

  RETURN NEW;
END;
$function$;

ALTER TABLE public.conversations
  ALTER COLUMN status SET DEFAULT 'accepted';

-- Unlock existing pending chats
UPDATE public.conversations
SET status = 'accepted'
WHERE status = 'pending';
