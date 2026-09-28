# SK Live Admin

Next.js master/admin panel for **SK Live** (LIVO). Manage users, agencies, shop, gifts, games, salaries, withdrawals, messaging, and related live-platform configuration against Supabase.

## Requirements

- Node.js 20+
- npm

## Setup

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

Production:

```bash
npm run build
npm start
```

## Environment

This package includes environment files for local and Coolify deploys:

| File | Purpose |
|------|---------|
| `.env.local` | Local Next.js development |
| `.env.coolify` | Coolify / VPS deployment |

Typical variables:

- `NEXT_PUBLIC_SUPABASE_URL` — Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` — service role key (server-only)
- `ADMIN_PANEL_PASSWORD` — admin login gate (Coolify)
- `DATABASE_URL` — Postgres URL for migrations and scripts
- `BAISHUN_APP_ID`, `BAISHUN_APP_KEY`, `BAISHUN_APP_CHANNEL`, `BAISHUN_API_BASE` — Baishun game API

Keep these files private. Rotate credentials if the archive was shared outside your team.

## Docker / Coolify

- `Dockerfile` — multi-stage image using Next.js `standalone` output
- `docker-compose.coolify.yml` — Coolify stack with Traefik labels (`admin.skliveparty.online`)
- `nixpacks.toml` — Node 20 for Nixpacks

```bash
docker build \
  --build-arg NEXT_PUBLIC_SUPABASE_URL="$NEXT_PUBLIC_SUPABASE_URL" \
  --build-arg SUPABASE_SERVICE_ROLE_KEY="$SUPABASE_SERVICE_ROLE_KEY" \
  -t sklive-admin .
```

```bash
docker compose -f docker-compose.coolify.yml up -d --build
```

## Layout

| Path | Description |
|------|-------------|
| `app/` | App Router pages and server actions |
| `components/` | Admin UI |
| `lib/` | Server helpers (Supabase, audit, etc.) |
| `scripts/` | Migrations, seeds, uploads |
| `public/` | Static assets |
| `middleware.ts` | Auth / request middleware |

## Scripts

`package.json` defines seed and migration helpers (`apply-*-migration`, `seed-*`, asset uploads). Most require a DB URL in `.env.local`.

## Stack

Next.js 16, React 19, TypeScript, Tailwind CSS 4, Supabase, Recharts, Lucide, Sonner.
