# LIVO (SK Live) — Mobile Application

Flutter client for **LIVO**, a social audio and entertainment platform. The app provides real-time voice rooms, live interaction, virtual gifts, games, messaging, and a virtual economy on Android and iOS.

**Package name:** `sk_live`  
**Current version:** `1.3.0+24` (see `pubspec.yaml`)

---

## Overview

LIVO is a community-focused live audio product. Core capabilities include:

- Real-time **voice rooms** with seat-based hosting and audience modes  
- **Social login** (Google, email, and related auth flows)  
- **Virtual gifting** with animated effects and in-app economy (coins / diamonds)  
- **Direct messaging**, profiles, rankings, agencies, and host tools  
- **Mini-games** and event surfaces integrated into rooms  
- **Push notifications**, deep links, and background room keepalive  
- Multi-language UI via Flutter localization (`lib/l10n`)

This repository contains the **mobile application source only**. Backend services (API, database, auth, storage, realtime gateway, voice infrastructure) are deployed separately and must be configured before the app can run against a live environment.

---

## Technology Stack

| Layer | Technology |
|--------|------------|
| Framework | Flutter (Dart SDK `^3.11.4`) |
| State management | Riverpod, Provider |
| Navigation | GoRouter |
| Backend SDK | Supabase Flutter (Auth, Database, Storage, Realtime) |
| Realtime rooms | Socket.IO gateway |
| Voice | Orbit Voice |
| Push / analytics | Firebase (Messaging, Crashlytics, Analytics, Performance) |
| Payments | Google Play / App Store in-app purchase |
| Local cache | Hive, SharedPreferences, Flutter Secure Storage |

---

## Repository Structure

```
sklive-mobile/
├── lib/                 # Application source (features, core, l10n)
├── assets/              # Images, animations, branding assets
├── android/             # Android host project
├── ios/                 # iOS host project
├── packages/            # Local Flutter packages (e.g. overlay window)
├── supabase/            # Edge functions & SQL migrations (reference / deploy)
├── scripts/             # Helper scripts
├── docs/                # Operational notes
├── pubspec.yaml         # Dependencies and app metadata
└── README.md            # This file
```

Feature code lives primarily under `lib/features/`. Shared services, providers, and utilities live under `lib/core/`.

---

## Prerequisites

Install the following on the development machine:

1. **Flutter** (stable channel recommended; Dart SDK compatible with `^3.11.4`)  
2. **Xcode** (macOS) for iOS builds  
3. **Android Studio** / Android SDK for Android builds  
4. Platform tooling: CocoaPods (iOS), JDK 17+ (Android)

Verify Flutter:

```bash
flutter doctor -v
```

Resolve any blocking issues reported by `flutter doctor` before building.

---

## Getting Started

### 1. Unpack and enter the project

```bash
unzip sklive-mobile-source.zip
cd sklive-mobile
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure platform credentials

Firebase config files (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) are included when present so the project can build against the configured Firebase project. Replace them if you migrate to a different Firebase project.

**Android release signing files are included** in this package for Play Store builds:

| File | Purpose |
|------|---------|
| `android/key.properties` | Release signing config |
| `android/app/upload-keystore.jks` | Upload / release keystore |

Treat these files as confidential. Keep them private and do not publish this package to public repositories or share broadly. Configure iOS signing separately with your Apple Developer certificates and provisioning profiles.

API endpoints and keys used by the client are defined in application constants (for example under `lib/core/util/`). Point these at your Supabase (or compatible) backend, realtime gateway, and related services before production use.

### 4. Run in debug

```bash
flutter run
```

Or select a device / emulator from your IDE (Android Studio, VS Code, or Cursor).

### 5. Build release artifacts

**Android App Bundle (Play Store):**

```bash
flutter build appbundle --release
```

**Android APK:**

```bash
flutter build apk --release
```

**iOS (requires Mac + signing certificates):**

```bash
flutter build ipa --release
```

---

## Configuration Notes

- **Backend URL / anon key:** Update the Supabase base URL and anon key to match the environment you operate (staging or production).  
- **Realtime gateway:** Room presence, seats, gifts, and chat events depend on the Socket.IO gateway URL being reachable from the device.  
- **Voice:** Orbit Voice credentials and session endpoints must match your voice provider setup.  
- **OAuth:** Google (and other) client IDs must match the Firebase / Google Cloud project used for this app package ID.  
- **Deep links / store listing:** Package name, bundle ID, and store metadata must stay aligned with the signing and Firebase projects you use.

If Remote Config or similar bootstrap is used in your environment, see `docs/` for any environment-switch notes included with this package.

---

## Localization

UI strings are managed under `lib/l10n/`. After editing ARB sources (if applicable), regenerate localizations with:

```bash
flutter gen-l10n
```

---

## Quality Checks

```bash
flutter analyze
flutter test
```

Address analyzer findings before shipping a release build.

---

## What Is Excluded From This Package

To keep the archive small and safe for transfer, the following are omitted:

- Flutter / Dart tool caches (`.dart_tool/`)  
- Build outputs (`build/`, Android/iOS intermediate build folders)  
- Gradle caches (`.gradle/`)  
- iOS CocoaPods install output (`Pods/`, `.symlinks/`)  
- Git history (`.git/`)  
- Local IDE settings and OS junk (`.idea/`, `.DS_Store`, etc.)  
- Local machine paths (`android/local.properties`)  
- Old keystore backups (`android/keystore-backup/`)  

**Note:** Active Android signing materials (`android/key.properties` and `android/app/upload-keystore.jks`) **are included**. Keep this package private.  

After unpacking, run `flutter pub get` (and `pod install` under `ios/` on macOS when building for iOS) to regenerate dependencies.

---

## Support Handoff

For engineering handoff, please confirm with the delivering party:

1. Target backend base URL(s) and environment (staging / production)  
2. Firebase project access for push and Crashlytics  
3. Google / Apple developer accounts and signing materials  
4. Voice (Orbit) and game-provider credentials, if those features are in scope  
5. Preferred store package name / bundle identifier for release builds  

---

## License & Ownership

This source package is provided for the designated client under the terms agreed between the parties. Redistribution, reverse engineering for competing products, or publication without authorization is not permitted unless explicitly allowed in writing.

---

## Contact

For setup questions related to this delivery package, contact your project owner or the engineering contact who provided this archive.
