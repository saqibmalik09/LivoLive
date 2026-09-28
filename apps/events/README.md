# SK Live Events

Next.js frontend for **SK Live** party event pages (leaderboards, gift scoring, and rewards). Hosted for in-app WebViews and the public events domain (`events.skliveparty.online`).

Built with **Next.js 16**, **React 19**, **TypeScript**, **Tailwind CSS**, and **Supabase**.

## Features

- Event landing and themed campaign pages (for example `/14-august`)
- Live rankings and score display driven by Supabase
- Gift point rules and reward slot configuration from event `action_config`
- WebView session auth helpers for the SK Live mobile client

## Requirements

- Node.js 20+
- npm (lockfile included)

## Environment

This package includes environment files for local and Coolify deployments:

| File | Purpose |
|------|---------|
| `.env.example` | Template (empty values) |
| `.env.local` | Local Next.js development |
| `.env.coolify` | Coolify / production-style values |

Required variables:

```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
```

For local work, copy or use `.env.local` (Next.js loads it automatically). For Docker Compose / Coolify, align values with `.env.coolify` or a `.env` file as referenced by `docker-compose.coolify.yml`.

> **Note:** Client zips intentionally include existing `.env*` credentials so the app can run without re-entering secrets. Rotate keys if this archive is shared beyond your team.

## Setup

```bash
cd sklive-events
npm ci
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Development server |
| `npm run build` | Production build |
| `npm start` | Serve production build |
| `npm run lint` | ESLint |

## Project layout

```
app/                 Next.js App Router pages
  14-august/         August 14 campaign UI
lib/                 Supabase client, event APIs, WebView auth
public/              Static assets (campaign art, icons)
Dockerfile           Multi-stage production image
docker-compose.coolify.yml
```

## Docker

Build and run with Compose (expects Coolify external network `coolify` when using the provided compose file):

```bash
docker compose -f docker-compose.coolify.yml build
docker compose -f docker-compose.coolify.yml up -d
```

Build args / env must provide `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` (baked in at build time for the public Next.js client).

## License

Private — SK Live internal use.
