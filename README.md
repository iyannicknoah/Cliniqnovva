# Cliniqnovva

Clinic Management System for Rwanda. See [`docs/technical-spec.md`](docs/technical-spec.md) for the
full functional/technical spec — every module, role, and rule referenced below traces back to a
section number in that document.

## Layout

```
backend/        Node.js/Express API + Firebase Admin SDK (see backend/README.md)
firebase/       firestore.rules, firestore.indexes.json, storage.rules, firebase.json, .firebaserc
patient_app/    Flutter, Android/iOS — patient booking/records/chat app
staff_app/      Flutter, Android/iOS, mobile-only, mandatory for all staff roles
docs/           technical-spec.md (reference spec)
```

Not yet created, pending a framework decision (see project chat / section 13):
- `admin_dashboard/` — web app for Super Admin/Org Admin/Branch Admin/Receptionist/Accountant/Pharmacist
- `doctor_dashboard/` — optional, doctor-only web add-on alongside the mandatory Staff App

## Status: project setup only

Nothing beyond scaffolding has been built. Backend routes return `501 Not Implemented`; Flutter apps
show a placeholder screen confirming flavor/localization wiring. No booking, billing, or record
logic exists yet — that's Phase 1, and hasn't been started.

## Environments

Three separate Firebase projects, one per environment: `cliniqnovva-dev`, `cliniqnovva-staging`,
`cliniqnovva-prod` (see `firebase/.firebaserc`). Each of `backend/`, `patient_app/`, `staff_app/`
has its own environment-switching mechanism — see their respective READMEs.

## What's verified vs. what's not

- Backend: every route/controller/service file syntax-checked; the Express app loads correctly end
  to end (fails only on placeholder Firebase credentials, as expected).
- Flutter apps: `flutter analyze` clean, `flutter test` passing on both, confirming flavor config +
  generated localization wiring actually works at runtime, not just "looks right."
- Firestore rules/indexes: structurally valid per the Firebase CLI, but not yet deployed or
  emulator-tested against real data — the Firebase projects themselves don't exist yet.
- Android build flavors: written to the standard documented Gradle pattern, not yet full-build
  verified (Android SDK licenses aren't accepted in this environment, and doing a full build wasn't
  necessary to unblock this setup pass).
- iOS flavors: not done — needs Xcode on a Mac, can't be scripted from this Windows environment.
