-- Agency Info fields (nickname already = name, logo_url exists)
ALTER TABLE public.agencies
  ADD COLUMN IF NOT EXISTS attribute text DEFAULT 'Personal',
  ADD COLUMN IF NOT EXISTS whatsapp text,
  ADD COLUMN IF NOT EXISTS contact_email text;

COMMENT ON COLUMN public.agencies.attribute IS 'Agency attribute e.g. Personal, Company';
COMMENT ON COLUMN public.agencies.whatsapp IS 'Public WhatsApp contact';
COMMENT ON COLUMN public.agencies.contact_email IS 'Public contact email';
