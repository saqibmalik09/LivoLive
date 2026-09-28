-- Party events: admin-selected screen template for in-app navigation.

ALTER TABLE public.party_events
  ADD COLUMN IF NOT EXISTS screen_template text NOT NULL DEFAULT 'cp_romance';

ALTER TABLE public.party_events
  DROP CONSTRAINT IF EXISTS party_events_screen_template_check;

ALTER TABLE public.party_events
  ADD CONSTRAINT party_events_screen_template_check CHECK (
    screen_template IN (
      'cp_romance',
      'recharge',
      'ranking',
      'tasks',
      'festival',
      'room_party'
    )
  );

-- Backfill from legacy action_type where screen_template is still default.
UPDATE public.party_events
SET screen_template = CASE action_type
  WHEN 'cp_ranking' THEN 'ranking'
  WHEN 'game_ranking' THEN 'ranking'
  WHEN 'gift_ranking' THEN 'ranking'
  WHEN 'wealth_ranking' THEN 'ranking'
  WHEN 'charm_ranking' THEN 'ranking'
  WHEN 'room_ranking' THEN 'ranking'
  WHEN 'agency_ranking' THEN 'ranking'
  ELSE screen_template
END
WHERE action_type IN (
  'cp_ranking',
  'game_ranking',
  'gift_ranking',
  'wealth_ranking',
  'charm_ranking',
  'room_ranking',
  'agency_ranking'
);

UPDATE public.party_events
SET action_config = action_config || jsonb_build_object(
  'cta_action',
  CASE action_type
    WHEN 'cp_ranking' THEN 'cp_ranking'
    WHEN 'game_ranking' THEN 'game_ranking'
    WHEN 'agency_ranking' THEN 'agency_ranking'
    WHEN 'charm_ranking' THEN 'charm_ranking'
    WHEN 'wealth_ranking' THEN 'wealth_ranking'
    WHEN 'room_ranking' THEN 'room_ranking'
    ELSE COALESCE(action_config->>'cta_action', 'gift_ranking')
  END
)
WHERE action_type IN (
  'cp_ranking',
  'game_ranking',
  'gift_ranking',
  'wealth_ranking',
  'charm_ranking',
  'room_ranking',
  'agency_ranking'
)
AND (action_config->>'cta_action') IS NULL;

COMMENT ON COLUMN public.party_events.screen_template IS
  'Flutter event detail layout: cp_romance, recharge, ranking, tasks, festival, room_party';
