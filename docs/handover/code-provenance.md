# Code provenance — which copy is authoritative

Reconciled 27 Sep 2026, comparing the client's archives against the live VPS file by file
(SHA-256 per file, excluding `node_modules`, `.next`, `.git`).

## Verdict: the VPS is the final code

For every service, `/opt/sklive-*` on the production VPS is authoritative. The client's
`Livo code.zip` is an **older snapshot, reformatted** — the archives were assembled on
20 Sep (every file in a given zip carries one identical timestamp, the signature of a bulk
copy, so zip mtimes say nothing about when code changed).

## Evidence

| Service | Formatting-only diffs | Real code diffs | Files only on VPS |
|---|---|---|---|
| admin | 0 | 13 | `lib/media-url.ts`, ranking-trigger script |
| master-panel | 0 | 6 | `ShopItemThumb.tsx`, `SvgaPreview.tsx`, `lib/media-url.ts` |
| gateway | 0 | 2 | — |
| super-admin | 26 | 25 | — |
| landing | 0 | 0 | — |

- **admin, master-panel, gateway** — VPS files were edited 22–24 Sep, *after* the zips were made,
  and the VPS carries code files the zips lack entirely. These are hotfixes applied directly on
  the server. Production is ahead.
- **super-admin** — the zip's "changes" are quote style, line reflow, and **stripped doc comments**.
  The VPS copy retains explanatory comments (e.g. the note on why the Super Admin panel is limited
  to ban/unban with no PII edit). Same logic, richer source on the VPS.
- **mobile** — the first archive (`sklive-mobile-source.zip`) is **v1.3.0+24**; the copy inside
  `Livo code.zip` is **v1.2.9+23**, an older release run through `dart format`. The newer one also
  carries four Supabase migrations dated 22–23 Sep and three feature files the older lacks, and
  the older contains nothing the newer is missing. The v1.3.0 copy is kept.
- **signing** — `sklive-mobile-signing.zip` is byte-identical to the keystore already in
  `secrets/signing/`. No conflict.

## What was merged in from the zips

Only files absent from the VPS and additive: `AGENTS.md`, `CLAUDE.md`, `README.md`, `.gitignore`,
`zuvo.toml`, `.env.coolify`, `.zuvo/project-ref`, and two gateway scripts
(`baishun_sync_gamelist.js`, `check-seats.js`). Deliberately **not** taken: `.env.local`
(stale secrets) and `tsconfig.tsbuildinfo` (build artifact).

Each service's live `.env` was pulled from the VPS into `secrets/env/<service>.env`.

## Verification

After merging, every service in `apps/` matches the VPS byte-for-byte on every file except the
`.env` moved into `secrets/`. Re-check any time with:

```bash
cd apps/<service> && find . -type f -not -name "._*" -print0 | xargs -0 shasum -a 256
```

## Beyond /opt — also verified and captured

- **Edge functions**: all 7 project functions deployed at
  `/data/coolify/services/mnq3.../volumes/functions/` are byte-identical to
  `apps/mobile/supabase/functions/`. (`hello` and `main` are Supabase scaffolding, no repo copy.)
  This also settles a Schedule A question: **Tulasi is integrated**, as the `tulasi-game` edge
  function — not via any service `.env`. A `zego-token` function is deployed too, so voice touches
  Zego as well as Orbit/LiveKit.
- **Coolify stacks**: the Supabase and LiveKit compose files live outside `/opt` under root-only
  `/data/coolify/services/`. Copied to `infra/coolify/`, with their env files in `secrets/env/`.

## Not verifiable from the server

The **mobile app** has no counterpart on the VPS — the Flutter source is not deployed there. The
v1.3.0+24 archive is the newest copy we hold, but nothing on the server can confirm it matches the
APK currently live on Google Play. That confirmation needs Play Console access.

## Consequence worth acting on

Production has been edited directly on the server, and the client's own archive is already behind.
Until this workspace is under git and deploys come from it, any redeploy from the client's copy
would silently revert the 22–24 Sep hotfixes.
