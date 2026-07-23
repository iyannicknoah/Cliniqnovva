// Service layer for the service catalog (spec section 6.4 / 9 — Part 7).
// Full CRUD, branch-scoped. A service with appointment/invoice history can
// never be hard-deleted — deactivate (soft delete) instead.
const { db } = require('../config/firebase-admin');

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

async function auditLog({ actorId, actorRole }, action, targetId, organizationId) {
  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: actorRole || null,
    action,
    targetCollection: 'services',
    targetId,
    organizationId,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Positive integer check for duration (mins) and price (RWF) — both must be
 * whole numbers (spec section 6.4: "default price in RWF" as a whole
 * number; duration "a positive number consistent with the branch's slot
 * configuration" — the cross-branch slot-consistency check itself lands
 * with the scheduling work in a later part; positivity/integer-ness is
 * enforced here).
 */
function assertPositiveInt(value, label) {
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) {
    throw httpError(400, `${label} must be a positive whole number`);
  }
}

/**
 * Services of an organization (optionally one branch/department), each with
 * `hasHistory` — whether any appointment references it. The client uses
 * that to decide between offering Delete (no history) and Deactivate-only
 * (spec 6.4: "deleting a service that has appointment/invoice history is
 * blocked").
 */
async function list({ organizationId, branchId, departmentId }) {
  let query = db.collection('services').where('organizationId', '==', organizationId);
  if (branchId) query = query.where('branchId', '==', branchId);
  if (departmentId) query = query.where('departmentId', '==', departmentId);

  const [serviceSnap, apptSnap] = await Promise.all([
    query.get(),
    db.collection('appointments').where('organizationId', '==', organizationId).get(),
  ]);

  const servicesWithHistory = new Set(
    apptSnap.docs.map((doc) => doc.data().serviceId).filter(Boolean)
  );

  return serviceSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
    hasHistory: servicesWithHistory.has(doc.id),
  }));
}

async function getById(id) {
  const doc = await db.collection('services').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

function assertAccess(service, scope) {
  if (scope.level === 'platform') return;
  if (service.organizationId !== scope.organizationId) {
    throw httpError(403, 'This service belongs to a different organization');
  }
  if (scope.level === 'branch' && service.branchId !== scope.branchId) {
    throw httpError(403, 'This service belongs to a different branch');
  }
}

async function create(
  { organizationId, branchId, departmentId, name, defaultDurationMins, defaultPriceRwf },
  actor
) {
  if (!name || !name.trim()) throw httpError(400, 'Service name is required');
  if (!branchId) throw httpError(400, 'branchId is required');
  if (!departmentId) throw httpError(400, 'departmentId is required');
  assertPositiveInt(defaultDurationMins, 'Default duration');
  assertPositiveInt(defaultPriceRwf, 'Default price');

  // The department must exist, belong to the same organization AND the
  // same branch — a service can't be filed under another branch's
  // department (spec 6.4: "define a service catalog per branch").
  const deptDoc = await db.collection('departments').doc(departmentId).get();
  if (!deptDoc.exists) throw httpError(404, 'Department not found');
  const dept = deptDoc.data();
  if (dept.organizationId !== organizationId || dept.branchId !== branchId) {
    throw httpError(400, 'That department does not belong to this branch');
  }

  const data = {
    organizationId,
    branchId,
    departmentId,
    name: name.trim(),
    defaultDurationMins,
    defaultPriceRwf,
    isActive: true,
    createdAt: new Date().toISOString(),
  };
  const ref = await db.collection('services').add(data);
  await auditLog(actor, 'service.created', ref.id, organizationId);
  return { id: ref.id, ...data };
}

async function update(
  id,
  { name, departmentId, defaultDurationMins, defaultPriceRwf, isActive },
  actor
) {
  const service = await getById(id);
  if (!service) throw httpError(404, 'Service not found');
  assertAccess(service, actor.scope);

  const updates = {};
  if (name !== undefined) {
    if (!name || !name.trim()) throw httpError(400, 'Service name cannot be empty');
    updates.name = name.trim();
  }
  if (departmentId !== undefined) {
    const deptDoc = await db.collection('departments').doc(departmentId).get();
    if (!deptDoc.exists) throw httpError(404, 'Department not found');
    const dept = deptDoc.data();
    if (dept.organizationId !== service.organizationId || dept.branchId !== service.branchId) {
      throw httpError(400, 'That department does not belong to this branch');
    }
    updates.departmentId = departmentId;
  }
  if (defaultDurationMins !== undefined) {
    assertPositiveInt(defaultDurationMins, 'Default duration');
    updates.defaultDurationMins = defaultDurationMins;
  }
  if (defaultPriceRwf !== undefined) {
    assertPositiveInt(defaultPriceRwf, 'Default price');
    updates.defaultPriceRwf = defaultPriceRwf;
  }
  if (isActive !== undefined) {
    if (typeof isActive !== 'boolean') throw httpError(400, 'isActive must be a boolean');
    updates.isActive = isActive;
  }
  if (Object.keys(updates).length === 0) throw httpError(400, 'No editable fields provided');

  await db.collection('services').doc(id).update(updates);
  await auditLog(actor, 'service.updated', id, service.organizationId);
  return { ...service, ...updates };
}

/**
 * Hard delete — only allowed with NO appointment history (spec 6.4: "a
 * service that has appointment/invoice history is blocked"). Every invoice
 * is generated from an appointment (`invoices/{id}: ..., appointmentId`),
 * so checking appointments transitively covers invoice history too — there
 * is no invoice without an appointment that referenced this service first.
 */
async function remove(id, actor) {
  const service = await getById(id);
  if (!service) throw httpError(404, 'Service not found');
  assertAccess(service, actor.scope);

  const apptSnap = await db.collection('appointments').where('serviceId', '==', id).limit(1).get();
  if (!apptSnap.empty) {
    throw httpError(400, 'This service has appointment/invoice history — deactivate it instead of deleting.');
  }

  await db.collection('services').doc(id).delete();
  await auditLog(actor, 'service.deleted', id, service.organizationId);
}

module.exports = { list, getById, create, update, remove };
