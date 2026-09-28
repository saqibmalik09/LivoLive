# Orbit Voice edge function (SK Live)

Deploy:

```bash
supabase functions deploy orbit-voice-session --project-ref pbobnvkscssgfpynmdhl
supabase secrets set \
  ORBIT_API_URL=http://34.89.138.245:3000 \
  ORBIT_LIVEKIT_URL=ws://34.89.138.245:7880 \
  ORBIT_TENANT_API_KEY=ovk_YOUR_PANEL_SECRET
```

Notes:
- `ORBIT_TENANT_API_KEY` is the Orbit panel API key (`ovk_…`), sent as `x-api-key`.
- App ID is **not** an edge secret — Orbit resolves it from the key via `resolve_api_key`.
- Admin: Settings → Voice Backend → switch to `orbit` and set the same URLs (optional; secrets override).
- Listeners: token only (no `/join`, no `GET /api/rooms` scan) — faster first remote audio.
- Seat mute → seats PATCH; speak → `/join`. Orbit room id via one POST upsert (no 100-room list).
- Client may send `on_seat: true` on claim so `canPublish` is minted even if DB seat row lags.
- `billing_only: true` skips token mint; join/mute run in background (local mic already flipped).
- Cached `orbit_room_id` skips room upsert.
- Timing: each hop is logged + returned as `timings` (`auth_getUser_ms`, `settings_ms`,
  `seat_lookup_ms`, `orbit_room_upsert_ms`, `orbit_join_ms` / `orbit_seats_mute_ms`,
  `orbit_token_ms`, `total_ms`). Dashboard → Edge Functions → `orbit-voice-session` → Logs.

Apply SQL migration `20260809180000_voice_backend_settings.sql`.
