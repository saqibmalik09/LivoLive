-- Optional: allow dedicated message_type (app uses text + metadata if not applied)
ALTER TABLE public.chat_messages DROP CONSTRAINT IF EXISTS chat_messages_message_type_check;
ALTER TABLE public.chat_messages ADD CONSTRAINT chat_messages_message_type_check
  CHECK (message_type = ANY (ARRAY['text'::text, 'image'::text, 'gift'::text, 'voice'::text, 'room_invite'::text]));
