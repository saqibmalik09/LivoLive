# Livo / SK Live Party — Engineering Handover

Last updated: 2026-10-12

Read this top to bottom before touching anything. The traps section exists
because each item in it cost real downtime or a wrong answer to the client.

---

## 1. What this is

Android voice-chat / party app ("LIVO", package `com.sklive.app`), Flutter
front end on a self-hosted Supabase backend, plus a Node realtime gateway and
four Next.js admin panels.

- **Client:** Livo Technology.
- There is **no git
  repo** — the local tree *is* the source of truth. No commits, no branches.
  Back up before destructive edits.
- The manager who reports bugs is a non-technical WhatsApp contact; bug reports
  arrive as screenshots in Roman Urdu. Read them literally — "2-3 second ke baad
  speaker pe chala jata hai" was the detail that solved the headset bug.

---

## 2. Servers

| | Old | New (current) |
|---|---|---|
| IP | `51.222.81.97` | `13.140.57.228` (Mumbai) |
| user | `ubuntu` | `sklive` (passwordless sudo) |
| status | **stopped DB, keep for rollback** | **live, all traffic** |

Migration completed 2026-10-10/11. DNS for all 10 hostnames points at the new
server. The old box still runs its app containers but its **database is
stopped** — do not start it, two live databases will diverge and the daily
payout cron would pay twice.

### Hostnames (all → 13.140.57.228)
`skliveparty.online`, `www`, `api`, `gateway`, `admin`, `super`, `master`,
`merchant`, `events`, `voice`

`api.` is Supabase/Kong — the app's main endpoint. `gateway.` is the realtime
Node gateway. `voice.` is self-hosted LiveKit.

### Access
- From the Mac: SSH to `sklive@13.140.57.228` (password auth; **ask the project owner**).
- The new server reaches the old one with a one-way key:
  `/home/sklive/.ssh/migrate_old` → `ubuntu@51.222.81.97`.
- Helper scripts live in `ops/handover/` (see §8). They expect a file named
  `pw_new` next to them containing the sklive password — create it yourself,
  it is deliberately **not** committed.

---

## 3. Stack layout on the new server

Coolify-managed Docker. ~30 containers.

- **Supabase** — `/data/coolify/services/mnq3vesx0syflb0m0bot3oa2/`
  DB container: `supabase-db-mnq3vesx0syflb0m0bot3oa2` (PostgreSQL 15.8)
  Bring up: `docker compose -f docker-compose.yml up -d`
  `supabase-edge-functions` **additionally** uses
  `-f docker-compose.edge-secrets.yml`. The other override files
  (`google-auth`, `email-autoconfirm`) are **vestigial** — do not add them.
- **LiveKit (voice)** — `/data/coolify/services/rr1rnq2qirqyr2yinczwpsse/`
  Carries the Traefik labels for `voice.skliveparty.online`. A *second*
  LiveKit (`trzes9cwliufu1bgylhjqp59`, test domain
  `voice-test.almuqeetmarketing.com`) is **stopped** — it was holding ports
  7881/7882.
- **App layer** — `/opt/sklive-{gateway,admin,super-admin,master-panel,merchant-panel,events,landing}/`
  each with `docker-compose.coolify.yml`, images tagged `:local`, built on the
  box. **Not** under `/data/coolify`.
- **Object storage** — MinIO, bind-mounted at
  `/data/coolify/services/mnq3vesx0syflb0m0bot3oa2/volumes/storage` (~25 GB).

---

## 4. Salary / payroll model (gets asked about constantly)

Two **different** cycles. Getting this backwards broke agency pay once already.

| | Period | Covers | Paid |
|---|---|---|---|
| **Agency + Host** | `YYYY-MM-A` / `-B` | 1–15 / 16–end | **16th** / **1st** |
| **BD** | `YYYY-MM-M` | whole month | **1st** |

- `get_period_id_for_ts()` returns **A/B** (agency/host).
- BD resolves its own monthly period via `bd_period_ids_for()`, which prefers
  `-M` and falls back to the halves for months before the switch (Jul–Sep 2026).
- `run_scheduled_agency_period_payouts()` — day 1 pays previous month `-B`,
  day 16 pays current month `-A`.
- Agency level 1 needs **500,000 charm**; most agencies legitimately show $0.
- Charm lives in `host_period_stats`, keyed by `period_id`. If you change the
  period scheme you must migrate that data too.

Panel: `lib/salary-hub/constants.ts` has `cycleForRole()` and
`agencyPeriodsFor()`. Host/agency read the halves via `.in("period_id", …)`;
BD reads the month.

---

## 5. Voice architecture

Two backends. `system_settings.voice_backend` selects; it is currently
**`livekit`**.

1. **Gateway path (primary)** — app → `gateway.skliveparty.online` socket →
   `voice:token` → self-hosted LiveKit at `wss://voice.skliveparty.online`.
   Config comes from **`system_settings`** (`livekit_url`, `livekit_api_key`,
   `livekit_api_secret`), *not* env vars.
2. **Edge-function fallback** — `orbit-voice-session` → Orbit
   (`wss://live.getorbitlive.com`). Only used when the gateway socket is down.

The gateway logs one line per request:
`[voice:livekit] ok room=… publish=… seat=… perm=…`
`perm=updated` is healthy. `perm=failed_503` means `voice.skliveparty.online`
has no backend.

---

## 6. Known-good verification commands

```bash
# voice health (last 2 min) — expect perm=updated, zero failed_503
docker logs --since 120s sklive-gateway 2>&1 | grep -oE "perm=[a-z0-9_]+" | sort | uniq -c

# container health
docker ps --format '{{.Names}}|{{.Status}}' | grep -Ei 'restarting|unhealthy|Exited'

# slow queries (the recurring failure mode — see traps)
SELECT round(mean_exec_time)||'ms', calls, left(query,70)
  FROM pg_stat_statements WHERE mean_exec_time > 2000 AND calls > 3
  ORDER BY mean_exec_time DESC LIMIT 10;
```

**QA account:** ask the project owner for the QA login.
VIP level and inventory can be edited directly on this user for testing —
reset it afterwards.

---

## 7. Traps — every one of these cost real time

1. **Verify the build exit status, not a grep.** A panel rebuild failed on a
   type error for two cycles while Docker silently redeployed the *old* image.
   Grepping the bundle for a string that already existed "confirmed" a fix that
   was never deployed. Check `docker compose build` returns 0, then grep for a
   string that is **new** in your change.
2. **Statement timeouts are the recurring bug.** `authenticated` has
   `statement_timeout = 8s`. Three separate client-reported "bugs" were really
   `57014` timeouts on tables that outgrew their indexes
   (`gift_logs` 5M rows, `transactions` 11.4M). The app catches the error and
   renders a *misleading* message — "User not found", or zeros. **Always check
   `pg_stat_statements` before believing a UI symptom.**
3. **An access denial can look like zero data.** `get_agency_period_targets`
   returned `{"success": false, "message": "No access"}` for plain hosts and the
   app rendered it as "Agency LV 0, charm 0, empty host list".
4. **`agency_members` has no `owner` role** — only `host` and `admin`. Role
   checks that expect `owner` silently exclude everyone.
5. **AppleDouble files (`._*`)** copied from macOS break the Next.js panel
   build. Delete before building.
6. **Never `pg_dump` this database for migration.** It silently restores
   `auth.users`, `storage.objects` and `cron.job` as **0** rows. Copy PGDATA
   physically (both servers run the identical image).
7. **LiveKit needs explicit DNS** in its compose (`8.8.8.8`, `1.1.1.1`).
   Without it the container inherits the host's `127.0.0.53` stub, cannot reach
   STUN, and crash-loops.
8. **`coolify-proxy` must be attached to the Supabase docker network**, or Kong
   is unreachable and `api.` dies.
9. **Only ever send the APK from `ops/releases/`.** Old builds in
   `_ARCHIVE_DO_NOT_SEND/`. A stale older APK sitting beside the
   real one once went to the client as "the fix".
10. **The emulator is slow but usable.** AVD `LivoLite`, 720x1600, 4 cores,
    4 GB, `-gpu host`. Higher resolutions hang the VM. `adb shell input tap`
    often misses — use `input swipe x y x y 300`. `input text` truncates at
    `.` and `@` — use `KEYCODE_PERIOD` / `KEYCODE_AT`.

---

## 8. Build & release

```bash
export PATH="/usr/local/share/flutter/bin:$PATH"
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
cd apps/mobile
flutter test                     # must be all green
flutter build apk --release
```

Then **always**:
- confirm no source is newer than the APK,
- check `versionCode` with `aapt2 dump badging`,
- confirm the signature is `CN=SK Live` (not a debug key),
- grep `lib/arm64-v8a/libapp.so` for a string **new** in your change,
- copy to `ops/releases/SKLive-vX.Y.Z-buildNN-FINAL.apk`.

Current release: **v1.6.5 build 59**.

---

## 9. Open items (nothing in this list is fixable by a rebuild)

1. **Gift animations.** 2.36M sends in 7 days, **0.2% animate**. Real
   Gift-category items (LOVE KISS etc.) animate fine. The volume is
   **Lucky / Lucky Pro** game items (Gold 1.75M sends, Whisky 129k…) which have
   **no `svga_url`**. Needs a client decision + `.svga` files.
2. **165 missing image files.** Point at a suspended Supabase project
   (`wbwvtsnuvenxvetbhupf.supabase.co`, HTTP 402) and are **404 on our storage
   too** — never migrated. 9 wealth entry banners, 6 VIP badges, 100 charm
   badges, 50 CP badges. Needs the original files.
3. **Entrance effects:** 143 of 274 equipped are **expired** so they correctly
   do not play. Product decision: should the UI still show them as equipped?
4. **Headset audio** — fixed in v1.6.5 but **never tested on real hardware**.
   Test: join a room, *then* plug in a headset, wait past 5 seconds.
5. **Two queries averaging 2.8s / 2.1s** — under the 8s limit, not yet failing.
   Same trajectory as the three that already broke.
6. **Old server decommission** once confident.

---

## 10. Starting prompt for a fresh session

> You are taking over maintenance of Livo / SK Live Party, an Android
> voice-chat app with a self-hosted Supabase backend. Read
> `/Users/macbook/Downloads/Softwares/livo-sklive/HANDOVER.md` in full before
> doing anything — it documents the servers, the two different payroll cycles,
> the voice architecture, and ten traps that have each caused real downtime.
>
> There is no git repo; the local tree is the source of truth, so back up before
> destructive edits. The production database is live with ~8,700 users and real
> money flows through it — verify with read-only queries before changing
> anything, and never start the old server's database.
>
> When a bug is reported, check `pg_stat_statements` for statement timeouts
> before trusting the UI message: three "bugs" have turned out to be 8-second
> query timeouts that the app rendered as misleading text. Verify fixes against
> the live system, not just the source — and confirm builds exit 0 rather than
> grepping for strings that may predate your change.
>
> I will give you the server password and QA credentials when you need them.
