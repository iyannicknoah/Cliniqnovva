// Service layer for organizations (spec section 4 / 6.2 / 9, Part 3 Task 1-4).
const { db } = require('../config/firebase-admin');

// basic=1 branch, pro=5, enterprise=unlimited (null).
const PLAN_BRANCH_LIMITS = { basic: 1, pro: 5, enterprise: null };

function branchLimitForPlan(plan) {
  if (!Object.prototype.hasOwnProperty.call(PLAN_BRANCH_LIMITS, plan)) {
    const err = new Error(`Unknown subscription plan "${plan}"`);
    err.status = 400;
    throw err;
  }
  return PLAN_BRANCH_LIMITS[plan];
}

async function branchCountFor(organizationId) {
  const snapshot = await db.collection('branches').where('organizationId', '==', organizationId).get();
  return snapshot.size;
}

async function create({ name, subscriptionPlan, ownerContactName, ownerContactPhone }) {
  const branchLimit = branchLimitForPlan(subscriptionPlan);
  const doc = {
    name,
    subscriptionPlan,
    branchLimit,
    ownerContactName: ownerContactName || null,
    ownerContactPhone: ownerContactPhone || null,
    isActive: true,
    createdAt: new Date().toISOString(),
  };
  const ref = await db.collection('organizations').add(doc);
  return { id: ref.id, ...doc, branchCount: 0 };
}

async function list() {
  const snapshot = await db.collection('organizations').orderBy('createdAt', 'desc').get();
  return Promise.all(
    snapshot.docs.map(async (doc) => ({
      id: doc.id,
      ...doc.data(),
      branchCount: await branchCountFor(doc.id),
    }))
  );
}

async function getById(id) {
  const doc = await db.collection('organizations').doc(id).get();
  if (!doc.exists) return null;

  const branchesSnapshot = await db.collection('branches').where('organizationId', '==', id).get();
  const branches = branchesSnapshot.docs.map((b) => ({ id: b.id, ...b.data() }));

  return { id: doc.id, ...doc.data(), branchCount: branches.length, branches };
}

const EDITABLE_FIELDS = ['name', 'subscriptionPlan', 'ownerContactName', 'ownerContactPhone'];

async function update(id, fields) {
  const updates = {};
  for (const key of EDITABLE_FIELDS) {
    if (fields[key] !== undefined) updates[key] = fields[key];
  }
  if (updates.subscriptionPlan) {
    updates.branchLimit = branchLimitForPlan(updates.subscriptionPlan);
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
    timestamp: new Date().toISOString(),
  });
  return getById(id);
}

module.exports = { create, list, getById, update, setStatus, branchLimitForPlan, PLAN_BRANCH_LIMITS };
