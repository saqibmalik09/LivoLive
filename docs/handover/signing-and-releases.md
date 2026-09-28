# Android signing and release state

Verified 28 Sep 2026, without a JDK — macOS ships `keytool`/`java` as stubs with no runtime, so
the keystore was opened with `openssl` and the APK signatures parsed directly from the
APK Signing Block.

## The keystore is confirmed good

| Check | Result |
|---|---|
| Password in `key.properties` opens the keystore | **Yes** |
| Alias | `upload` — matches `key.properties` |
| Private key extractable | **Yes**, RSA 2048 |
| Certificate subject | `C=PK, ST=Sindh, L=Karachi, O=SK Live, OU=Mobile, CN=SK Live` |
| Certificate expires | 4 Dec 2053 |
| Cert SHA-256 | `44785925...e168bf5a` |

**It is the real production signing key.** The APK currently being served to users is signed with
this exact certificate, so we can ship updates that install over existing apps. This closes the
biggest open risk from handover.

## Three different generations are in play

| Where | versionName | versionCode | Notes |
|---|---|---|---|
| **Live to users** (Supabase `app-releases/app-release.apk`) | **1.2.5** | **19** | 209,788,827 bytes, uploaded 14 Sep |
| **APK supplied 28 Sep** (`ops/releases/`) | **1.2.9** | **23** | 212,080,631 bytes — a different binary, never published |
| **Newest source we hold** (`apps/mobile`) | **1.3.0** | **24** | never built or shipped |

So users are running code **two generations behind** the newest source. Neither 1.2.9 nor 1.3.0
has ever reached them.

`app_versions` gates Android at `min_version = 1.1.0` with `is_force_update = true`.

## How to reproduce these checks

```bash
# keystore (no JDK needed)
PW=$(grep '^storePassword=' secrets/signing/key.properties | cut -d= -f2-)
openssl pkcs12 -in secrets/signing/upload-keystore.jks -nokeys -clcerts -passin pass:"$PW" \
  | openssl x509 -noout -subject -enddate -fingerprint -sha256

# APK version, from the Android SDK's native aapt2
~/Library/Android/sdk/build-tools/36.0.0/aapt2 dump badging <file>.apk | head -1
```

The APK signer certificate is in the APK Signing Block (v2 scheme), not `META-INF/*.RSA` — there
are no JAR signature files in these builds.

## Still required before a release can be built

The app **cannot be compiled** until the `orbit_voice` 0.4.0 package arrives — `pubspec.yaml`
overrides it to `../../orbit-voice/packages/orbit_voice`, which no archive has included.
Its native library `liborbit_denoise.so` is present in the APK, confirming it is a real
dependency and not dead config.

Also needed locally (no credentials required — we can install these): Flutter SDK, Dart, and a
real JDK. The Android SDK is already present with build-tools 35 and 36.

## Play Console confirmation (28 Sep 2026)

The **app signing key certificate** in Play Console matches our keystore on all three
fingerprints (MD5, SHA-1, SHA-256 `44:78:59:25:…:BF:5A`).

That is the certificate Google signs releases with, so:

- Builds delivered through Play and builds delivered through the Supabase APK channel carry the
  **same signature**.
- The two install bases are interchangeable — a Play install can be updated by the direct APK and
  vice versa.
- The `app_versions` force-update, which points every Android user at
  `app-releases/app-release.apk`, is therefore safe for Play-installed users too.

This is the good outcome. Had Google been re-signing with a different key, the two channels would
have been mutually un-installable.

## Release procedure (both channels)

Prerequisite: the genuine `orbit_voice` 0.4.0. Nothing below may be done with the dev stub.

1. Delete the stub: `rm -rf orbit-voice/`, drop the real package at the same path.
2. Restore the client's lockfile: `cp ops/original-lockfiles/pubspec.lock.original apps/mobile/pubspec.lock`
3. `flutter pub get`, then `flutter analyze` — expect **0 errors**.
4. Bump `version:` in `pubspec.yaml`. **versionCode must exceed the highest already on Play**
   (production was 19 / v1.2.5 at handover; 1.3.0+24 has been built locally but never published).
   Play rejects a re-used or lower versionCode permanently.
5. Build both artifacts:
   ```bash
   flutter build appbundle --release   # Play
   flutter build apk --release         # direct channel
   ```
6. **Shippability check** on the APK — must return 1, not 0:
   ```bash
   unzip -Z1 build/app/outputs/flutter-apk/app-release.apk \
     | grep -c '^lib/arm64-v8a/liborbit_denoise.so'
   ```
7. Confirm the signature is ours before publishing (see the reproduce steps above).
8. Publish:
   - **Play**: upload the AAB, use a staged rollout.
   - **Direct**: upload the APK to the Supabase `app-releases` bucket, then update the
     `app_versions` android row — `min_version`, and the `?v=` cache-buster on `apk_download_url`.
9. Note the asymmetry: Play supports staged rollout; the direct channel is all-or-nothing the
   moment the file is replaced. Publish to Play first, watch it, then swap the APK.
