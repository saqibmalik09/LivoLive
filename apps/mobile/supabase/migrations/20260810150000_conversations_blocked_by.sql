-- Track who blocked a DM conversation (WhatsApp-style blacklist).
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS blocked_by uuid REFERENCES public.users (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS conversations_blocked_by_idx
  ON public.conversations (blocked_by)
  WHERE status = 'blocked';
