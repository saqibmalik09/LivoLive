-- CP Nest: admin-managed event banners (tap → CP events screen or ranking).

CREATE TABLE IF NOT EXISTS public.cp_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text NOT NULL DEFAULT '',
  banner_url text NOT NULL DEFAULT '',
  action_type text NOT NULL DEFAULT 'cp_events',
  action_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  start_at timestamptz,
  end_at timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  priority int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cp_events_action_type_check CHECK (
    action_type IN (
      'cp_events',
      'cp_ranking',
      'cp_level',
      'cp_nest',
      'none'
    )
  )
);

CREATE INDEX IF NOT EXISTS cp_events_active_priority_idx
  ON public.cp_events (is_active, priority DESC, start_at DESC);

ALTER TABLE public.cp_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read cp events" ON public.cp_events;
CREATE POLICY "Public read cp events"
  ON public.cp_events
  FOR SELECT
  TO public
  USING (true);
