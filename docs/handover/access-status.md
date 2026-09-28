# Access status — as at 27 Sep 2026

Verified by direct login, not just received on paper.

## Held and working

| Access | Detail |
|---|---|
| VPS SSH | `ubuntu@51.222.81.97` — password auth; **passwordless sudo** confirmed |
| Host / Docker | full control via sudo; 29 containers healthy |
| Coolify | `sklivepk@gmail.com`, the only account, team **owner**; UI at `http://51.222.81.97:8000` |
| Postgres / Supabase | direct `psql` in `supabase-db-mnq3vesx0syflb0m0bot3oa2`; 5.8 GB, 4.65M transactions |
| Admin panel | password verified against deployed `ADMIN_PANEL_PASSWORD` |
| Master panel | operator `sonuking` — active, shared with client staff (8 operators total) |
| Domains / SSL | 8 hosts serving, Let's Encrypt auto-renew, valid to 13 Dec 2026 |

## Not yet held — owed under Clause 5.1(a)

- [x] Flutter app source — received 27 Sep, sorted to `apps/mobile/` (`sk_live` v1.3.0+24,
      Flutter SDK ^3.11.4, 483 Dart files). No git history in the archive.
- [x] Android upload keystore + `key.properties` — **VERIFIED 28 Sep**. Password opens it,
      private key is usable, and its certificate is the one signing the APK live to users, so
      updates will install over existing apps. Detail in `signing-and-releases.md`.
- [ ] Source repositories for the six web services, or confirmation that `/opt` is the only copy
- [ ] Google Play Console (listing assets did arrive in `apps/mobile/store/play/`)
- [ ] Firebase console (FCM) — client configs `google-services.json` / `GoogleService-Info.plist`
      are in the archive, but console access is still needed
- [ ] Domain registrar / DNS panel (nameservers: Hostinger `*.dns-parking.com`)
- [ ] VPS provider panel (reboot, snapshot, rescue)
- [ ] Orbit · Baishun · Jieyou · Tulasi dashboards
- [ ] `master` bootstrap password
- [ ] Dedicated master-panel operator account for Inexia, instead of sharing `sonuking`

## Discrepancies against the agreement

- **There is no iOS app.** Schedule A describes the mobile app as "Android (Google Play) and
  iOS (Apple App Store)" and lists Apple App Store In-App Purchase as an integrated Third-Party
  Service; Clause 1.1 ties "Resolve" to submitting builds to Google Play and/or the App Store.
  The product ships on **Android only** (`com.sklive.app`). The repo's `ios/` directory is stock
  Flutter scaffolding — automatic signing, no development team, never provisioned. Remove the iOS
  and Apple IAP references when Schedule A is amended, so we are not on the hook for a platform
  that does not exist.

- Schedule A lists **4** subdomains; Traefik serves **8** plus `voice-test.almuqeetmarketing.com`,
  a domain outside Livo's. `events.`, `super.`, `voice.` and the apex are being maintained
  without being in scope — amend Schedule A.
- Schedule A lists **Jieyou** and **Tulasi** as integrated game providers; no configuration for
  either exists in any service `.env`. Only **Orbit** (voice) and **Baishun** are wired.

## Risks recorded at handover (all pre-existing)

1. **No backups.** No cron, no Coolify scheduled backups, `/data/coolify/backups` empty.
   Nothing to maintain under Clause 2.1(d) — establishing this is Additional Work (Clause 3.1).
2. **No version control.** No git repo on the server; code hand-copied from a Mac
   (`._*` AppleDouble files present). No history, no rollback path.
3. Coolify admin UI on plain HTTP — owner password crosses the internet in cleartext.
4. `PasswordAuthentication yes` and no SSH keys on `ubuntu` — password-only exposure on port 22.
