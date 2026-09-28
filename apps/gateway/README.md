# SK Live Realtime Gateway

Socket.IO realtime gateway for SK Live rooms. Handles live room events, gifts, DMs, voice (Orbit/LiveKit), and Baishun game merchant APIs. State is coordinated over Redis; durable data goes through Postgres (Supabase).

## Stack

- **Node.js** (>=18) + Express + Socket.IO
- **Redis** — pub/sub adapter and ephemeral room/seat state
- **Postgres** — ledger, gifts, and persistence via `DATABASE_URL`
- **Orbit** — voice/LiveKit token and room APIs
- **Baishun** — game list sync and merchant callbacks

## Quick start

```bash
npm install
cp .env.coolify .env   # or use the provided .env
npm start              # node src/server.js
# npm run dev          # watch mode
```

Health check: `GET /health` (default port `3000`).

## Environment

Required / commonly used variables (see `.env` / `.env.coolify`):

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP/Socket.IO listen port |
| `SUPABASE_URL` | Auth / JWKS base URL |
| `SUPABASE_JWT_SECRET` | HS256 JWT verification |
| `DATABASE_URL` | Postgres connection string |
| `REDIS_URL` | Redis URL (adapter + state) |
| `ORBIT_*` | Orbit API + LiveKit + tenant key |
| `BAISHUN_*` | Baishun app credentials and API base |
| `LUCKY_RTP_MIN` / `LUCKY_RTP_MAX` | Lucky gift RTP band |

Do not commit secrets. `.gitignore` already excludes `.env` and `.env.*`.

## Scripts

- `npm start` — production entry (`src/server.js`)
- `npm run dev` — same with `--watch`
- `scripts/baishun_sync_gamelist.js` — sync Baishun game list
- `scripts/check-seats.js` — seat/state sanity check

## Docker / Coolify

```bash
docker compose -f docker-compose.coolify.yml --env-file .env up -d --build
```

Compose starts Redis (`sklive-gateway-redis`) and the gateway image from `Dockerfile` (Node 20 Alpine). Traefik labels target `gateway.skliveparty.online` on the Coolify network; the gateway also joins the Supabase Docker network to reach Postgres.

## Layout

```
src/          Gateway server and modules
scripts/      Ops helpers
Dockerfile    Production image
docker-compose.coolify.yml
zuvo.toml     Deploy metadata
```
