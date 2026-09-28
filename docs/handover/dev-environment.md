# Development environment

## Status

| Surface | Can we fix bugs today? |
|---|---|
| Admin, master, super-admin, events, landing panels | **Yes** |
| Node/Socket.IO gateway | **Yes** |
| Supabase edge functions (9 deployed) | **Yes** |
| Database / data-integrity fixes | **Yes** |
| Flutter app — non-voice code | **Yes, via the dev stub below** |
| Flutter app — voice | **No.** Needs the real `orbit_voice` 0.4.0 |
| Shipping an Android release | Signing verified; blocked only by `orbit_voice` |

## Deploying a web fix

Services build from their own directory on the VPS — Coolify does not pull from git:

```bash
cd /opt/sklive-<service>
sudo cp -a . ../sklive-<service>.bak-$(date +%F)      # no git on the server: do this first
sudo docker compose -f docker-compose.coolify.yml up -d --build
```

Edge functions live at
`/data/coolify/services/mnq3vesx0syflb0m0bot3oa2/volumes/functions/<name>/index.ts`
and take effect on container restart.

There is **no staging environment** — changes land on production, against live users.

## The orbit_voice development stub

`apps/mobile/pubspec.yaml` overrides `orbit_voice` to `../../orbit-voice/packages/orbit_voice`.
The client has never supplied that package, so a stub lives there implementing the 36 members
the app actually uses. It is gitignored.

Only one file imports the package — `lib/core/services/orbit_voice_session_service.dart` — and
the remaining ~134 references in the app go through that wrapper, which is why a stub is enough
to unblock everything else.

**`OrbitEngine.loginRoom()` throws on purpose.** The stub can never look like working voice.
`kOrbitVoiceIsDevStub` is `true` whenever it is active.

**Never build a release with the stub in place.** When the real package arrives, delete the whole
`orbit-voice/` directory, drop the genuine one at the same path, and run `flutter pub get`.

## Local toolchain

Present: Node 24, npm 11, Android SDK (build-tools 35 + 36), git, openssl, Docker CLI.
Docker daemon is **not running locally**, so image builds happen on the VPS.
Installed for this project: OpenJDK (Gradle) and the Flutter SDK.

`keytool`/`java` shipped by macOS are stubs with no runtime — use `openssl` for keystore work,
as in `signing-and-releases.md`.

## First fix applied (28 Sep 2026)

`lib/features/home/presentation/pages/family_management_screen.dart:757` — `_buildStackedBadge`
declared its parameter as `FutureProvider<String?> Function(int)`, but `wealthBadgeProvider`,
`charmBadgeProvider` and `familyBadgeProvider` are all declared
`FutureProvider.autoDispose.family<String?, int>` in `lib/core/providers/profile_provider.dart`.
That produced three `argument_type_not_assignable` **errors**, which would fail a release build.

Corrected to `AutoDisposeFutureProvider<String?> Function(int)`. `flutter analyze` now reports
**0 errors** (48 warnings, 531 info — all pre-existing lint).

These errors were **pre-existing in the v1.3.0 source**, not introduced by the stub: the only
dependency changes from `pub get` were dropping the real `orbit_voice`'s transitives
(`livekit_client`, `sdp_transform`, `asn1lib`, `mime_type`) and minor bumps to `intl`, `matcher`,
`meta`, `test_api` and `vector_math`. Riverpod was untouched.

This is very likely **why v1.3.0 was never released** — it did not compile.

## Lockfile handling

`flutter pub get` rewrote `apps/mobile/pubspec.lock` (orbit_voice 0.4.0 → 0.4.0-stub.1) and
`analysis_options.yaml`. The originals as delivered by the client are preserved at
`ops/original-lockfiles/`. Restore them when the real package arrives.

## What the dropped dependencies tell us

The real `orbit_voice` 0.4.0 depends transitively on **`livekit_client` 2.11.0** — the official
LiveKit Flutter SDK. So the app is a standard LiveKit client underneath, which makes a
backend-only voice migration (mint tokens server-side, hand the app a different `livekitUrl`)
substantially more plausible than the vendor's integration guide implies.

## Build pipeline proven (28 Sep 2026)

`flutter build apk --debug --target-platform android-arm64` completed successfully — first Gradle
run took ~32 minutes, subsequent builds are far quicker. It produced
`com.sklive.app` **versionCode 24 / versionName 1.3.0**, the first time v1.3.0 has ever been built.

So the full chain works: resolve → analyse → compile → signed artifact. The only thing still
missing for a *shippable* build is the genuine `orbit_voice` package.

## Is a given build shippable?

A build made with the stub has no native denoise library. Check before releasing anything:

```bash
unzip -Z1 <file>.apk | grep -c '^lib/arm64-v8a/liborbit_denoise.so'
# 1 = real orbit_voice was used, build is a release candidate
# 0 = STUB build, voice is dead, DO NOT SHIP
```

The production APK (v1.2.5, live to users) returns 1. Any build made today returns 0.
