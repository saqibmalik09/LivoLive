# SK Live Super Admin

Next.js staff portal for the SK Live (LIVO) BD hierarchy: Super BD, BD Admin, and BD. Deployed at `super.skliveparty.online`.

## Features

- Role-based dashboard with analytics charts
- Team hierarchy, agencies, and hosts (scoped to each role’s subtree)
- Agency application approve / reject
- Create downline staff (Super BD → BD Admin, BD Admin → BD)
- My Agency management and moderation tools

## Stack

- Next.js 16 (App Router) + React 19
- Supabase Auth and RPCs
- Tailwind CSS 4, Recharts, Lucide

## Setup

```bash
cp .env.example .env.local
# Fill NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
# Or use the included .env.local / .env.coolify for the existing project

npm install
npm run dev
```

Dev server: [http://localhost:3003](http://localhost:3003)

Production:

```bash
npm run build
npm start
```

## Environment

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase (or Kong) API URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anon key |
| `NODE_OPTIONS` | Optional; `--max-http-header-size=1048576` avoids HTTP 431 on large cookies |

Included env files: `.env.local`, `.env.coolify`, `.env.example`, `.env.local.example`.

## Roles

| Role | Access |
|------|--------|
| Super BD | Full subtree; create BD Admin |
| BD Admin | Subtree; create BD |
| BD | Agencies / hosts; applications |

Sign in with the same SK Live account used in the main app (Google or email).

## Docker / Coolify

Multi-stage `Dockerfile` builds a Next.js standalone image on port 3000.

```bash
# Local / Coolify-style compose (requires external `coolify` network for Traefik)
docker compose -f docker-compose.coolify.yml --env-file .env.coolify up -d --build
```

Build args / runtime env: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`. Traefik labels target `super.skliveparty.online`.

## Project layout

| Path | Purpose |
|------|---------|
| `app/` | App Router pages (portal, login, auth callback) |
| `components/` | UI panels, charts, filters |
| `lib/` | Auth, Supabase clients, actions, permissions |
| `middleware.ts` | Session refresh |
| `public/` | Static assets |
