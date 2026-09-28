-- Per-user show/hide for room / SU / home games.
-- No rows for a target => everyone sees it (current default).
-- mode = hide_from  => listed users do NOT see it
-- mode = show_only  => ONLY listed users see it

CREATE TABLE IF NOT EXISTS public.room_game_visibility (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope text NOT NULL CHECK (scope IN ('category', 'game_config', 'tulasi_game')),
  target_id text NOT NULL,
  mode text NOT NULL CHECK (mode IN ('hide_from', 'show_only')),
  user_id uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (scope, target_id, user_id)
);

CREATE INDEX IF NOT EXISTS room_game_visibility_target_idx
  ON public.room_game_visibility (scope, target_id);

CREATE INDEX IF NOT EXISTS room_game_visibility_user_idx
  ON public.room_game_visibility (user_id);

ALTER TABLE public.room_game_visibility ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "room_game_visibility_select_auth" ON public.room_game_visibility;
CREATE POLICY "room_game_visibility_select_auth"
  ON public.room_game_visibility
  FOR SELECT
  TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.room_game_visibility TO authenticated;

COMMENT ON TABLE public.room_game_visibility IS
  'Audience rules: hide_from / show_only users per category, game_config, or tulasi_game.';
