# zego-token Edge Function

Mints Zego Token04 for authenticated users. Client must NOT ship AppSign.

Token04 is implemented **inline** (no `zego-server-assistant` npm/esm import — that package is not on the registry and breaks Supabase bundling).

## Required secrets

```bash
supabase secrets set ZEGO_APP_ID=<numeric_app_id> --project-ref pbobnvkscssgfpynmdhl
supabase secrets set ZEGO_SERVER_SECRET=<32_char_server_secret> --project-ref pbobnvkscssgfpynmdhl
```

Use **ServerSecret** from Zego console (not AppSign).

## Deploy

```bash
cd sklive-mobile
supabase functions deploy zego-token --project-ref pbobnvkscssgfpynmdhl
```

## After deploy

1. Rotate AppSign in Zego console (old value was client-exposed).
2. Confirm `system_settings.zego_app_sign` is purged (migration does this).
3. Release Android with:
   `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`
