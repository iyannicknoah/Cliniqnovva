# Cliniqnovva Backend

Node.js/Express REST API + Firebase Admin SDK. See `/docs/technical-spec.md` at the repo root for the full functional spec this structure implements.

## Structure

```
src/
  config/        env.js (loads .env.$NODE_ENV), firebase-admin.js (modular Admin SDK), i18n.js
  routes/        one file per resource, mounted under /api/v1 by routes/index.js
  controllers/   thin HTTP handlers — parse/validate request, call services, shape response
  services/      business logic + Firestore reads/writes (currently stubs — Phase 1 work)
  middleware/    verifyToken (Firebase ID token verification), requireRole (RBAC), branchScope
                 (org/branch data isolation), rateLimiter, errorHandler
  locales/       backend-generated text (notifications, error messages) in en/rw/fr
```

Server listens on port **3000** by default (`PORT` env var). `GET /api/health` → `{status: "ok", timestamp}`
works even before Firebase is configured — Firebase Admin init failures are logged as a warning, not a
crash, so the server always boots; only routes that actually touch Firestore/Auth/Storage/Messaging will
fail until real credentials are supplied.

## Environments

Three separate Firebase projects are expected: `cliniqnovva-dev`, `cliniqnovva-staging`, `cliniqnovva-prod`.
Copy `.env.example` to `.env.development` / `.env.staging` / `.env.production` and fill in credentials —
either `FIREBASE_SERVICE_ACCOUNT_PATH` (path to the downloaded service-account JSON) or the three discrete
`FIREBASE_PROJECT_ID`/`FIREBASE_CLIENT_EMAIL`/`FIREBASE_PRIVATE_KEY` vars (better for hosting providers
without file uploads, e.g. Railway/Render). These files are gitignored — never commit real credentials.

```
npm run dev            # NODE_ENV=development
npm run dev:staging     # NODE_ENV=staging
npm start               # NODE_ENV=production
```

## Known issue to fix before shipping reports/exports

`xlsx` (used for report exports, Task 1) has an **unpatched high-severity** prototype-pollution/ReDoS
vulnerability in its npm-published version (no fix available via `npm audit fix`). Options before this
matters in production: install from SheetJS's own CDN-hosted tarball instead of npm, or swap to a
maintained alternative like `exceljs`. Not blocking for now since no report-export code exists yet.

## Auth endpoints (Part 2)

`POST /api/auth/invite-staff` (super_admin/clinic_admin/branch_admin) and
`POST /api/auth/set-claims` (super_admin only) are real, not stubs — also reachable at
`/api/v1/auth/invite-staff` / `/set-claims` (same router, mounted twice). Both are rate-limited.
`invite-staff` creates the Firebase Auth user + Firestore `/users` doc, sets custom claims, and
generates a password-setup link (logged to console — no email/SMS provider wired up yet).

## Current status

Auth (Part 2) and project-setup (Part 1) are real; everything else is still `501 Not Implemented`
skeletons wired up correctly (verified by loading the app with placeholder credentials) — no business
logic (booking transactions, invoice math, etc.) beyond auth has been implemented yet.
