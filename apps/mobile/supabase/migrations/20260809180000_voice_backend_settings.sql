-- Dual voice backend: Zego (default) or Orbit Voice (LiveKit VM).
-- Clients may read these keys (not secrets). Tenant API key stays in edge secrets.

INSERT INTO public.system_settings (key, value, description, updated_at)
VALUES
  (
    'voice_backend',
    'zego',
    'Room voice media backend: zego (default) or orbit (LiveKit / Orbit Voice VM). Admin Settings → Voice Backend.',
    now()
  ),
  (
    'orbit_api_url',
    '',
    'Orbit Voice API base URL (e.g. https://api.voice.example.com). Used when voice_backend=orbit.',
    now()
  ),
  (
    'orbit_livekit_url',
    '',
    'Orbit LiveKit WebSocket URL (e.g. wss://voice.example.com). Used when voice_backend=orbit.',
    now()
  )
ON CONFLICT (key) DO UPDATE
SET description = EXCLUDED.description,
    updated_at = now();
