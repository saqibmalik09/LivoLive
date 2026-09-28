# Coolify-managed stacks

These compose files are **not** in `/opt` — Coolify keeps them under
`/data/coolify/services/<id>/`, which is root-only. Pulled 27 Sep 2026.

| Folder | Coolify service id | What it runs |
|---|---|---|
| `supabase/` | `mnq3vesx0syflb0m0bot3oa2` | self-hosted Supabase: Postgres, Auth, Storage, Realtime, Kong, Studio, edge functions, minio, analytics |
| `livekit/` | `rr1rnq2qirqyr2yinczwpsse` | LiveKit voice server + its Redis |

The Supabase stack has override files layered alongside the main compose:
`docker-compose.edge-secrets.yml`, `docker-compose.google-auth.yml`,
`docker-compose.email-autoconfirm.yml`.

Matching `.env` files are in `secrets/env/coolify-supabase.env` and `coolify-livekit.env`.

**Note:** the server also holds several `docker-compose.yml.bak-*` files dated 15 and 22 Sep,
evidence that this stack has been edited by hand in place. Not copied here — they are stale
snapshots, but they confirm there is no change history for the infrastructure either.

**Edge functions** live at `/data/coolify/services/mnq3.../volumes/functions/`. All seven
project functions are byte-identical to `apps/mobile/supabase/functions/`; the deployed
`hello` and `main` are Supabase's own scaffolding and have no repo counterpart.
