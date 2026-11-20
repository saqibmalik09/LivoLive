# Livo / SK Live Party — maintenance workspace

Production: `51.222.81.97` (`vps-1873f92d`), Coolify-orchestrated Docker, self-hosted Supabase.

## How to use this folder

**Drop anything into `_inbox/`.** Zips, folders, screenshots, keystores, SQL dumps, WhatsApp exports —
no need to name or place them. Tell me it's there and I'll sort it into the tree below, renaming and
unpacking as needed. If something is ambiguous I'll ask before moving it.

## Where things go

| Path | Holds | Maps to production |
|---|---|---|
| `apps/mobile/` | Flutter app source | Google Play + App Store builds |
| `apps/admin-panel/` | Next.js admin | `/opt/sklive-admin` → admin.skliveparty.online |
| `apps/master-panel/` | Next.js master panel | `/opt/sklive-master-panel` → master.skliveparty.online |
| `apps/super-admin/` | Next.js super admin | `/opt/sklive-super-admin` → super.skliveparty.online |
| `apps/events/` | Next.js events site | `/opt/sklive-events` → events.skliveparty.online |
| `apps/landing/` | Next.js landing | `/opt/sklive-landing` → skliveparty.online |
| `apps/gateway/` | Node / Socket.IO room gateway | `/opt/sklive-gateway` → gateway.skliveparty.online |
| `infra/compose/` | `docker-compose.coolify.yml` per service | deployment definitions |
| `infra/coolify/` | Coolify config, app settings, notes | Coolify UI on `:8000` |
| `infra/supabase/` | migrations, schema dumps, SQL, edge functions | supabase-* containers |
| `infra/traefik/` | routing rules, cert/domain notes | coolify-proxy |
| `docs/handover/` | access checklist, audit findings, code provenance | — |
| `docs/runbooks/` | restart / redeploy / rollback / restore procedures | — |
| `ops/scripts/` | maintenance and deploy scripts | — |
| `ops/backups/` | local DB dumps (never committed) | — |
| `secrets/env/` | `.env` files pulled from the server | — |
| `secrets/signing/` | Android keystore, iOS certs & provisioning | — |

## Rules I follow when sorting

1. `secrets/` and `ops/backups/` are gitignored and never leave this machine.
2. Source that mirrors a deployed service keeps the server's own layout, so a diff against
   `/opt/sklive-*` stays meaningful.
3. `.env` files are copied into `secrets/env/<service>.env`, never into the app folder.
4. Nothing is overwritten — an incoming file that clashes is suffixed with its date and flagged.
5. `_inbox/` is cleared only after each file has a home.

## Which copy of the code is real

`apps/` mirrors the **production VPS**, which is authoritative — the client's archives are older,
reformatted snapshots that are already missing server-side hotfixes. See
`docs/handover/code-provenance.md` before restoring anything from a client zip.

## Open gaps

Flutter source · Android keystore + iOS certs · Play Console · App Store Connect · Firebase ·
domain registrar / DNS · VPS provider panel · Orbit, Baishun, Jieyou, Tulasi dashboards ·
`master` bootstrap password · a dedicated master-panel operator account for the maintainer.

## Known risks at handover

- **No backups anywhere** — no cron, no Coolify schedule, empty backup dir, 5.8 GB live DB.
- **No version control on the server** — code hand-copied, no history, no rollback.
- Coolify admin served over plain HTTP; SSH is password-only with no keys installed.
