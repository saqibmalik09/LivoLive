# SK Live / LIVO Landing

Public marketing website for **SK Live (LIVO)** — the product landing and promotional web presence.

## Tech stack

- **Next.js** 16 (App Router)
- **React** 19 + TypeScript
- **Tailwind CSS** 4
- **Framer Motion**

## Setup

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

Environment files (`.env`, `.env.coolify`, and related `.env.*`) are included in this delivery. Adjust values for your environment as needed before running or deploying.

## Scripts

| Command         | Description              |
|-----------------|--------------------------|
| `npm run dev`   | Local development server |
| `npm run build` | Production build         |
| `npm run start` | Serve production build   |
| `npm run lint`  | ESLint                   |

## Build & deploy

**Local production:**

```bash
npm run build
npm run start
```

**Docker / Coolify:** A `Dockerfile` and `docker-compose.coolify.yml` are provided for containerized deployment. Ensure the included env files (or Coolify environment variables) match your target host before building or publishing the image.
