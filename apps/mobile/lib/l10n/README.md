# Localization (gen-l10n)

## Workflow
1. Add every new user-facing string to `app_en.arb` first (template / fallback).
2. Run `flutter gen-l10n` (or `flutter pub get`).
3. Use in UI: `context.l10n.someKey` via `package:sk_live/core/l10n/l10n_ext.dart`.
4. Translate into `app_ar.arb` (priority), then other `app_*.arb` files.
5. Missing keys in non-EN locales fall back to English automatically.

## Locales
`en` (default), `ar`, `id`, `tr`, `ur`, `hi`, `pt`, `th`, `vi`

## UI
My Profile → Language → pick locale (persisted in SharedPreferences).
