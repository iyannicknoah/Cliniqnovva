// Service layer for the platform-wide audit log — restored 2026-07-29 after
// being deliberately removed 2026-07-24 ("general activity log feature
// retired"). See docs/security-review.md §3 and firestore.rules for the
// removal history; docs/technical-spec.md §6.12 for the original 5-field
// shape this restores (actorId, actorRole, action, targetCollection,
// targetId, timestamp), plus one deliberate addition beyond that original
// spec: `clinicId`, needed so a Clinic Admin's view can be scoped to their
// own clinic the same way every other collection in this codebase is.
//
// write() is called from inside other services (clinics/staff/invoices/
// patients/platform), the same non-blocking-hook placement already used for
// notificationsService — but unlike those call sites, the try/catch lives
// INSIDE write() itself so every call site is a plain one-liner and an audit
// write can never throw into (or roll back) the action it's recording.
const { db } = require('../config/firebase-admin');

async function write({ actorId, actorRole, clinicId, action, targetCollection, targetId }) {
  try {
    await db.collection('auditLogs').add({
      actorId: actorId || null,
      actorRole: actorRole || null,
      clinicId: clinicId || null,
      action,
      targetCollection,
      targetId: targetId || null,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.warn(`[auditLog] write failed for ${action} on ${targetCollection}/${targetId}: ${err.message}`);
  }
}

/**
 * View-only (there is no write route — write() above is only ever called
 * internally from other services). clinicId is required for a Clinic Admin
 * (their own clinic, resolved by the controller the same way every other
 * clinic-scoped list() is); a Super Admin may omit it for a platform-wide
 * view or pass one to scope down to a single clinic, same optional-clinicId
 * shape as platform.service.js's other cross-org views.
 */
async function list({ clinicId, actorId, action, dateFrom, dateTo }) {
  let query = db.collection('auditLogs');
  if (clinicId) query = query.where('clinicId', '==', clinicId);
  if (actorId) query = query.where('actorId', '==', actorId);
  if (action) query = query.where('action', '==', action);

  const snap = await query.get();
  let logs = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  if (dateFrom) logs = logs.filter((l) => l.timestamp >= dateFrom);
  if (dateTo) logs = logs.filter((l) => l.timestamp <= `${dateTo}T23:59:59.999Z`);
  return logs.sort((a, b) => (a.timestamp < b.timestamp ? 1 : -1));
}

module.exports = { write, list };
