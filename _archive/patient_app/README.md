# Cliniqnovva — Patient App

Flutter, Android/iOS only (spec section 2/7).

## Structure

```
lib/
  main.dart / main_dev.dart / main_staging.dart / main_prod.dart   flavor entry points
  app.dart                                                          root MaterialApp widget
  core/
    config/flavor_config.dart          per-environment settings (API base URL, Firebase project id)
    config/generated_l10n/             generated from lib/l10n/*.arb — do not hand-edit
    theme/, constants/
  l10n/                                app_en.arb / app_rw.arb / app_fr.arb — edit these, not the generated files
  data/repositories/, data/api/        HTTP client + repositories talking to the backend
  features/<name>/presentation/        widgets/screens
  features/<name>/application/         state management / use-cases
```

Feature folders currently scaffolded (empty, Phase 1 work): `auth`, `clinic_search`, `booking`,
`medical_history`, `invoices`, `notifications`, `reviews`, `chat`.

## Running

```
flutter run --flavor dev -t lib/main_dev.dart
flutter run --flavor staging -t lib/main_staging.dart
flutter run --flavor prod -t lib/main_prod.dart
```

Android product flavors (`dev`/`staging`/`prod`) are configured in `android/app/build.gradle.kts`.
**iOS flavors (Xcode schemes/configurations) still need to be created manually in Xcode on a Mac** —
this can't be done from Windows without Xcode installed.

## Firebase

Not yet wired up — `firebase_core`/`firebase_auth`/`cloud_firestore`/`firebase_messaging` are added
as dependencies, but `Firebase.initializeApp()` is intentionally not called yet (see TODO in each
`main_*.dart`). Once the three Firebase projects exist (`cliniqnovva-dev/staging/prod`), run
`flutterfire configure` for each to generate `firebase_options.dart`, then wire it into `main_*.dart`.

## i18n

Kinyarwanda/English/French via Flutter's official ARB + `gen-l10n` codegen (`generate: true` in
pubspec.yaml, config in `l10n.yaml`). Add new UI strings to `lib/l10n/app_en.arb` (with `rw`/`fr`
translations in the sibling files) — never hardcode user-facing strings.
