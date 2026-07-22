// Service layer for organizations (spec section 4 / 6.2 / 9, Part 3 Task 1-4,
// Part 4 subscription/billing tracking). Cash-only record-keeping — there is
// NO payment gateway, this module only records that a payment happened.
const { db } = require('../config/firebase-admin');

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

// Part 4 Task 4: computed-on-read overdue detection — NEVER auto-suspends,
// that stays a manual Super Admin decision (Part 3's suspend toggle). This
// only surfaces a status for the UI.
function computeBillingStatus(org) {
  if (!org.nextDueDate) return 'unknown';
  const daysUntilDue = (new Date(org.nextDueDate).getTime() - Date.now()) / 86400000;
  if (daysUntilDue < 0) return 'overdue';
  if (daysUntilDue <= 7) return 'dueSoon';
  return 'paid';
}

async function branchCountFor(organizationId) {
  const snapshot = await db.collection('branches').where('organizationId', '==', organizationId).get();
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
  };
  const ref = await db.collection('organizations').add(doc);
  return { id: ref.id, ...doc, branchCount: 0, billingStatus: computeBillingStatus(doc) };
}

async function list() {
  const snapshot = await db.collection('organizations').orderBy('createdAt', 'desc').get();
  return Promise.all(
    snapshot.docs.map(async (doc) => {
      const data = doc.data();
      return { id: doc.id, ...data, branchCount: await branchCountFor(doc.id), billingStatus: computeBillingStatus(data) };
    })
  );
}

async function getById(id) {
  const doc = await db.collection('organizations').doc(id).get();
  if (!doc.exists) return null;

  const data = doc.data();
  const branchesSnapshot = await db.collection('branches').where('organizationId', '==', id).get();
  const branches = branchesSnapshot.docs.map((b) => ({ id: b.id, ...b.data() }));

  return { id: doc.id, ...data, branchCount: branches.length, branches, billingStatus: computeBillingStatus(data) };
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
  await db.collection('organizations').doc(id).update(updates);
  return getById(id);
}

/**
 * Activates/suspends an organization and writes an audit entry — a suspend
 * must take effect immediately for every user under it (enforced at the API
 * layer by branchScope.middleware.js's ORG_SCOPED_ROLES_FOR_SUSPENSION check).
 */
async function setStatus(id, isActive, actorId) {
  await db.collection('organizations').doc(id).update({ isActive });
  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: 'super_admin',
    action: isActive ? 'organization.activated' : 'organization.suspended',
    targetCollection: 'organizations',
    targetId: id,
    organizationId: id,
    timestamp: new Date().toISOString(),
  });
  return getById(id);
}

/**
 * Part 4 Task 3 — records that a cash payment happened (no gateway, this is
 * pure bookkeeping) and recalculates nextDueDate from the payment's own date
 * under the organization's current billingCycle.
 */
async function recordPayment(id, { amountRwf, date, note }, actorId) {
  const doc = await db.collection('organizations').doc(id).get();
  if (!doc.exists) return null;
  const data = doc.data();

  const payment = {
    date: date || new Date().toISOString(),
    amountRwf,
    note: note || null,
    recordedBy: actorId || null,
  };
  const paymentHistory = [...(data.subscriptionPaymentHistory || []), payment];
  const nextDueDate = computeNextDueDate(new Date(payment.date), data.billingCycle || 'monthly');

  await db.collection('organizations').doc(id).update({
    subscriptionPaymentHistory: paymentHistory,
    nextDueDate,
  });

  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: 'super_admin',
    action: 'organization.paymentRecorded',
    targetCollection: 'organizations',
    targetId: id,
    organizationId: id,
    timestamp: new Date().toISOString(),
  });

  return getById(id);
}

async function getPaymentHistory(id) {
  const doc = await db.collection('organizations').doc(id).get();
  if (!doc.exists) return null;
  return doc.data().subscriptionPaymentHistory || [];
}

module.exports = {
  create,
  list,
  getById,
  update,
  setStatus,
  recordPayment,
  getPaymentHistory,
  branchLimitForPlan,
  computeNextDueDate,
  computeBillingStatus,
  PLAN_BRANCH_LIMITS,
  BILLING_CYCLE_MONTHS,
};
