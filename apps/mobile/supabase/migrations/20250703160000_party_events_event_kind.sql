-- Party events: event_kind drives native CP vs WebView (no admin template picker).

ALTER TABLE public.party_events
  ADD COLUMN IF NOT EXISTS event_kind text;

UPDATE public.party_events
SET event_kind = CASE
  WHEN screen_template IN ('cp_romance', 'cp_event') THEN 'cp_native'
  WHEN screen_template IS NOT NULL THEN 'webview'
  WHEN action_type = 'cp_ranking' THEN 'cp_native'
  ELSE 'webview'
END
WHERE event_kind IS NULL;

ALTER TABLE public.party_events
  ALTER COLUMN event_kind SET DEFAULT 'webview';

UPDATE public.party_events
SET event_kind = 'webview'
WHERE event_kind IS NULL;

ALTER TABLE public.party_events
  ALTER COLUMN event_kind SET NOT NULL;

ALTER TABLE public.party_events
  DROP CONSTRAINT IF EXISTS party_events_screen_template_check;

ALTER TABLE public.party_events
  DROP CONSTRAINT IF EXISTS party_events_event_kind_check;

ALTER TABLE public.party_events
  ADD CONSTRAINT party_events_event_kind_check CHECK (
    event_kind IN ('cp_native', 'webview')
  );

COMMENT ON COLUMN public.party_events.event_kind IS
  'cp_native = fixed CpEventScreen; webview = in-app URL';
