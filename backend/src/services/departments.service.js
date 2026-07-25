// Service layer for departments (spec section 6.4 / 9 — Part 7).
// Full CRUD, branch-scoped. A department with services attached can never be
// hard-deleted — deactivate (soft delete) instead.
const { db } = require('../config/firebase-admin');

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/**
 * Departments of a clinic (optionally one branch), each with
 * `serviceCount` — how many catalog services point at it. The client uses
 * that to decide between offering Delete (0 services) and Deactivate.
 */
async function list({ clinicId, branchId }) {
  let query = db.collection('departments').where('clinicId', '==', clinicId);
  if (branchId) query = query.where('branchId', '==', branchId);
  const [deptSnap, serviceSnap] = await Promise.all([
    query.get(),
    db.collection('services').where('clinicId', '==', clinicId).get(),
  ]);

  const serviceCounts = {};
  serviceSnap.docs.forEach((doc) => {
    const { departmentId } = doc.data();
    if (!departmentId) return;
    serviceCounts[departmentId] = (serviceCounts[departmentId] || 0) + 1;
  });

  return deptSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
    serviceCount: serviceCounts[doc.id] || 0,
  }));
}

async function getById(id) {
  const doc = await db.collection('departments').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

/** Throws unless the department is inside the caller's scope. */
function assertAccess(department, scope) {
  if (scope.level === 'platform') return;
  if (department.clinicId !== scope.clinicId) {
    throw httpError(403, 'This department belongs to a different clinic');
  }
  if (scope.level === 'branch' && department.branchId !== scope.branchId) {
    throw httpError(403, 'This department belongs to a different branch');
  }
}

async function create({ clinicId, branchId, name }, actor) {
  if (!name || !name.trim()) throw httpError(400, 'Department name is required');
  if (!branchId) throw httpError(400, 'branchId is required');

  // The branch must exist and belong to the same clinic — a client
  // can't attach a department to another clinic's branch.
  const branchDoc = await db.collection('branches').doc(branchId).get();
  if (!branchDoc.exists) throw httpError(404, 'Branch not found');
  if (branchDoc.data().clinicId !== clinicId) {
    throw httpError(403, 'This branch belongs to a different clinic');
  }

  const data = {
    clinicId,
    branchId,
    name: name.trim(),
    isActive: true,
    createdAt: new Date().toISOString(),
  };
  const ref = await db.collection('departments').add(data);
  return { id: ref.id, ...data };
}

/** Rename and/or (de)activate — the only editable fields. */
async function update(id, { name, isActive }, actor) {
  const department = await getById(id);
  if (!department) throw httpError(404, 'Department not found');
  assertAccess(department, actor.scope);

  const updates = {};
  if (name !== undefined) {
    if (!name || !name.trim()) throw httpError(400, 'Department name cannot be empty');
    updates.name = name.trim();
  }
  if (isActive !== undefined) {
    if (typeof isActive !== 'boolean') throw httpError(400, 'isActive must be a boolean');
    updates.isActive = isActive;
  }
  if (Object.keys(updates).length === 0) throw httpError(400, 'No editable fields provided');

  await db.collection('departments').doc(id).update(updates);
  return { ...department, ...updates };
}

/**
 * Hard delete — only allowed while NO services point at the department
 * (Part 7 Task 1). With services attached the department must be
 * deactivated instead, so existing catalog/booking data keeps resolving.
 */
async function remove(id, actor) {
  const department = await getById(id);
  if (!department) throw httpError(404, 'Department not found');
  assertAccess(department, actor.scope);

  const serviceSnap = await db.collection('services').where('departmentId', '==', id).limit(1).get();
  if (!serviceSnap.empty) {
    throw httpError(400, 'This department has services attached — deactivate it instead of deleting.');
  }

  await db.collection('departments').doc(id).delete();
}

module.exports = { list, getById, create, update, remove };
