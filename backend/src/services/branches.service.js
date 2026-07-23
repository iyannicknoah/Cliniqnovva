// Service layer for branches (spec section 4 / 6.2 / 9 — Part 6).
// Full branch management: list (with per-branch employee counts), detail,
// create (plan branch-limit enforced), update (Branch Admin restricted to
// working hours only), and activate/deactivate (blocked while the branch
// still has active staff or appointments).
const { db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');

// Appointment statuses that count as "active" for the deactivation guard —
// completed/cancelled appointments never block a deactivation.
const ACTIVE_APPOINTMENT_STATUSES = ['pending', 'confirmed', 'checkedIn'];

// Fields a client is ever allowed to write on a branch document. Everything
// else (organizationId, isActive, createdAt) is server-owned.
const WRITABLE_FIELDS = [
  'name',
  'address',
  'phone',
  'location',
  'workingHours',
  'umugandaSaturdayHours',
  'servicesOffered',
];

// Working-hours only — the subset a Branch Admin may edit on their own
// branch (Part 6 Task 3: "editable working hours only").
const BRANCH_ADMIN_FIELDS = ['workingHours', 'umugandaSaturdayHours'];

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/**
 * Validates a {start, end} 'HH:mm' pair (opening time must be before
 * closing time — Part 6 Task 4). `label` names the field in error messages.
 * Null/undefined is allowed (hours are optional); anything else must be a
 * well-formed pair.
 */
function assertValidHours(hours, label) {
  if (hours === null || hours === undefined) return;
  const pattern = /^([01]\d|2[0-3]):[0-5]\d$/;
  if (typeof hours !== 'object' || !pattern.test(hours.start || '') || !pattern.test(hours.end || '')) {
    throw httpError(400, `${label} must be { start: 'HH:mm', end: 'HH:mm' }`);
  }
  if (hours.start >= hours.end) {
    throw httpError(400, `${label}: opening time must be before closing time`);
  }
}

/**
 * Branches of an organization, each with `employeeCount` (non-patient users
 * assigned to that branch, deactivated accounts excluded) — Part 6 Task 3.
 */
async function list(organizationId) {
  const [branchSnap, userSnap] = await Promise.all([
    db.collection('branches').where('organizationId', '==', organizationId).get(),
    db.collection('users').where('organizationId', '==', organizationId).get(),
  ]);

  const countsByBranch = {};
  userSnap.docs.forEach((doc) => {
    const { branchId, role, isActive } = doc.data();
    if (!branchId || role === ROLES.PATIENT || isActive === false) return;
    countsByBranch[branchId] = (countsByBranch[branchId] || 0) + 1;
  });

  return branchSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
    employeeCount: countsByBranch[doc.id] || 0,
  }));
}

/**
 * List plus the organization's plan limit, so the client can disable
 * "+ Add Branch" (and show the limit message) without a second request.
 */
async function listWithPlan(organizationId) {
  const orgDoc = await db.collection('organizations').doc(organizationId).get();
  if (!orgDoc.exists) throw httpError(404, 'Organization not found');
  const branches = await list(organizationId);
  return {
    branches,
    branchLimit: orgDoc.data().branchLimit ?? null,
    branchCount: branches.length,
  };
}

async function getById(id) {
  const doc = await db.collection('branches').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

/**
 * @param {{actorId: string, actorRole: string}} actor - used to log whether this
 *   was a Super Admin acting on an organization's behalf (support exception).
 */
async function create(
  { organizationId, name, address, phone, location, workingHours, umugandaSaturdayHours, servicesOffered },
  { actorId, actorRole }
) {
  const orgDoc = await db.collection('organizations').doc(organizationId).get();
  if (!orgDoc.exists) throw httpError(404, 'Organization not found');

  // Enforce the subscription plan's branch limit (basic=1, pro=5,
  // enterprise=unlimited/null) — applies here too, not just the Organization
  // Admin's own creation flow, since Super Admin's "on this org's behalf"
  // path is the same underlying write.
  const { branchLimit } = orgDoc.data();
  if (branchLimit !== null && branchLimit !== undefined) {
    const countSnapshot = await db.collection('branches').where('organizationId', '==', organizationId).count().get();
    if (countSnapshot.data().count >= branchLimit) {
      throw httpError(400, "You've reached your plan's branch limit. Contact support to upgrade.");
    }
  }

  assertValidHours(workingHours, 'workingHours');
  assertValidHours(umugandaSaturdayHours, 'umugandaSaturdayHours');

  const data = {
    organizationId,
    name,
    address: address || null,
    phone: phone || null,
    location: location || null,
    workingHours: workingHours || null,
    umugandaSaturdayHours: umugandaSaturdayHours || null,
    servicesOffered: Array.isArray(servicesOffered) ? servicesOffered : [],
    isActive: true,
    createdAt: new Date().toISOString(),
  };
  const ref = await db.collection('branches').add(data);

  const onBehalfOfOrg = actorRole === ROLES.SUPER_ADMIN;
  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: actorRole || null,
    action: onBehalfOfOrg ? 'branch.createdOnBehalfOfOrganization' : 'branch.created',
    targetCollection: 'branches',
    targetId: ref.id,
    organizationId,
    timestamp: new Date().toISOString(),
  });

  return { id: ref.id, ...data };
}

/**
 * Scope rules: Super Admin → any branch; Organization Admin → only branches
 * of their own organization; Branch Admin → only their own branch, and only
 * the working-hours fields.
 */
function assertBranchAccess(branch, scope, { hoursOnlyForBranchLevel = false, requestedFields = [] } = {}) {
  if (scope.level === 'platform') return;
  if (branch.organizationId !== scope.organizationId) {
    throw httpError(403, 'This branch belongs to a different organization');
  }
  if (scope.level === 'branch') {
    if (branch.id !== scope.branchId) {
      throw httpError(403, 'You can only manage your own branch');
    }
    if (hoursOnlyForBranchLevel) {
      const disallowed = requestedFields.filter((f) => !BRANCH_ADMIN_FIELDS.includes(f));
      if (disallowed.length > 0) {
        throw httpError(403, 'Branch Admins can only edit working hours');
      }
    }
  }
}

async function update(id, fields, { actorId, actorRole, scope }) {
  const branch = await getById(id);
  if (!branch) throw httpError(404, 'Branch not found');

  const requestedFields = Object.keys(fields).filter((f) => WRITABLE_FIELDS.includes(f));
  if (requestedFields.length === 0) throw httpError(400, 'No editable fields provided');

  assertBranchAccess(branch, scope, { hoursOnlyForBranchLevel: true, requestedFields });

  if ('workingHours' in fields) assertValidHours(fields.workingHours, 'workingHours');
  if ('umugandaSaturdayHours' in fields) assertValidHours(fields.umugandaSaturdayHours, 'umugandaSaturdayHours');
  if ('name' in fields && !fields.name) throw httpError(400, 'Branch name cannot be empty');

  const updates = {};
  requestedFields.forEach((f) => {
    updates[f] = fields[f] === undefined ? null : fields[f];
  });

  await db.collection('branches').doc(id).update(updates);

  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: actorRole || null,
    action: 'branch.updated',
    targetCollection: 'branches',
    targetId: id,
    organizationId: branch.organizationId,
    timestamp: new Date().toISOString(),
  });

  return { ...branch, ...updates };
}

/**
 * Deactivation guard (Part 6 DONE CONDITION): a branch cannot be turned off
 * while it still has active staff or active appointments — those must be
 * deactivated/completed first, so nothing keeps operating under a dead branch.
 */
async function setStatus(id, isActive, { actorId, actorRole, scope }) {
  const branch = await getById(id);
  if (!branch) throw httpError(404, 'Branch not found');

  assertBranchAccess(branch, scope);

  if (!isActive) {
    const staffSnap = await db.collection('users').where('branchId', '==', id).get();
    const activeStaff = staffSnap.docs.filter((doc) => {
      const { role, isActive: userActive } = doc.data();
      return role !== ROLES.PATIENT && userActive !== false;
    });
    if (activeStaff.length > 0) {
      throw httpError(
        400,
        `This branch still has ${activeStaff.length} active staff member${activeStaff.length === 1 ? '' : 's'} — deactivate or reassign them first.`
      );
    }

    const apptSnap = await db
      .collection('appointments')
      .where('branchId', '==', id)
      .where('status', 'in', ACTIVE_APPOINTMENT_STATUSES)
      .limit(1)
      .get();
    if (!apptSnap.empty) {
      throw httpError(400, 'This branch still has active appointments — complete or cancel them first.');
    }
  }

  await db.collection('branches').doc(id).update({ isActive });

  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: actorRole || null,
    action: isActive ? 'branch.activated' : 'branch.deactivated',
    targetCollection: 'branches',
    targetId: id,
    organizationId: branch.organizationId,
    timestamp: new Date().toISOString(),
  });

  return { ...branch, isActive };
}

module.exports = { list, listWithPlan, getById, create, update, setStatus };
