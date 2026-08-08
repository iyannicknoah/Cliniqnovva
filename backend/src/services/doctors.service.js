// Service layer for doctors (Part 20 — patient-facing browse). This route
// was scaffolded back in Part 6/7 with ROLES.PATIENT already wired into its
// role lists but never implemented (doctor CRUD ended up living under
// staff.routes.js/staff.service.js instead, see that file's header). This
// fills in the read side as the dedicated PUBLIC-WITHIN-APP doctor read
// path: cross-clinic, patient-safe fields only — never email/phone/
// blockedSlots, which stay staff.service.js-only.
const { db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/** Explicit allowlist — never spread raw doc data into a patient-facing response. */
function toPublicDoctor(userDoc, doctorDoc) {
  const u = userDoc || {};
  const d = doctorDoc || {};
  return {
    id: u.id,
    name: u.name || null,
    branchId: u.branchId || null,
    clinicId: u.clinicId || null,
    specialty: d.specialty || null,
    bio: d.bio || null,
    // Not sensitive (same status as specialty) — Part 21's Booking screen
    // filters "doctors for this department" the same way the web
    // dashboard's staff list already does (staff.service.js's
    // attachDoctorFields also exposes it, unrestricted by role there).
    departmentIds: Array.isArray(d.departmentIds) ? d.departmentIds : [],
    // Day/start/end/slot-length only — blockedSlots and breakMinutes are
    // operational scheduling detail, not part of a patient-facing profile.
    schedule: Array.isArray(d.schedule)
      ? d.schedule.map(({ day, startTime, endTime, slotDurationMins }) => ({
          day,
          startTime,
          endTime,
          slotDurationMins,
        }))
      : [],
    averageRating: d.averageRating || 0,
    reviewCount: d.reviewCount || 0,
  };
}

async function fetchDoctorUsers({ branchId }) {
  let query = db.collection('users').where('role', '==', ROLES.DOCTOR);
  if (branchId) query = query.where('branchId', '==', branchId);
  const snap = await query.get();
  return snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((u) => u.isActive !== false);
}

/** Doctors at one branch, patient-safe shape — Part 20 Task 3. */
async function list({ branchId }) {
  if (!branchId) throw httpError(400, 'branchId is required');
  const users = await fetchDoctorUsers({ branchId });
  if (users.length === 0) return [];

  const doctorDocs = await Promise.all(users.map((u) => db.collection('doctors').doc(u.id).get()));
  const doctorById = {};
  doctorDocs.forEach((doc) => {
    if (doc.exists) doctorById[doc.id] = doc.data();
  });

  return users.map((u) => toPublicDoctor(u, doctorById[u.id]));
}

/** One doctor, patient-safe shape, or null if not found/not an active doctor. */
async function getById(id) {
  const userDoc = await db.collection('users').doc(id).get();
  if (!userDoc.exists) return null;
  const user = { id: userDoc.id, ...userDoc.data() };
  if (user.role !== ROLES.DOCTOR || user.isActive === false) return null;

  const doctorDoc = await db.collection('doctors').doc(id).get();
  return toPublicDoctor(user, doctorDoc.exists ? doctorDoc.data() : null);
}

/**
 * Cross-clinic doctor search by name/specialty (Part 20 Task 2 — the Browse
 * search bar matches "clinic/branch name, doctor name, specialty"). Returns
 * the set of branchIds with at least one matching active doctor, so
 * browse.service.js can OR it into the branch-name/address match.
 */
async function searchBranchIdsByNameOrSpecialty(term) {
  const needle = term.trim().toLowerCase();
  if (!needle) return new Set();

  const users = await fetchDoctorUsers({});
  if (users.length === 0) return new Set();

  const doctorDocs = await Promise.all(users.map((u) => db.collection('doctors').doc(u.id).get()));
  const doctorById = {};
  doctorDocs.forEach((doc) => {
    if (doc.exists) doctorById[doc.id] = doc.data();
  });

  const branchIds = new Set();
  users.forEach((u) => {
    const specialty = doctorById[u.id]?.specialty || '';
    const nameMatch = (u.name || '').toLowerCase().includes(needle);
    const specialtyMatch = specialty.toLowerCase().includes(needle);
    if ((nameMatch || specialtyMatch) && u.branchId) branchIds.add(u.branchId);
  });
  return branchIds;
}

module.exports = { list, getById, searchBranchIdsByNameOrSpecialty };
