-- Allow sk_host_native event kind for simple SK Host Party screen.
ALTER TABLE public.party_events
  DROP CONSTRAINT IF EXISTS party_events_event_kind_check;

ALTER TABLE public.party_events
  ADD CONSTRAINT party_events_event_kind_check
  CHECK (event_kind IN (
    'cp_native',
    'webview',
    'weekly_star_native',
    'game_star_native',
    'sk_host_native'
  ));
