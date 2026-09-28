# What to request from Daim (Livo Technology)

As at 27 Sep 2026. Grouped by urgency. Items 1–3 block work that is already being discussed.

## 1. Blocking the voice integration

- **`orbit-voice` Flutter package, version 0.4.0 — the full folder.**
  `pubspec.yaml` overrides this package to a local path `../../orbit-voice/packages/orbit_voice`
  that was not included in any archive. Without it the Android app **cannot be compiled at all**,
  and we cannot audit how the voice SDK connects. The pub.dev 0.3.0 release is explicitly noted
  in the code as not equivalent. Whoever built the app, or the Orbit vendor, has this.
- **LiveKit API key and secret — and confirmation of which server.**
  A LiveKit server is already running on Livo's own VPS answering `voice.skliveparty.online`
  (alongside `voice-test.almuqeetmarketing.com`). The integration guide says the voice server is
  "hosted separately from your infrastructure". These cannot both be true. Which instance is the
  target?
- **Is Orbit (`api.getorbitlive.com`) being replaced or kept?** Production currently routes all
  voice through Orbit, which also handles billing hooks and seat/publish gating. If Orbit goes,
  that logic has to be rebuilt — it is the largest hidden cost in this change.

## 2. Blocking mobile releases

- **Is the app on Google Play?** If yes: Play Console access, and confirmation of whether
  Play App Signing is enabled. The `app_versions` table distributes Android as a direct APK from
  Supabase storage, so Play may not be the live channel — but `verify-and-deliver-iap` and Play
  Billing suggest a listing exists.
- **Confirm the release channel.** Is `app-releases/app-release.apk` in Supabase storage the
  channel users actually update from? The file there is dated 14 Sep.
- **Firebase console access** (FCM). The in-app config files are present; console access is not.

## 3. Who else is changing production

Between **22 and 24 September**, files in `/opt/sklive-admin`, `/opt/sklive-master-panel` and
`/opt/sklive-gateway` were edited **directly on the server** — these fixes exist nowhere else, not
even in Livo's own archives. Clause 5.1(e) requires prior notice before the client or any third
party changes the platform.

Ask: **who has server access, and will they notify us before making changes?** If direct edits
continue during the term, same-day bug resolution under Clause 4.3 cannot be guaranteed, and a
redeploy could silently revert their work.

## 4. Access still outstanding (Clause 5.1(a))

- Domain registrar / DNS panel
- VPS provider panel (reboot, snapshot, rescue)
- Orbit, Baishun, Jieyou and Tulasi dashboards
- The `master` bootstrap password, and a dedicated master-panel operator account for Inexia
  (we are currently sharing `sonuking`, an account someone else uses)
- Confirmation that no git repository exists anywhere — so far, none has been found on the server
  or in any archive

## 5. Contract housekeeping

- **Schedule A needs amending on four points:**
  1. There is no iOS app — remove iOS and Apple App Store IAP.
  2. Eight subdomains are served, not four (`events.`, `super.`, `voice.`, apex/`www`), plus
     `voice-test.almuqeetmarketing.com`, a domain that is not Livo's.
  3. Tulasi *is* integrated — as a Supabase edge function, not via any service config.
  4. Zego is present as a second voice backend and is not mentioned at all.
- **Fee for Months 2–3 must be agreed by 26 Oct 2026** (Clause 6.2), otherwise PKR 20,000/month
  continues by default (Clause 6.3).
- **Confirm the first month's PKR 20,000 has been paid** — it was due within 3 days of 27 Sep.

## 6. Two decisions to put to him in writing

- **There are no backups.** No cron, no Coolify schedule, empty backup directory, on a 5.8 GB
  database holding 4.65M transactions. Nothing existed at the Effective Date, so under Clause
  2.1(d) there is nothing to maintain — setting it up is Additional Work. Get the risk
  acknowledged in writing either way.
- **There is no version control.** Approve a git baseline of the reconciled code, so hotfixes stop
  living only on one unbacked-up server.

Both, and the voice integration, are Additional Work under Clause 3.1 — each needs a written
quote and his written approval before work starts (Clause 3.2).
