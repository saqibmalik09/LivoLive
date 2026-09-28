-- Link home top banners to a party event (tap opens that event).
ALTER TABLE public.banners
  ADD COLUMN IF NOT EXISTS party_event_id uuid
    REFERENCES public.party_events(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS banners_party_event_id_idx
  ON public.banners (party_event_id)
  WHERE party_event_id IS NOT NULL;

COMMENT ON COLUMN public.banners.party_event_id IS
  'Optional party_events.id. When set (typically on top banners), app opens that event on tap.';
