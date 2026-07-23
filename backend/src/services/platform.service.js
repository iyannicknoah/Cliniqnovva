// Service layer for Super Admin platform oversight/support tools (Part 5).
// Everything here is read-only except the audit-log writes for
// record-view/support-view actions themselves — Super Admin must never be
// able to WRITE another organization's data through this module (Task 4
// DONE CONDITION).
const { randomUUID } = require('crypto');
const { db, auth } = require('../config/firebase-admin');
const { ORG_SCOPED_ROLES_FOR_SUSPENSION } = require('../middleware/branchScope.middleware');

// Only these collections can be viewed via viewRecord() — a fixed whitelist,
// not whatever collection name a caller passes in.
const VIEWABLE_COLLECTIONS = ['patients', 'appointments', 'invoices'];

async function _organizationNameMap() {
  const snapshot = await db.collection('organizations').get();
  const map = {};
  snapshot.docs.forEach((doc) => {
    map[doc.id] = doc.data().name;
  });
  return map;
}

/**
 * Part 5 Task 1 — search any branch or staff member across ALL
 * organizations by name. Not logged (only viewing a specific
 * patient/appointment/invoice record is, per the spec).
 */
async function search(query) {
  const q = (query || '').trim().toLowerCase();
  if (!q) return { branches: [], staff: [] };

  const [branchesSnapshot, staffSnapshot, orgNameById] = await Promise.all([
    db.collection('branches').get(),
    db.collection('users').where('role', 'in', ORG_SCOPED_ROLES_FOR_SUSPENSION).get(),
    _organizationNameMap(),
  ]);

  const branches = branchesSnapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((b) => (b.name || '').toLowerCase().includes(q))
    .map((b) => ({ ...b, organizationName: orgNameById[b.organizationId] || null }));

  const staff = staffSnapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((u) => (u.name || '').toLowerCase().includes(q))
    .map((u) => ({ ...u, organizationName: orgNameById[u.organizationId] || null }));

  return { branches, staff };
}

/**
 * Part 5 Task 2 — platform-wide metrics, for Cliniqnovva's own business
 * visibility, never shown to any organization.
 */
async function getMetrics() {
  const now = new Date();
  const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
  const monthEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1)).toISOString();

  const [orgsCount, branchesCount, staffSnapshot, patientsCount, appointmentsCount] = await Promise.all([
    db.collection('organizations').count().get(),
    db.collection('branches').count().get(),
    db.collection('users').where('role', 'in', ORG_SCOPED_ROLES_FOR_SUSPENSION).get(),
    db.collection('patients').count().get(),
    db
      .collection('appointments')
      .where('createdAt', '>=', monthStart)
      .where('createdAt', '<', monthEnd)
      .count()
      .get(),
  ]);

  // isActive filtered in-memory (not a Firestore where-clause) so this
  // doesn't need a composite index alongside the 'role in [...]' query.
  const totalActiveStaff = staffSnapshot.docs.filter((doc) => doc.data().isActive !== false).length;

  return {
    totalOrganizations: orgsCount.data().count,
    totalBranches: branchesCount.data().count,
    totalActiveStaff,
    totalPatients: patientsCount.data().count,
    totalAppointmentsThisMonth: appointmentsCount.data().count,
  };
}

/**
 * Resolves actor uids to a human-readable label — a `/users` doc's
 * name/email for staff/org admins, falling back to the Firebase Auth
 * record's email for accounts with no Firestore mirror (e.g. Super Admin,
 * which is auth-only). So the audit log never shows a bare uid when a real
 * name/email is available.
 */
async function _actorLabelMap(actorIds) {
  const uniqueIds = [...new Set(actorIds.filter(Boolean))];
  if (uniqueIds.length === 0) return {};

  const map = {};
  const userDocs = await Promise.all(uniqueIds.map((id) => db.collection('users').doc(id).get()));
  const missing = [];
  userDocs.forEach((doc, i) => {
    if (doc.exists) {
      const data = doc.data();
      map[uniqueIds[i]] = data.name || data.email || uniqueIds[i];
    } else {
      missing.push(uniqueIds[i]);
    }
  });

  await Promise.all(
    missing.map(async (id) => {
      try {
        const userRecord = await auth.getUser(id);
        map[id] = userRecord.email || userRecord.displayName || id;
      } catch {
        map[id] = id;
      }
    })
  );

  return map;
}

/**
 * Part 5 Task 1 — platform-wide audit log, filterable by organization,
 * actor, action type, and date range. Resolves `organizationId`/`actorId`
 * to a real clinic name and a real actor name/email so the log reads as
 * actual activity, not a wall of opaque Firestore ids.
 */
async function getAuditLog({ organizationId, actorId, action, dateFrom, dateTo, limit } = {}) {
  let query = db.collection('auditLogs').orderBy('timestamp', 'desc');
  if (organizationId) query = query.where('organizationId', '==', organizationId);
  if (actorId) query = query.where('actorId', '==', actorId);
  if (action) query = query.where('action', '==', action);
  if (dateFrom) query = query.where('timestamp', '>=', dateFrom);
  if (dateTo) query = query.where('timestamp', '<=', dateTo);
  query = query.limit(Math.min(Number(limit) || 100, 500));

  const snapshot = await query.get();
  const entries = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  const [orgNameById, actorLabelById] = await Promise.all([
    _organizationNameMap(),
    _actorLabelMap(entries.map((e) => e.actorId)),
  ]);

  return entries.map((e) => ({
    ...e,
    organizationName: e.organizationId ? orgNameById[e.organizationId] || null : null,
    actorLabel: e.actorId ? actorLabelById[e.actorId] || e.actorId : e.actorRole || null,
  }));
}

/**
 * Part 5 Task 1 — read-only cross-org record view for support/dispute
 * resolution, logged every time (`platform.recordViewed`).
 */
async function viewRecord(collection, id, actorId) {
  if (!VIEWABLE_COLLECTIONS.includes(collection)) {
    const err = new Error(`"${collection}" is not a viewable collection`);
    err.status = 400;
    throw err;
  }

  const doc = await db.collection(collection).doc(id).get();
  if (!doc.exists) return null;

  const data = doc.data();
  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: 'super_admin',
    action: 'platform.recordViewed',
    targetCollection: collection,
    targetId: id,
    organizationId: data.organizationId || null,
    timestamp: new Date().toISOString(),
  });

  return { id: doc.id, ...data };
}

/**
 * Part 5 Task 3 — Support View start/end, both logged. Returns a random
 * sessionId purely to correlate the start/end pair in the audit trail — this
 * is NOT an auth token; the Flutter side still uses the Super Admin's own
 * ID token for every request, scoped to read-only endpoints only, so there
 * is no way to accidentally write another org's data through this path.
 */
async function startSupportView(organizationId, actorId) {
  const orgDoc = await db.collection('organizations').doc(organizationId).get();
  if (!orgDoc.exists) return null;

  const sessionId = randomUUID();
  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: 'super_admin',
    action: 'platform.supportViewStarted',
    targetCollection: 'organizations',
    targetId: organizationId,
    organizationId,
    sessionId,
    timestamp: new Date().toISOString(),
  });

  return { sessionId, organization: { id: orgDoc.id, ...orgDoc.data() } };
}

async function endSupportView(organizationId, sessionId, actorId) {
  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: 'super_admin',
    action: 'platform.supportViewEnded',
    targetCollection: 'organizations',
    targetId: organizationId,
    organizationId,
    sessionId: sessionId || null,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Super Admin Overview page — real monthly revenue growth, aggregated from
 * every organization's `subscriptionPaymentHistory` (Part 4), grouped by the
 * calendar month each payment was recorded on. Cash-only bookkeeping, same
 * as the rest of billing — this is a sum of recorded payments, not a
 * projection or a gateway feed.
 */
async function getRevenueTrend({ months = 12 } = {}) {
  const monthCount = Math.min(Math.max(Number(months) || 12, 1), 36);
  const now = new Date();
  const buckets = new Map();
  const ordered = [];
  for (let i = monthCount - 1; i >= 0; i--) {
    const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1));
    const key = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
    buckets.set(key, 0);
    ordered.push(key);
  }

  const snapshot = await db.collection('organizations').get();
  snapshot.docs.forEach((doc) => {
    const payments = doc.data().subscriptionPaymentHistory || [];
    payments.forEach((payment) => {
      const paidAt = new Date(payment.date);
      if (Number.isNaN(paidAt.getTime())) return;
      const key = `${paidAt.getUTCFullYear()}-${String(paidAt.getUTCMonth() + 1).padStart(2, '0')}`;
      if (buckets.has(key)) {
        buckets.set(key, buckets.get(key) + (payment.amountRwf || 0));
      }
    });
  });

  return ordered.map((key) => ({ month: key, revenueRwf: buckets.get(key) }));
}

module.exports = {
  search,
  getMetrics,
  getAuditLog,
  viewRecord,
  startSupportView,
  endSupportView,
  getRevenueTrend,
  VIEWABLE_COLLECTIONS,
};
