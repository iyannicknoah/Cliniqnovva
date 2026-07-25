# Cliniqnovva — Firebase/GCP Budget Alerts (Part 18 Task 4)

Budget alerts are billing-account configuration in the Google Cloud
Console — there is no application code path for this (nothing in
`backend/` or `cliniqnovva/` touches billing), and it requires access to
the actual GCP Billing Account tied to the `cliniqnovva-prod` project,
which only whoever holds that account can grant. This document is the
exact runbook to run once that access is available — it is **not yet
executed**, since no billing account was reachable while building this
part.

## Why this matters for Cliniqnovva specifically

The cost surfaces that could spike unexpectedly, given this app's actual
usage patterns:
- **Firestore reads** — the notification bell, chat inbox, and dashboard
  metrics all poll/stream live data; a bug that causes a tight re-fetch
  loop (a bad `ref.watch` dependency, for instance) would show up here
  first and fastest.
- **Cloud Functions / Cloud Run**, if the backend or the `popularityRecalc`
  cron job is ever migrated off its current host onto GCP compute.
- **Firebase Hosting bandwidth** for `flutter build web` — normally
  trivial, but a cache-busting misconfiguration serving huge uncompressed
  bundles repeatedly could add up.
- **Cloud Storage backup exports** (`docs/backup-restore.md`) accumulating
  without their retention policy actually pruning old backups.

None of these are expected to be large for a first paying clinic, which is
exactly why alerts matter more than hard caps here — the goal is "notice
early," not "shut the clinic's app off," since Firebase does not support
hard spending caps that stop serving traffic (a budget alert notifies; it
does not disable the project).

## Setup — Console (recommended, no gcloud CLI access needed)

1. Go to **console.cloud.google.com/billing** → select the billing account
   linked to `cliniqnovva-prod`.
2. **Budgets & alerts** → **Create budget**.
3. Scope: **Projects** → select `cliniqnovva-prod` only (not the whole
   billing account, if it's shared with other projects — keeps this
   budget meaningful specifically to Cliniqnovva).
4. Amount: set a **monthly** budget. Recommended starting point for a
   single paying clinic on Firebase's Blaze plan: **$25/month** — well
   above expected usage at this scale, low enough that any real anomaly
   still trips it early. Revisit once real usage data exists after the
   first billing cycle.
5. Alert thresholds — set all four:
   - 50% of budget (early warning, no action needed yet)
   - 75% of budget
   - 90% of budget
   - 100% of budget (investigate immediately)
6. Recipients: the email(s) that should receive these — at minimum the
   account that owns `cliniqnovva-prod`'s billing. Also check **"Connect a
   Pub/Sub topic"** only if programmatic alerting (e.g., piping into Slack)
   is wanted later — not required for the DONE CONDITION here.
7. Save.

## Setup — gcloud CLI equivalent (once a billing account ID is known)

```bash
# Find the billing account ID first:
gcloud billing accounts list

gcloud billing budgets create \
  --billing-account=<BILLING_ACCOUNT_ID> \
  --display-name="Cliniqnovva Production" \
  --budget-amount=25USD \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.75 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0 \
  --filter-projects=projects/cliniqnovva-prod
```

## Verification

```bash
gcloud billing budgets list --billing-account=<BILLING_ACCOUNT_ID>
```

should list "Cliniqnovva Production" with the four thresholds above. The
Console's **Budgets & alerts** page shows the same thing visually, plus
current month-to-date spend against it.

## Status

Documented and ready to execute — **not yet run**, since it needs a human
with access to the GCP Billing Console (or a service account with
`billing.budgets.create` IAM permission) to actually create it. Whoever
takes Cliniqnovva live should run the Console steps above as part of
go-live, before onboarding the first paying clinic.
