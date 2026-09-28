-- Dynamic room share domain (editable in Supabase Table Editor → system_settings)
INSERT INTO public.system_settings (key, value, description)
VALUES (
  'room_share_base_url',
  '___sk_live_land___',
  'Public HTTPS base for WhatsApp room invite links (no trailing slash). Example link: {base}/r/{roomId}'
)
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = timezone('utc'::text, now());
