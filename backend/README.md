# Cliniqnovva Backend

Node.js/Express REST API + Firebase Admin SDK. See `/docs/technical-spec.md` at the repo root for the full functional spec this structure implements.

## Structure

```
src/
  config/        env.js (loads .env.$NODE_ENV), firebase-admin.js (modular Admin SDK), i18n.js
  routes/        one file per resource, mounted under /api/v1 by routes/index.js
  controllers/   thin HTTP handlers — parse/validate request, call services, shape response
  services/      business logic + Firestore reads/writes (currently stubs — Phase 1 work)
  middleware/    auth (Firebase ID token verification), role (RBAC), branchScope (org/branch
                 data isolation), rateLimiter, errorHandler
  locales/       backend-generated text (notifications, error messages) in en/rw/fr
```

## Environments

Three separate Firebase projects are expected: `cliniqnovva-dev`, `cliniqnovva-staging`, `cliniqnovva-prod`.
Copy `.env.example` to `.env.development` / `.env.staging` / `.env.production` and fill in each
project's real service-account credentials (Firebase Console → Project Settings → Service Accounts
→ Generate new private key). These files are gitignored — never commit real credentials.

```
npm run dev            # NODE_ENV=development
npm run dev:staging     # NODE_ENV=staging
npm start               # NODE_ENV=production
```

## Current status

Project-setup phase only: middleware, config, and route/controller/service skeletons exist and are
wired together correctly (verified by loading the app with placeholder credentials), but controller
handlers return `501 Not Implemented`. No business logic (booking transactions, invoice math, etc.)
has been implemented yet — that's Phase 1.
