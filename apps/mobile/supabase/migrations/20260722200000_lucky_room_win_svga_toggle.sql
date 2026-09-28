-- Temporarily disable in-room Lucky / Lucky Pro win SVGAs (fanbi + multiplier).
-- Top global win patti is unaffected. Toggle in Admin → Lucky gifts / System Config.
INSERT INTO public.system_settings (key, value, description)
VALUES (
  'lucky_room_win_svga_enabled',
  'false',
  'When true, room shows Lucky/Lucky Pro win fanbi + multiplier SVGA after a bonus. Set false if phones white-screen during those animations. Global top patti is separate.'
)
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = timezone('utc'::text, now());
