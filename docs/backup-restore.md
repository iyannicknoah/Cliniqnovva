# Cliniqnovva — Backup & Disaster Recovery (Part 18 Task 3)

Project: `cliniqnovva-prod` (see `firebase/.firebaserc`). Two systems hold
data that must survive a disaster and be restorable together, because they
reference each other by the same uid: **Firestore** (all clinical/business
data) and **Firebase Authentication** (every staff/admin login — no
separate user database exists). A backup that only covers Firestore is
incomplete: restoring `/users/{uid}` documents with no matching Auth
account (or vice versa) leaves staff unable to log in even though "the
data" is back.

## 1. Scheduled Firestore export

Firestore's built-in **Backup Schedules** feature (not Cloud Functions, not
a cron job we maintain) is the primary mechanism — Google runs it, it needs
no application code, and it survives even if the Cliniqnovva backend server
itself is down or misconfigured.

### One-time setup (run once per environment, by whoever holds the GCP project's Owner/Editor role)

```bash
gcloud config set project cliniqnovva-prod

# Daily backup, kept for 14 days — enough to catch "we didn't notice
# until three days later" data problems without unbounded storage cost.
gcloud firestore backups schedules create \
  --database='(default)' \
  --recurrence=daily \
  --retention=14d

# Weekly backup, kept for 90 days — a longer safety net independent of the
# daily rotation, for the rarer "this needs to go back further" case.
gcloud firestore backups schedules create \
  --database='(default)' \
  --recurrence=weekly \
  --day-of-week=sunday \
  --retention=90d
```

Verify what's scheduled at any time:

```bash
gcloud firestore backups schedules list --database='(default)'
gcloud firestore backups list --location=<database-location>
```

Backups are stored by Google in the same region as the database, managed
entirely outside the application — no bucket to provision, no credentials
to rotate for this part.

### Supplementary on-demand export (before risky operations)

Before a schema-affecting deploy, a bulk data migration, or a demo-data
reseed against a real environment, take an explicit export to Cloud
Storage as well — it's portable (can be inspected, downloaded, imported
into a completely different project for testing) in a way a managed
backup isn't:

```bash
gsutil mb -l <region> gs://cliniqnovva-prod-firestore-exports   # one-time
gcloud firestore export gs://cliniqnovva-prod-firestore-exports/manual-$(date +%Y%m%d-%H%M%S)
```

### Firebase Authentication export (weekly, manual or cron'd alongside the above)

```bash
firebase auth:export auth-backup-$(date +%Y%m%d).json --project cliniqnovva-prod
```

This file contains password hashes and custom claims (role/clinicId/
branchId) for every account. **Treat it exactly like the service account
key** — store it in the same restricted location (never committed to git,
never a public bucket), since it's enough to reconstruct every login.

## 2. Restore procedure

Two different disasters need two different restores:

### 2a. Restoring Firestore data (e.g., a bad migration corrupted documents, or accidental bulk deletion)

```bash
# From a managed backup:
gcloud firestore backups restore \
  --source-backup=<backup-id-from `backups list`> \
  --destination-database='cliniqnovva-restore-check' \
  --project=cliniqnovva-prod

# From a manual GCS export instead:
gcloud firestore import gs://cliniqnovva-prod-firestore-exports/manual-YYYYMMDD-HHMMSS \
  --database='cliniqnovva-restore-check'
```

Both commands restore into a **new, separate database ID**
(`cliniqnovva-restore-check`), never directly overwriting the live
`(default)` database. This is deliberate:

1. Inspect the restored database first (spot-check a few patients,
   appointments, invoices — confirm the data actually looks right and
   matches the expected point in time) before anyone depends on it.
2. Only once verified, cut the backend over: update
   `backend/.env.production`'s Firestore database reference (or, for the
   simpler single-incident case, use `gcloud firestore databases clone` /
   re-export the verified restore back into `(default)` via
   `gcloud firestore import` targeting `(default)` directly — appropriate
   once you're confident the restore is correct and are ready to accept
   the downtime of a real cutover).
3. Delete the temporary `cliniqnovva-restore-check` database once the
   incident is closed, to avoid paying for two live databases indefinitely.

### 2b. Restoring Firebase Auth accounts (e.g., accounts were mistakenly deleted, or the whole project needs rebuilding)

```bash
firebase auth:import auth-backup-YYYYMMDD.json --project cliniqnovva-prod \
  --hash-algo=SCRYPT --hash-key=<key-from-export> --rounds=<n> --mem-cost=<n>
```

(`firebase auth:export`'s own output tells you the exact hash parameters
to pass back into `import` — they're specific to the project and must
match, or every imported user's password stops working even though the
account "restored" successfully.)

### 2c. Full disaster recovery (both systems lost — e.g., project-level incident)

1. Restore Firestore first (2a), into `(default)` directly this time since
   there's nothing live to protect.
2. Restore Auth (2b) from the *matching* backup — same day's exports, so
   Firestore `/users/{uid}` docs and Auth accounts agree on which uids
   exist. Mismatched backup dates are the main way this goes wrong: an
   Auth account with no matching `/users/{uid}` doc can sign in but hits
   403s everywhere (`attachScope` needs the custom claims, which import
   restores, but `verifyToken`/`requireRole`/every service's `assertAccess`
   also implicitly assumes the Firestore user doc exists for anything that
   reads it, e.g. staff listing screens).
3. Redeploy the backend (`firebase deploy` covers hosting only — the
   Node API's own deploy/restart is whatever the hosting platform for
   `backend/` requires) and re-run `flutter build web --release` +
   `firebase deploy --only hosting` for the frontend, so nothing is served
   stale against data that changed underneath it.
4. Spot-check: log in as one demo/test account per role, confirm the
   dashboard loads, confirm one patient record with clinical notes is
   readable by a doctor account.

## 3. What is deliberately NOT backed up separately

Patient documents (lab results, scans — spec 6.6) live in Cloudflare R2
(`backend/src/config/r2.js`), not Firestore or Firebase Storage. R2 backup/
versioning is a separate concern from this document, outside Part 18's
Firestore-focused scope — flagged here so it isn't mistaken for covered.
