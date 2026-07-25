# Cliniqnovva — Security Review (Part 18 Task 1)

Date: 2026-07-24
Scope: `firebase/firestore.rules`, `firebase/storage.rules`, and the backend
middleware/service layers that those rules assume are the "real" gate for
every write and most reads (per the architecture documented at the top of
`firestore.rules`: business-critical writes go through the Node backend
using the Admin SDK, which bypasses Firestore rules entirely — the rules
exist to lock down what a browser holding a Firebase ID token can do
*directly*).

## Method

1. Read `firestore.rules` end to end, collection by collection.
2. Grepped every `.collection('...')` call in `backend/src` (the full set of
   Firestore collections the system uses) and cross-referenced it against
   the rules file, to find any collection a client could reach that isn't
   explicitly gated.
3. Grepped every `.collection('...')` call in the Flutter app
   (`cliniqnovva/lib`) — the set of collections actually read *directly* by
   the client SDK, bypassing the backend — since that's the subset where a
   rules gap would be immediately exploitable.
4. Read the backend middleware chain (`verifyToken` → `attachScope` →
   `requireRole`) and the service-layer `assertAccess()` helpers that every
   entity service repeats, to confirm the rules and the API enforce the same
   isolation independently (defense in depth, not rules-only).

## Findings

### 1. clinicId/branchId isolation — no gaps found

Every collection in `firestore.rules` that holds org/branch-scoped data
(`clinics`, `branches`, `users`, `patients`, `appointments`,
`medicalRecords`, `invoices`, `inventory`, `chats`) gates `read` on
`isSuperAdmin() || inSameOrg(...) || inSameBranch(...)` (or the caller being
the record's own subject, e.g. a patient reading their own row). All
`write` is `if false` for every one of those collections — every mutating
operation is backend-only, and the backend's own `assertAccess()` helpers
(one per service: `appointments.service.js`, `invoices.service.js`,
`patients.service.js`, `reviews.service.js`, ...) independently re-check
`clinicId`/`branchId` against `req.scope` before any read or write.
Two collections are intentionally NOT org/branch-scoped and that's correct,
not a gap:
- `departments` / `services` / `doctors` / `publicHolidays`: readable by any
  signed-in user. This is deliberate — booking search has to work across
  branches/orgs (a patient or receptionist searching for an available
  doctor needs to see doctors outside their own branch). Nothing sensitive
  lives on these documents.
- `reviews`: `allow read: if true` — fully public by design (patients
  browsing clinics before signing in).

Collections the backend uses that are **not** listed in `firestore.rules**
at all — `queueCounters`, `inventoryAdjustments`, `patients/{id}/documents`
— fall through to the file's default-deny `match /{document=**}`. That's
correct: none of them are ever read directly by the Flutter client (grep
confirms only `chats` is read client-side outside the backend), so
default-deny is exactly what should happen to them.

### 2. Chat exception — scoped correctly

`/chats/{chatId}` and its `/messages` subcollection are the one documented
exception to "no direct client writes." Read/create/update all require the
caller to be either the chat's own `patientId` (uid match — dead code today
since there's no Patient App yet issuing patient tokens, correctly
documented as forward-looking) or staff `inSameBranch()` as the chat, or
Super Admin. `delete` is `if false` everywhere (messages are soft-deleted
via `update`, never hard-deleted). No gap.

### 3. patientMergeLogs — append-only, verified at two layers

**UPDATE (2026-07-24, later the same day):** the general `auditLogs`
collection/feature described in this section's original write-up was
removed entirely per explicit user instruction — no more dedicated
service/controller/routes, no more `auditLog()` helper calls scattered
through every other service, no more rules block for it. That finding is
kept below purely as a historical record of what was reviewed; it no
longer describes a live feature.

`patientMergeLogs` is a separate, narrower feature (the patient-merge
tool's own history record, not a general activity log) and was
deliberately kept — a merge losing its own audit trail would break the
"patient merge preserves history" guarantee. It remains append-only at two
layers:
- **Rules**: `allow write: if false` — no client can ever write, update,
  or delete a merge-log entry.
- **Service layer**: written once, by `patients.service.js#mergePatients`,
  with no update path at all.

### 4. Reviews — soft-hide only, verified at two layers

`reviews.service.js#remove()` (the author's own delete) and `#hide()` (staff
moderation) both only ever `.update({ isHidden: true, ... })` — there is no
`.delete()` call anywhere in the module. `firestore.rules` backs this with
`allow write: if false` on `/reviews` (client can't bypass the service layer
even by calling Firestore directly).

### 5. Gap found and fixed — stale account deactivation wasn't immediate

`verifyToken.js` had a dead check: `if (decoded.isActive === false)`.
`isActive` was never set as a Firebase custom claim anywhere in the
codebase (only as a plain Firestore field on `/users`) — the condition
could never be true. Separately, `staff.service.js#setStatus` correctly
calls `auth.updateUser(id, { disabled: true })` on deactivation, but
`verifyToken.js` called `auth.verifyIdToken(token)` **without**
`checkRevoked: true`, which means a deactivated staff member's
already-issued ID token would keep authenticating for up to its ~1 hour
remaining lifetime.

Contrast: **clinic suspension already blocked access immediately**,
correctly, because `branchScope.middleware.js#attachScope` does a live
Firestore read of `clinics/{id}.isActive` on *every single request*,
independent of token freshness — this is the mechanism Part 18's DONE
CONDITION ("clinic suspension blocks access immediately") depends on,
and it needed no fix.

**Fix applied**: `verifyToken.js` now calls
`auth.verifyIdToken(token, /* checkRevoked */ true)`, and the dead
`decoded.isActive` branch was removed. Per the Admin SDK, `checkRevoked:
true` makes `verifyIdToken` also reject tokens for disabled accounts
(`auth/user-disabled`) and explicitly-revoked sessions (`auth/id-token-
revoked`), both now mapped to clear error responses. This costs one extra
Firebase Auth backend round-trip per request — an accepted, standard
tradeoff for immediate deactivation.

## Conclusion

No unaddressed gaps. Firestore/Storage security rules default-deny
everything and only carve out exactly the exceptions the product needs
(public directory browsing, public reviews, direct chat writes), every
carve-out is scoped to org/branch/own-record, and the one real gap found
(delayed staff-deactivation enforcement) has been fixed and is covered by
an integration test (see `backend/test/`).
