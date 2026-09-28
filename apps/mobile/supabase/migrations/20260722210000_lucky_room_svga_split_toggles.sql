-- Split Lucky room win SVGA toggles: fanbi vs multiplier (independent).
-- Per-row multiplier toggles in lucky_bonus_multiplier_svgas stay as before.
INSERT INTO public.system_settings (key, value, description)
VALUES
  (
    'lucky_room_fanbi_svga_enabled',
    'false',
    'Room fanbi SVGA (beaver) after Lucky/Lucky Pro bonus. Independent of multiplier SVGA.'
  ),
  (
    'lucky_room_multiplier_svga_enabled',
    'false',
    'Master switch for all room multiplier (xN) SVGAs after Lucky/Lucky Pro bonus. Individual rows still need is_enabled=true.'
  )
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description,
  updated_at = timezone('utc'::text, now());

-- Keep legacy combined key in sync description (optional leftover).
UPDATE public.system_settings
SET description = 'Deprecated: use lucky_room_fanbi_svga_enabled + lucky_room_multiplier_svga_enabled',
    updated_at = timezone('utc'::text, now())
WHERE key = 'lucky_room_win_svga_enabled';
