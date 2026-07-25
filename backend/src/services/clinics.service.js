// Service layer for clinics (spec section 4 / 6.2 / 9, Part 3 Task 1-4,
// Part 4 subscription/billing tracking). Cash-only record-keeping — there is
// NO payment gateway, this module only records that a payment happened.
const { db, auth } = require('../config/firebase-admin');

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
async function setBillingStatus(id, billingStatus, actorId) {
  validateBillingStatus(billingStatus);
  await db.collection('clinics').doc(id).update({ billingStatus });
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
async function setStatus(id, isActive, actorId) {
  await db.collection('clinics').doc(id).update({ isActive });
  return getById(id);
}

/**
 * Part 4 Task 3 — records that a cash payment happened (no gateway, this is
 * pure bookkeeping) and recalculates nextDueDate from the payment's own date
 * under the clinic's current billingCycle. Only allowed once the
 * clinic's billingStatus has been manually marked 'paid'.
 */
async function recordPayment(id, { amountRwf, date, note }, actorId) {
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
    recordedBy: actorId || null,
  };
  const paymentHistory = [...(data.subscriptionPaymentHistory || []), payment];
  const nextDueDate = computeNextDueDate(new Date(payment.date), data.billingCycle || 'monthly');

  await db.collection('clinics').doc(id).update({
    subscriptionPaymentHistory: paymentHistory,
    nextDueDate,
  });

  return getById(id);
}

async function getPaymentHistory(id) {
  const doc = await db.collection('clinics').doc(id).get();
  if (!doc.exists) return null;
  return doc.data().subscriptionPaymentHistory || [];
}

/**
 * Hard-deletes a clinic — only allowed while it has zero branches (i.e. it
 * was never actually put into use), matching the rest of the app's rule
 * that nothing with dependent history is hard-deleted (see
 * services.service.js#remove). A clinic with branches must be suspended
 * instead. Also removes the clinic's own staff accounts (e.g. the Clinic
 * Admin created alongside it) — there's no dependent history to preserve
 * for those when the clinic itself never had branches.
 */
async function remove(id) {
  const doc = await db.collection('clinics').doc(id).get();
  if (!doc.exists) return null;

  const branchCount = await branchCountFor(id);
  if (branchCount > 0) {
    const err = new Error('This clinic has branches — suspend it instead of deleting.');
    err.status = 400;
    throw err;
  }

  const usersSnap = await db.collection('users').where('clinicId', '==', id).get();
  await Promise.all(
    usersSnap.docs.map(async (userDoc) => {
      await userDoc.ref.delete();
      try {
        await auth.deleteUser(userDoc.id);
      } catch (err) {
        if (err.code !== 'auth/user-not-found') throw err;
      }
    })
  );

  await db.collection('clinics').doc(id).delete();
  return { id };
}

module.exports = {
  create,
  list,
  getById,
  update,
  setStatus,
  setBillingStatus,
  recordPayment,
  getPaymentHistory,
  remove,
  branchLimitForPlan,
  computeNextDueDate,
  BILLING_STATUSES,
  PLAN_BRANCH_LIMITS,
  BILLING_CYCLE_MONTHS,
};
