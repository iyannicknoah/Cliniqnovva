// Service layer for Super Admin platform oversight/support tools (Part 5).
// Everything here is read-only except the audit-log writes for
// support-view actions themselves — Super Admin must never be able to
// WRITE another organization's data through this module (Task 4 DONE
// CONDITION).
const { randomUUID } = require('crypto');
const { db } = require('../config/firebase-admin');
const { ORG_SCOPED_ROLES_FOR_SUSPENSION } = require('../middleware/branchScope.middleware');

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
  getMetrics,
  startSupportView,
  endSupportView,
  getRevenueTrend,
};
