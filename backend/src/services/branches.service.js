// Service layer for branches (spec section 4 / 6.2 / 9 — Part 6).
// Full branch management: list (with per-branch employee counts), detail,
// create (plan branch-limit enforced), update (Branch Admin restricted to
// working hours only), and activate/deactivate (blocked while the branch
// still has active staff or appointments).
const { db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');
const storageService = require('./storage.service');

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
  // Patient App public-profile fields (visibility toggle, set at onboarding
  // — see the "public visibility" wizard step). Deliberately separate from
  // the internal name/phone/address above: a clinic may want a different
  // public-facing display name/contact than its internal admin record.
  'isPublic',
  'publicDisplayName',
  'publicPhone',
  'publicEmail',
  'publicAddress',
  'publicImageKey',
  // Admin Web Dashboard's "Go Public" wizard (2026-08-16) — extends the
  // onboarding-era public-profile fields above with 3 more steps. Kept as
  // their own fields rather than folding into the public-profile object so
  // each step can be saved independently ("Save and Next" per step).
  'publicServiceIds',
  'publicDoctorIds',
  'payoutMethod',
  'payoutDetails',
];

const PUBLIC_PROFILE_REQUIRED_FIELDS = [
  'publicDisplayName',
  'publicPhone',
  'publicEmail',
  'publicAddress',
  'publicImageKey',
];

const PAYOUT_METHODS = ['momo', 'airtel', 'bank'];

// Required keys of `payoutDetails`, per `payoutMethod` — momo/airtel are a
// phone number + the name on that account; bank needs enough to actually
// route a transfer. None of this is verified against a real payment
// provider (explicit user instruction — the wizard's own payout step warns
// the clinic to double-check before confirming).
const PAYOUT_DETAIL_FIELDS = {
  momo: ['phone', 'accountName'],
  airtel: ['phone', 'accountName'],
  bank: ['bankName', 'accountNumber', 'accountName'],
};

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Validates `payoutDetails` against whichever `payoutMethod` is in effect
 * (the merged view, same "existing doc + this call" logic as the
 * isPublic gate below). Both fields travel together — a `payoutMethod`
 * without matching `payoutDetails` (or vice versa) is never valid.
 */
function assertValidPayout(merged) {
  if (merged.payoutMethod === undefined || merged.payoutMethod === null) return;
  if (!PAYOUT_METHODS.includes(merged.payoutMethod)) {
    throw httpError(400, `payoutMethod must be one of: ${PAYOUT_METHODS.join(', ')}`);
  }
  const details = merged.payoutDetails;
  if (!details || typeof details !== 'object') {
    throw httpError(400, 'payoutDetails is required when payoutMethod is set');
  }
  const missing = PAYOUT_DETAIL_FIELDS[merged.payoutMethod].filter((f) => !details[f]);
  if (missing.length > 0) {
    throw httpError(400, `payoutDetails for ${merged.payoutMethod} is missing: ${missing.join(', ')}`);
  }
}

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
  if (
    'publicServiceIds' in fields &&
    fields.publicServiceIds !== null &&
    (!Array.isArray(fields.publicServiceIds) || fields.publicServiceIds.some((v) => typeof v !== 'string'))
  ) {
    throw httpError(400, 'publicServiceIds must be an array of service ids');
  }
  if (
    'publicDoctorIds' in fields &&
    fields.publicDoctorIds !== null &&
    (!Array.isArray(fields.publicDoctorIds) || fields.publicDoctorIds.some((v) => typeof v !== 'string'))
  ) {
    throw httpError(400, 'publicDoctorIds must be an array of doctor ids');
  }
  if ('payoutMethod' in fields || 'payoutDetails' in fields) {
    assertValidPayout({ ...branch, ...fields });
  }
  if (fields.isPublic === true) {
    // Checked against the MERGED view (existing doc + this call's fields),
    // not just this call's body — a public-profile field set in an earlier
    // request still counts, so the caller isn't forced to resend everything
    // every time. All 5 are required together: a public toggle with a
    // half-filled profile is worse than not being public at all.
    const merged = { ...branch, ...fields };
    const missing = PUBLIC_PROFILE_REQUIRED_FIELDS.filter((f) => !merged[f]);
    if (missing.length > 0) {
      throw httpError(400, `To go public, set: ${missing.join(', ')}`);
    }
    if (!EMAIL_PATTERN.test(merged.publicEmail)) {
      throw httpError(400, 'publicEmail must be a valid email address');
    }
    // "Go Public" wizard (2026-08-16) — the 3 steps beyond the original
    // public-profile ones are required too, same "half-finished is worse
    // than not public" reasoning as the profile-fields check above.
    if (!Array.isArray(merged.publicServiceIds)) {
      throw httpError(400, 'To go public, choose which services to show (even an empty selection must be saved)');
    }
    if (!Array.isArray(merged.publicDoctorIds)) {
      throw httpError(400, 'To go public, choose which doctors to show (even an empty selection must be saved)');
    }
    assertValidPayout(merged);
    if (!merged.payoutMethod) {
      throw httpError(400, 'To go public, set up payout details');
    }
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

/**
 * Uploads/replaces a branch's public profile image (Patient App browse
 * card/detail). A FIXED key path (not a subcollection like patient
 * documents) — re-uploading simply overwrites the R2 object, so there's
 * never an orphaned old image to clean up.
 */
async function setPublicImage(id, { buffer, contentType }, { scope }) {
  const branch = await getById(id);
  if (!branch) throw httpError(404, 'Branch not found');
  assertBranchAccess(branch, scope);

  const key = `branches/${id}/public-image`;
  await storageService.uploadFile(buffer, key, contentType);
  await db.collection('branches').doc(id).update({ publicImageKey: key });

  return { ...branch, publicImageKey: key };
}

// Same TTL as browse.service.js's own (unexported) PUBLIC_IMAGE_URL_TTL_SECONDS
// for this exact field — longer than the 15-minute document default so the
// Go Public wizard's share-card preview/download doesn't go stale mid-review.
const PUBLIC_IMAGE_URL_TTL_SECONDS = 60 * 60 * 6;

/**
 * Resolves a branch's publicImageKey to a signed R2 GET url for staff
 * callers (the Go Public wizard's downloadable share card) — the
 * browse.service.js#toPublicBranch resolution is patient-role-only and
 * unreachable from a staff session, so this is a separate staff-scoped path.
 */
async function getPublicImageUrl(id, { scope }) {
  const branch = await getById(id);
  if (!branch) throw httpError(404, 'Branch not found');
  assertBranchAccess(branch, scope);

  if (!branch.publicImageKey) return { url: null };
  const url = await storageService.getSignedDownloadUrl(branch.publicImageKey, PUBLIC_IMAGE_URL_TTL_SECONDS);
  return { url };
}

/**
 * Fetches a branch's uploaded public-profile photo bytes for
 * `GET /branches/:branchId/image-view` (2026-08-19) to stream — same
 * reasoning as `staff.service.js#getPhoto`'s doc comment: the "Go Public"
 * wizard's downloadable share card renders this via `Image.memory` after an
 * authenticated fetch, not `Image.network` against the signed R2 url
 * `getPublicImageUrl` returns above, because that url is blocked by R2's
 * bucket having no CORS policy for browser origins under Flutter web's
 * CanvasKit renderer. Returns null if no photo uploaded yet (caller 404s).
 */
async function getPublicImageBytes(id, { scope }) {
  const branch = await getById(id);
  if (!branch) throw httpError(404, 'Branch not found');
  assertBranchAccess(branch, scope);

  if (!branch.publicImageKey) return null;
  return storageService.getObjectBuffer(branch.publicImageKey);
}

module.exports = {
  list,
  listWithPlan,
  getById,
  create,
  update,
  setStatus,
  setPublicImage,
  getPublicImageUrl,
  getPublicImageBytes,
};
