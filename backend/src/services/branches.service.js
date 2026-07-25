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
// else (clinicId, isActive, createdAt) is server-owned.
const WRITABLE_FIELDS = [
  'name',
  'address',
  'phone',
  'location',
  'workingHours',
  'umugandaSaturdayHours',
  'servicesOffered',
  'holidayOverrides',
];

// Working-hours only — the subset a Branch Admin may edit on their own
// branch (Part 6 Task 3: "editable working hours only"). holidayOverrides
// added here too (Part 8 Task 2) — it's a scheduling setting in the same
// family as hours, and the Doctor Schedule screen (branch-scoped, not
// org-wide) is where a Branch Admin toggles it.
const BRANCH_ADMIN_FIELDS = ['workingHours', 'umugandaSaturdayHours', 'holidayOverrides'];

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/**
 * Validates a working-hours object. Accepted shapes (2026-07-23, per the
 * user's explicit instruction to support round-the-clock and overnight
 * clinics):
 *   - { is24Hours: true }                 — open 24 hours, no times needed
 *   - { start: 'HH:mm', end: 'HH:mm' }    — end EARLIER than start means the
 *     branch closes the NEXT day (e.g. 20:00 → 04:00, an overnight shift).
 * The only invalid pair is start === end — that's ambiguous; a 24-hour
 * branch must say so explicitly. Null/undefined is allowed (hours optional).
 */
function assertValidHours(hours, label) {
  if (hours === null || hours === undefined) return;
  if (typeof hours !== 'object') {
    throw httpError(400, `${label} must be an object`);
  }
  if (hours.is24Hours === true) return;
  const pattern = /^([01]\d|2[0-3]):[0-5]\d$/;
  if (!pattern.test(hours.start || '') || !pattern.test(hours.end || '')) {
    throw httpError(400, `${label} must be { start: 'HH:mm', end: 'HH:mm' } or { is24Hours: true }`);
  }
  if (hours.start === hours.end) {
    throw httpError(
      400,
      `${label}: opening and closing time can't be the same — use is24Hours for a round-the-clock branch`
    );
  }
}

/**
 * Branches of a clinic, each with `employeeCount` (non-patient users
 * assigned to that branch, deactivated accounts excluded) — Part 6 Task 3.
 */
async function list(clinicId) {
  const [branchSnap, userSnap] = await Promise.all([
    db.collection('branches').where('clinicId', '==', clinicId).get(),
    db.collection('users').where('clinicId', '==', clinicId).get(),
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
 * List plus the clinic's plan limit, so the client can disable
 * "+ Add Branch" (and show the limit message) without a second request.
 */
async function listWithPlan(clinicId) {
  const orgDoc = await db.collection('clinics').doc(clinicId).get();
  if (!orgDoc.exists) throw httpError(404, 'Clinic not found');
  const branches = await list(clinicId);
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
 *   was a Super Admin acting on a clinic's behalf (support exception).
 */
async function create(
  { clinicId, name, address, phone, location, workingHours, umugandaSaturdayHours, servicesOffered },
  { actorId, actorRole }
) {
  const orgDoc = await db.collection('clinics').doc(clinicId).get();
  if (!orgDoc.exists) throw httpError(404, 'Clinic not found');

  // Enforce the subscription plan's branch limit (basic=1, pro=5,
  // enterprise=unlimited/null) — applies here too, not just the Clinic
  // Admin's own creation flow, since Super Admin's "on this org's behalf"
  // path is the same underlying write.
  const { branchLimit } = orgDoc.data();
  if (branchLimit !== null && branchLimit !== undefined) {
    const countSnapshot = await db.collection('branches').where('clinicId', '==', clinicId).count().get();
    if (countSnapshot.data().count >= branchLimit) {
      throw httpError(400, "You've reached your plan's branch limit. Contact support to upgrade.");
    }
  }

  assertValidHours(workingHours, 'workingHours');
  assertValidHours(umugandaSaturdayHours, 'umugandaSaturdayHours');

  const data = {
    clinicId,
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

  return { id: ref.id, ...data };
}

/**
 * Scope rules: Super Admin → any branch; Clinic Admin → only branches
 * of their own clinic; Branch Admin → only their own branch, and only
 * the working-hours fields.
 */
function assertBranchAccess(branch, scope, { hoursOnlyForBranchLevel = false, requestedFields = [] } = {}) {
  if (scope.level === 'platform') return;
  if (branch.clinicId !== scope.clinicId) {
    throw httpError(403, 'This branch belongs to a different clinic');
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
  if ('holidayOverrides' in fields && fields.holidayOverrides !== null && !Array.isArray(fields.holidayOverrides)) {
    throw httpError(400, 'holidayOverrides must be an array of holiday ids');
  }

  const updates = {};
  requestedFields.forEach((f) => {
    updates[f] = fields[f] === undefined ? null : fields[f];
  });

  await db.collection('branches').doc(id).update(updates);

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

  return { ...branch, isActive };
}

module.exports = { list, listWithPlan, getById, create, update, setStatus };
