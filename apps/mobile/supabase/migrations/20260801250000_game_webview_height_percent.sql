-- Per-game room WebView sheet height (% of screen). Admin-editable.

ALTER TABLE public.game_configs
  ADD COLUMN IF NOT EXISTS webview_height_percent integer NOT NULL DEFAULT 70;

ALTER TABLE public.game_configs
  DROP CONSTRAINT IF EXISTS game_configs_webview_height_percent_check;

ALTER TABLE public.game_configs
  ADD CONSTRAINT game_configs_webview_height_percent_check
  CHECK (webview_height_percent >= 40 AND webview_height_percent <= 95);

COMMENT ON COLUMN public.game_configs.webview_height_percent IS
  'Room in-app game WebView sheet height as % of screen (40–95). Default 70.';
