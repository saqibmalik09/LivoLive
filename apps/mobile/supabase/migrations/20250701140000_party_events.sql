-- Party / Events tab: admin-managed event cards (banner + tap action).

CREATE TABLE IF NOT EXISTS public.party_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text NOT NULL DEFAULT '',
  banner_url text NOT NULL DEFAULT '',
  action_type text NOT NULL DEFAULT 'gift_ranking',
  action_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  start_at timestamptz,
  end_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  priority int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT party_events_action_type_check CHECK (
    action_type IN (
      'gift_ranking',
      'game_ranking',
      'cp_ranking',
      'charm_ranking',
      'wealth_ranking',
      'room_ranking',
      'agency_ranking',
      'none'
    )
  )
);

CREATE INDEX IF NOT EXISTS party_events_active_priority_idx
  ON public.party_events (is_active, priority DESC, start_at DESC);

ALTER TABLE public.party_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read active party events" ON public.party_events;
CREATE POLICY "Public read active party events"
  ON public.party_events
  FOR SELECT
  TO public
  USING (true);
