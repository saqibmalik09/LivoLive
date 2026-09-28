# SK Live Master Panel

Operator / super-admin style Next.js panel for **LIVO / SK Live**. Use it to manage users (ban, VIP, profile, room, grants), staff hierarchy, agencies and transfers, shop grants, and optional audit logging against the Coolify Supabase backend.

Visual style matches `sklive-admin` (dark glass + purple accents). Built with **Next.js** (App Router).

## Requirements

- Node.js 18+ (LTS recommended)
- npm

## Setup

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Environment

This delivery includes environment files (for example `.env.local`, `.env.coolify`). Keep them private; do not publish them.

Typical variables:

| Variable | Purpose |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Coolify Supabase API URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (server only) |
| `MASTER_PANEL_PASSWORD` | Login password (cookie `master_session`) |

Local fallback if `MASTER_PANEL_PASSWORD` is unset: `master123`.

## Build

```bash
npm run build
npm start
```

Docker / Coolify: see `Dockerfile` and `docker-compose.coolify.yml`.

## Database (optional)

Optional audit-source migration:

```bash
docker exec -i "$COOLIFY_DB_CONTAINER" psql -U postgres -d postgres < supabase/migrations/20260914120000_master_panel_audit_source.sql
```

The panel uses the service role and existing RPCs (for example `create_business_staff`). The migration only documents or optionally extends a `source` CHECK if one exists.
