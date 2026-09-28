-- Game Control admin: maintenance flags + ensure engine mode setting

ALTER TABLE public.game_configs
  ADD COLUMN IF NOT EXISTS maintenance_mode boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS maintenance_message text NOT NULL DEFAULT
    'This game is under maintenance. Please try again later.';

INSERT INTO public.system_settings (key, value, description)
VALUES (
  'game_control_mode',
  'random',
  'H5 game engine mode: random | house_optimized'
)
ON CONFLICT (key) DO NOTHING;
