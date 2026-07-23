// Service layer for departments (spec section 6.4 / 9).
// Part 6 implements list/create — the onboarding wizard's Step 2 creates the
// organization's first department(s). Update/remove land with the full
// Departments screen in a later part.
const { db } = require('../config/firebase-admin');

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

async function list({ organizationId, branchId }) {
  let query = db.collection('departments').where('organizationId', '==', organizationId);
  if (branchId) query = query.where('branchId', '==', branchId);
  const snapshot = await query.get();
  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

async function create({ organizationId, branchId, name }, { actorId, actorRole }) {
  if (!name || !name.trim()) throw httpError(400, 'Department name is required');
  if (!branchId) throw httpError(400, 'branchId is required');

  // The branch must exist and belong to the same organization — a client
  // can't attach a department to another clinic's branch.
  const branchDoc = await db.collection('branches').doc(branchId).get();
  if (!branchDoc.exists) throw httpError(404, 'Branch not found');
  if (branchDoc.data().organizationId !== organizationId) {
    throw httpError(403, 'This branch belongs to a different organization');
  }

  const data = {
    organizationId,
    branchId,
    name: name.trim(),
    isActive: true,
    createdAt: new Date().toISOString(),
  };
  const ref = await db.collection('departments').add(data);

  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: actorRole || null,
    action: 'department.created',
    targetCollection: 'departments',
    targetId: ref.id,
    organizationId,
    timestamp: new Date().toISOString(),
  });

  return { id: ref.id, ...data };
}

module.exports = { list, create };
