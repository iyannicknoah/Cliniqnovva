// Service layer for clinics (spec section 4 / 6.2 / 9, Part 3 Task 1-4,
// Part 4 subscription/billing tracking). Cash-only record-keeping — there is
// NO payment gateway, this module only records that a payment happened.
const { db, auth } = require('../config/firebase-admin');
const auditLogService = require('./auditLog.service');

// basic=1 branch, pro=5, enterprise=unlimited (null).
const PLAN_BRANCH_LIMITS = { basic: 1, pro: 5, enterprise: null };

// Months to add to compute the next due date per billing cycle (Part 4 Task 1).
const BILLING_CYCLE_MONTHS = { monthly: 1, quarterly: 3 };

function branchLimitForPlan(plan) {
  if (!Object.prototype.hasOwnProperty.call(PLAN_BRANCH_LIMITS, plan)) {
    const err = new Error(`Unknown subscription plan "${plan}"`);
    err.status = 400;
    throw err;
  }
  return PLAN_BRANCH_LIMITS[plan];
}

function validateBillingCycle(cycle) {
  if (!Object.prototype.hasOwnProperty.call(BILLING_CYCLE_MONTHS, cycle)) {
    const err = new Error(`Unknown billing cycle "${cycle}"`);
    err.status = 400;
    throw err;
  }
}

function computeNextDueDate(fromDate, billingCycle) {
  validateBillingCycle(billingCycle);
  const d = new Date(fromDate);
  d.setUTCMonth(d.getUTCMonth() + BILLING_CYCLE_MONTHS[billingCycle]);
  return d.toISOString();
}

// Manually set by the Super Admin (not auto-suspends — that stays a separate
// manual decision, Part 3's suspend toggle). Recording a payment requires
// the clinic to already be marked 'paid'.
const BILLING_STATUSES = ['notPaid', 'pending', 'paid'];

function validateBillingStatus(status) {
  if (!BILLING_STATUSES.includes(status)) {
    const err = new Error(`Unknown billing status "${status}"`);
    err.status = 400;
    throw err;
  }
}

async function branchCountFor(clinicId) {
  const snapshot = await db.collection('branches').where('clinicId', '==', clinicId).get();
  return snapshot.size;
}

async function create({ name, subscriptionPlan, ownerContactName, ownerContactPhone, billingCycle, subscriptionAmountRwf }) {
  const branchLimit = branchLimitForPlan(subscriptionPlan);
  const cycle = billingCycle || 'monthly';
  validateBillingCycle(cycle);

  const doc = {
    name,
    subscriptionPlan,
    branchLimit,
    ownerContactName: ownerContactName || null,
    ownerContactPhone: ownerContactPhone || null,
    isActive: true,
    createdAt: new Date().toISOString(),
    billingCycle: cycle,
    subscriptionAmountRwf: subscriptionAmountRwf ?? 0,
    nextDueDate: computeNextDueDate(new Date(), cycle),
    subscriptionPaymentHistory: [],
    billingStatus: 'notPaid',
  };
  const ref = await db.collection('clinics').add(doc);
  return { id: ref.id, ...doc, branchCount: 0 };
}

async function list() {
  const snapshot = await db.collection('clinics').orderBy('createdAt', 'desc').get();
  return Promise.all(
    snapshot.docs.map(async (doc) => {
      const data = doc.data();
      return { id: doc.id, ...data, branchCount: await branchCountFor(doc.id), billingStatus: data.billingStatus || 'notPaid' };
    })
  );
}

/**
 * Rollback helper for create() in clinics.controller.js: if creating the
 * Clinic Admin's Firebase Auth account fails right after the clinic doc was
 * written, this undoes that write so the failed attempt doesn't leave a
 * dangling clinic with no working admin login.
 */
async function deleteById(id) {
  await db.collection('clinics').doc(id).delete();
}

async function getById(id) {
  const doc = await db.collection('clinics').doc(id).get();
  if (!doc.exists) return null;

  const data = doc.data();
  const branchesSnapshot = await db.collection('branches').where('clinicId', '==', id).get();
  const branches = branchesSnapshot.docs.map((b) => ({ id: b.id, ...b.data() }));

  return {
    id: doc.id,
    ...data,
    branchCount: branches.length,
    branches,
    billingStatus: data.billingStatus || 'notPaid',
  };
}

/**
 * Super Admin manually flips a clinic's billing status between notPaid,
 * pending, and paid — recording an actual payment (below) is only allowed
 * once a clinic is marked 'paid'.
 */
async function setBillingStatus(id, billingStatus, actor) {
  validateBillingStatus(billingStatus);
  await db.collection('clinics').doc(id).update({ billingStatus });
  await auditLogService.write({
    actorId: actor?.actorId,
    actorRole: actor?.actorRole,
    clinicId: id,
    action: 'clinic.billing_status_changed',
    targetCollection: 'clinics',
    targetId: id,
  });
  return getById(id);
}

const EDITABLE_FIELDS = [
  'name',
  'subscriptionPlan',
  'ownerContactName',
  'ownerContactPhone',
  'billingCycle',
  'subscriptionAmountRwf',
];

async function update(id, fields) {
  const updates = {};
  for (const key of EDITABLE_FIELDS) {
    if (fields[key] !== undefined) updates[key] = fields[key];
  }
  if (updates.subscriptionPlan) {
    updates.branchLimit = branchLimitForPlan(updates.subscriptionPlan);
  }
  if (updates.billingCycle) {
    // Cadence changed — recompute the due date from today under the new cycle
    // rather than leaving it computed under the old one.
    validateBillingCycle(updates.billingCycle);
    updates.nextDueDate = computeNextDueDate(new Date(), updates.billingCycle);
  }
  await db.collection('clinics').doc(id).update(updates);
  return getById(id);
}

/**
 * Activates/suspends a clinic — a suspend must take effect immediately for
 * every user under it (enforced at the API layer by
 * branchScope.middleware.js's ORG_SCOPED_ROLES_FOR_SUSPENSION check).
 */
async function setStatus(id, isActive, actor) {
  await db.collection('clinics').doc(id).update({ isActive });
  await auditLogService.write({
    actorId: actor?.actorId,
    actorRole: actor?.actorRole,
    clinicId: id,
    action: isActive ? 'clinic.activated' : 'clinic.suspended',
    targetCollection: 'clinics',
    targetId: id,
  });
  return getById(id);
}

/**
 * Part 4 Task 3 — records that a cash payment happened (no gateway, this is
 * pure bookkeeping) and recalculates nextDueDate from the payment's own date
 * under the clinic's current billingCycle. Only allowed once the
 * clinic's billingStatus has been manually marked 'paid'.
 */
async function recordPayment(id, { amountRwf, date, note }, actor) {
  const doc = await db.collection('clinics').doc(id).get();
  if (!doc.exists) return null;
  const data = doc.data();

  if ((data.billingStatus || 'notPaid') !== 'paid') {
    const err = new Error('Clinic must be marked Paid before recording a payment.');
    err.status = 400;
    throw err;
  }

  const payment = {
    date: date || new Date().toISOString(),
    amountRwf,
    note: note || null,
    recordedBy: actor?.actorId || null,
  };
  const paymentHistory = [...(data.subscriptionPaymentHistory || []), payment];
  const nextDueDate = computeNextDueDate(new Date(payment.date), data.billingCycle || 'monthly');

  await db.collection('clinics').doc(id).update({
    subscriptionPaymentHistory: paymentHistory,
    nextDueDate,
  });

  await auditLogService.write({
    actorId: actor?.actorId,
    actorRole: actor?.actorRole,
    clinicId: id,
    action: 'clinic.payment_recorded',
    targetCollection: 'clinics',
    targetId: id,
  });

  return getById(id);
}

async function getPaymentHistory(id) {
  const doc = await db.collection('clinics').doc(id).get();
  if (!doc.exists) return null;
  return doc.data().subscriptionPaymentHistory || [];
}

// Grace period between "Archive clinic" and permanent cascading deletion
// (2026-07-25, explicit user instruction) — long enough for a Super Admin
// to notice and undo a mistake, short enough to actually free the data.
const PURGE_AFTER_DAYS = 14;

/**
 * "Delete clinic" (2026-07-25) — no longer a hard delete. Marks the clinic
 * (and every branch under it) inactive/archived; nothing is removed. Fully
 * reversible via unarchive() any time before the 14-day grace period
 * (PURGE_AFTER_DAYS) elapses, at which point permanentlyDeleteArchivedClinics()
 * (the daily cron job, see jobs/purgeArchivedClinics.job.js) sweeps it up.
 * Unlike the old branch-count-gated hard delete this replaces, it works
 * regardless of how much is linked to the clinic — that's the whole point.
 */
async function archive(id, actor) {
  const doc = await db.collection('clinics').doc(id).get();
  if (!doc.exists) return null;

  await db.collection('clinics').doc(id).update({
    isActive: false,
    isArchived: true,
    archivedAt: new Date().toISOString(),
  });

  const branchesSnap = await db.collection('branches').where('clinicId', '==', id).get();
  await Promise.all(branchesSnap.docs.map((b) => b.ref.update({ isActive: false })));

  await auditLogService.write({
    actorId: actor?.actorId,
    actorRole: actor?.actorRole,
    clinicId: id,
    action: 'clinic.archived',
    targetCollection: 'clinics',
    targetId: id,
  });

  return getById(id);
}

/** Undoes archive() — clinic and every branch under it become active again. */
async function unarchive(id, actor) {
  const doc = await db.collection('clinics').doc(id).get();
  if (!doc.exists) return null;

  await db.collection('clinics').doc(id).update({
    isActive: true,
    isArchived: false,
    archivedAt: null,
  });

  const branchesSnap = await db.collection('branches').where('clinicId', '==', id).get();
  await Promise.all(branchesSnap.docs.map((b) => b.ref.update({ isActive: true })));

  await auditLogService.write({
    actorId: actor?.actorId,
    actorRole: actor?.actorRole,
    clinicId: id,
    action: 'clinic.unarchived',
    targetCollection: 'clinics',
    targetId: id,
  });

  return getById(id);
}

/** Deletes every doc a query matches; returns their ids. */
async function deleteQueryDocs(query) {
  const snap = await query.get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
  return snap.docs.map((d) => d.id);
}

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

async function deleteChatsForBranches(branchIds) {
  if (branchIds.length === 0) return;
  const snap = await db.collection('chats').where('branchId', 'in', branchIds).get();
  await Promise.all(
    snap.docs.map(async (chatDoc) => {
      const messagesSnap = await chatDoc.ref.collection('messages').get();
      await Promise.all(messagesSnap.docs.map((m) => m.ref.delete()));
      await chatDoc.ref.delete();
    })
  );
}

/**
 * The actual permanent, cascading delete — only ever called by
 * permanentlyDeleteArchivedClinics() below, never directly from a route.
 * Walks every collection that references the clinic (by clinicId,
 * branchId, or patientId) and removes it, including subcollections
 * (patients/{id}/documents, chats/{id}/messages) Firestore doesn't cascade
 * on its own, plus each staff/doctor's Firebase Auth account. No recovery
 * after this runs.
 *
 * KNOWN GAP: patient document uploads (patients/{id}/documents) are stored
 * as Firestore metadata pointing at Cloudflare R2 objects — this deletes
 * the metadata but does NOT delete the underlying R2 files, to avoid an
 * automated job holding R2 delete credentials. Those become orphaned
 * objects; a separate manual/ops cleanup is needed for the bucket itself.
 */
async function cascadeDeleteClinic(clinicId) {
  const branchIds = await deleteQueryDocs(db.collection('branches').where('clinicId', '==', clinicId));
  const patientIds = (await db.collection('patients').where('clinicId', '==', clinicId).get()).docs.map((d) => d.id);
  const userDocs = (await db.collection('users').where('clinicId', '==', clinicId).get()).docs;

  for (const branchChunk of chunk(branchIds, 10)) {
    await Promise.all([
      deleteQueryDocs(db.collection('departments').where('branchId', 'in', branchChunk)),
      deleteQueryDocs(db.collection('services').where('branchId', 'in', branchChunk)),
      deleteQueryDocs(db.collection('appointments').where('branchId', 'in', branchChunk)),
      deleteQueryDocs(db.collection('invoices').where('branchId', 'in', branchChunk)),
      deleteQueryDocs(db.collection('reviews').where('branchId', 'in', branchChunk)),
      deleteQueryDocs(db.collection('inventory').where('branchId', 'in', branchChunk)),
      deleteQueryDocs(db.collection('inventoryAdjustments').where('branchId', 'in', branchChunk)),
      deleteQueryDocs(db.collection('publicHolidays').where('branchId', 'in', branchChunk)),
      deleteQueryDocs(db.collection('queueCounters').where('branchId', 'in', branchChunk)),
      deleteChatsForBranches(branchChunk),
    ]);
  }

  for (const patientChunk of chunk(patientIds, 10)) {
    await deleteQueryDocs(db.collection('medicalRecords').where('patientId', 'in', patientChunk));
    await Promise.all([
      deleteQueryDocs(db.collection('patientMergeLogs').where('survivingPatientId', 'in', patientChunk)),
      deleteQueryDocs(db.collection('patientMergeLogs').where('mergedPatientId', 'in', patientChunk)),
    ]);
  }
  for (const patientId of patientIds) {
    await deleteQueryDocs(db.collection('patients').doc(patientId).collection('documents'));
  }
  await deleteQueryDocs(db.collection('patients').where('clinicId', '==', clinicId));

  await Promise.all(
    userDocs.map(async (userDoc) => {
      const data = userDoc.data();
      if (data.role === 'doctor') {
        await db.collection('doctors').doc(userDoc.id).delete().catch(() => {});
      }
      await deleteQueryDocs(db.collection('notifications').where('userId', '==', userDoc.id));
      await userDoc.ref.delete();
      try {
        await auth.deleteUser(userDoc.id);
      } catch (err) {
        if (err.code !== 'auth/user-not-found') throw err;
      }
    })
  );

  await deleteQueryDocs(db.collection('branches').where('clinicId', '==', clinicId));
  await db.collection('clinics').doc(clinicId).delete();
}

/**
 * Cron entry point (jobs/purgeArchivedClinics.job.js, daily) — finds every
 * clinic archived more than PURGE_AFTER_DAYS ago and permanently deletes
 * it via cascadeDeleteClinic(). Filters archivedAt in JS rather than a
 * Firestore range query so this doesn't need a new composite index for a
 * background job that isn't latency-sensitive.
 */
async function permanentlyDeleteArchivedClinics() {
  const cutoff = new Date(Date.now() - PURGE_AFTER_DAYS * 24 * 60 * 60 * 1000).toISOString();
  const snap = await db.collection('clinics').where('isArchived', '==', true).get();
  const due = snap.docs.filter((d) => (d.data().archivedAt || '') <= cutoff);

  for (const doc of due) {
    await cascadeDeleteClinic(doc.id);
  }
  return { purged: due.length };
}

module.exports = {
  create,
  deleteById,
  list,
  getById,
  update,
  setStatus,
  setBillingStatus,
  recordPayment,
  getPaymentHistory,
  archive,
  unarchive,
  permanentlyDeleteArchivedClinics,
  branchLimitForPlan,
  computeNextDueDate,
  BILLING_STATUSES,
  PLAN_BRANCH_LIMITS,
  BILLING_CYCLE_MONTHS,
  PURGE_AFTER_DAYS,
};
