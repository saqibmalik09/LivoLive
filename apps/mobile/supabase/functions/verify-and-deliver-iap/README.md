# verify-and-deliver-iap

Server-side Google Play purchase verification before coin credit.

## Secrets (Supabase Dashboard → Edge Functions → Secrets)

| Secret | Value |
|--------|--------|
| `GOOGLE_PLAY_PACKAGE_NAME` | `com.sklive.app` |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Full JSON key of a Play-linked service account |

Also available by default: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.

## One-time Google / Play setup

1. Google Cloud project linked to Play Console → enable **Google Play Android Developer API**.
2. Create a service account → download JSON key.
3. Play Console → **Users and permissions** → invite the service account email with permission to view financial / manage orders (purchase verification).
4. Set the two secrets above.

## Deploy

```bash
cd sklive-mobile
supabase functions deploy verify-and-deliver-iap --project-ref <YOUR_PROJECT_REF>
supabase secrets set GOOGLE_PLAY_PACKAGE_NAME=com.sklive.app
supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON="$(cat /path/to/play-sa.json)"
```

Apply SQL migration `20260808140000_secure_iap_google_verify.sql` (revokes client RPC).

## Smoke test

- Fake GPA + random token from a rooted/debug client → reject, no credit.
- Real internal-track purchase → one credit; retry → `duplicate: true`.
- Direct `rpc('deliver_iap_purchase')` as user JWT → permission denied.
