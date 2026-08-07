// Service layer for staff (spec section 6.3 / 6.5 / 9 — Part 8).
// Staff = doctor, nurse, receptionist, pharmacist, accountant (Task 1's
// explicit role list — clinic_admin/super_admin accounts are created
// elsewhere). Doctors additionally get a /doctors/{uid} document (specialty,
// departmentIds, schedule, blockedSlots, ratings).
// Accounts are created DIRECTLY via authService.createStaffAccountWithPassword
// — the one account-creation path, no invite flow (see auth.service.js).
//
// branch_admin (2026-07-25): also created and listed through this same path
// now — a branch's admin is created as the second step of "+ Add Branch"
// (Clinic Admin only, see the actorRole check in create() below), so they
// show up in that branch's own Staff list with the "Branch Admin" role
// label, same as any other staff member.
const { db } = require('../config/firebase-admin');
const { auth } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');
const authService = require('./auth.service');
const auditLogService = require('./auditLog.service');

const STAFF_ROLES = [
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LABORATORIAN,
  ROLES.RECEPTIONIST,
  ROLES.PHARMACIST,
  ROLES.ACCOUNTANT,
];

// What list() shows for a branch's Staff screen — the 5 STAFF_ROLES plus
// that branch's own admin, if it has one.
const LISTABLE_ROLES = [...STAFF_ROLES, ROLES.BRANCH_ADMIN];

// What create() accepts — same as LISTABLE_ROLES, but branch_admin is
// further gated to Clinic Admin/Super Admin callers only (see create()).
const CREATABLE_ROLES = [...STAFF_ROLES, ROLES.BRANCH_ADMIN];

// Appointment statuses that count as a doctor "being in use" — not
// currently enforced as a deactivation block (Part 8 only requires that
// staff are never hard-deleted; see staff.controller.js's remove() stub).
const ACTIVE_APPOINTMENT_STATUSES = ['pending', 'confirmed', 'checkedIn'];

const DAYS_OF_WEEK = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/** Attaches /doctors/{uid} fields (specialty, departmentIds, ratings) onto matching doctor rows, batched. */
async function attachDoctorFields(staffRows) {
  const doctorIds = staffRows.filter((s) => s.role === ROLES.DOCTOR).map((s) => s.id);
  if (doctorIds.length === 0) return staffRows;

  const doctorDocs = await Promise.all(doctorIds.map((id) => db.collection('doctors').doc(id).get()));
  const doctorById = {};
  doctorDocs.forEach((doc) => {
    if (doc.exists) doctorById[doc.id] = doc.data();
  });

  return staffRows.map((s) => {
    if (s.role !== ROLES.DOCTOR) return s;
    const d = doctorById[s.id];
    return {
      ...s,
      specialty: d?.specialty || null,
      bio: d?.bio || null,
      departmentIds: d?.departmentIds || [],
      schedule: d?.schedule || [],
      breakMinutes: d?.breakMinutes || 0,
      blockedSlots: d?.blockedSlots || [],
      averageRating: d?.averageRating || 0,
      reviewCount: d?.reviewCount || 0,
    };
  });
}

/** Staff (STAFF_ROLES plus that branch's own admin) for one branch — Part 8 Task 1. */
async function list({ clinicId, branchId }) {
  let query = db
    .collection('users')
    .where('clinicId', '==', clinicId)
    .where('role', 'in', LISTABLE_ROLES);
  if (branchId) query = query.where('branchId', '==', branchId);

  const snapshot = await query.get();
  const staff = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  return attachDoctorFields(staff);
}

async function getById(id) {
  const doc = await db.collection('users').doc(id).get();
  if (!doc.exists) return null;
  const [withDoctorFields] = await attachDoctorFields([{ id: doc.id, ...doc.data() }]);
  return withDoctorFields;
}

function assertAccess(staffMember, scope) {
  if (scope.level === 'platform') return;
  if (staffMember.clinicId !== scope.clinicId) {
    throw httpError(403, 'This staff member belongs to a different clinic');
  }
  if (scope.level === 'branch' && staffMember.branchId !== scope.branchId) {
    throw httpError(403, 'This staff member belongs to a different branch');
  }
}

/**
 * Creates a staff account directly, active immediately (Part 8 Task 1/3 —
 * no invite, password shown once by the caller after this returns). Doctors
 * additionally get a /doctors/{uid} document.
 *
 * branch_admin (2026-07-25) is the one CREATABLE_ROLES entry with extra
 * rules: only a Clinic Admin/Super Admin may create one (a Branch Admin
 * can't create a peer for another branch), and a branch can only ever have
 * one — this is step 2 of "+ Add Branch", not a general staff role.
 */
async function create(
  { email, password, name, role, clinicId, branchId, phone, specialty, departmentIds },
  actor
) {
  if (!CREATABLE_ROLES.includes(role)) {
    throw httpError(400, `Role must be one of: ${CREATABLE_ROLES.join(', ')}`);
  }
  if (!branchId) throw httpError(400, 'branchId is required');

  if (role === ROLES.BRANCH_ADMIN) {
    if (actor.actorRole !== ROLES.CLINIC_ADMIN && actor.actorRole !== ROLES.SUPER_ADMIN) {
      throw httpError(403, 'Only a Clinic Admin can assign a branch admin.');
    }
    const existing = await db
      .collection('users')
      .where('branchId', '==', branchId)
      .where('role', '==', ROLES.BRANCH_ADMIN)
      .limit(1)
      .get();
    if (!existing.empty) {
      throw httpError(400, 'This branch already has an admin.');
    }
  }

  const { uid } = await authService.createStaffAccountWithPassword({
    email,
    password,
    name,
    role,
    clinicId,
    branchId,
    phone,
    createdBy: actor.actorId,
  });

  if (role === ROLES.DOCTOR) {
    await db
      .collection('doctors')
      .doc(uid)
      .set({
        specialty: specialty || null,
        bio: null,
        departmentIds: Array.isArray(departmentIds) ? departmentIds : [],
        schedule: [],
        breakMinutes: 0,
        blockedSlots: [],
        averageRating: 0,
        reviewCount: 0,
      });
  }

  await auditLogService.write({
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    clinicId,
    action: 'staff.created',
    targetCollection: 'users',
    targetId: uid,
  });

  return getById(uid);
}

const EDITABLE_FIELDS = ['name', 'phone', 'email'];
const EDITABLE_DOCTOR_FIELDS = ['specialty', 'departmentIds'];

/** Edits name/phone/email (all roles) and specialty/departmentIds (doctors only). Role is fixed at creation. */
async function update(id, fields, actor) {
  const staffMember = await getById(id);
  if (!staffMember) throw httpError(404, 'Staff member not found');
  assertAccess(staffMember, actor.scope);

  const updates = {};
  for (const key of EDITABLE_FIELDS) {
    if (fields[key] !== undefined) updates[key] = fields[key];
  }
  if (updates.name === '') throw httpError(400, 'Name cannot be empty');

  if (updates.email && updates.email !== staffMember.email) {
    await auth.updateUser(id, { email: updates.email });
  }
  if (Object.keys(updates).length > 0) {
    await db.collection('users').doc(id).update(updates);
  }

  if (staffMember.role === ROLES.DOCTOR) {
    const doctorUpdates = {};
    for (const key of EDITABLE_DOCTOR_FIELDS) {
      if (fields[key] !== undefined) doctorUpdates[key] = fields[key];
    }
    if (Object.keys(doctorUpdates).length > 0) {
      await db.collection('doctors').doc(id).update(doctorUpdates);
    }
  }

  return getById(id);
}

/**
 * Activate/deactivate — the ONLY removal path for staff (spec/master rule
 * 10: soft-delete only, never hard-delete a record with dependent history;
 * there is no DELETE endpoint for staff at all, see staff.controller.js).
 */
async function setStatus(id, isActive, actor) {
  const staffMember = await getById(id);
  if (!staffMember) throw httpError(404, 'Staff member not found');
  assertAccess(staffMember, actor.scope);

  await db.collection('users').doc(id).update({ isActive });
  await auth.updateUser(id, { disabled: !isActive });

  await auditLogService.write({
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    clinicId: staffMember.clinicId,
    action: isActive ? 'staff.activated' : 'staff.deactivated',
    targetCollection: 'users',
    targetId: id,
  });

  return getById(id);
}

function assertValidTime(value, label) {
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(value || '')) {
    throw httpError(400, `${label} must be 'HH:mm'`);
  }
}

function toMinutes(hhmm) {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

/**
 * Weekly recurring schedule (spec 6.5, Part 8 Task 2) — rejects overlapping
 * slots on the same day for the same doctor. Only Branch Admin/Receptionist/
 * Clinic Admin may write it (Doctor is view-own-only, enforced in the
 * controller/route role list).
 *
 * breakMinutes (2026-07-26, explicit user instruction) — a single per-doctor
 * buffer the booking engine (`appointments.service.js`'s
 * `getAvailableSlots`) enforces on both sides of every booked appointment
 * AND every blocked slot, so two bookings for the same doctor are never
 * offered back-to-back with no recovery time between them.
 */
async function setSchedule(doctorId, entries, breakMinutes, actor) {
  const staffMember = await getById(doctorId);
  if (!staffMember) throw httpError(404, 'Doctor not found');
  if (staffMember.role !== ROLES.DOCTOR) throw httpError(400, 'This staff member is not a doctor');
  assertAccess(staffMember, actor.scope);

  if (!Array.isArray(entries)) throw httpError(400, 'schedule must be an array');

  const normalizedBreakMinutes = breakMinutes ?? 0;
  if (!Number.isInteger(normalizedBreakMinutes) || normalizedBreakMinutes < 0) {
    throw httpError(400, 'breakMinutes must be a non-negative whole number');
  }

  const byDay = {};
  for (const entry of entries) {
    const { day, startTime, endTime, slotDurationMins } = entry;
    if (!DAYS_OF_WEEK.includes(day)) {
      throw httpError(400, `day must be one of: ${DAYS_OF_WEEK.join(', ')}`);
    }
    assertValidTime(startTime, 'startTime');
    assertValidTime(endTime, 'endTime');
    if (toMinutes(startTime) >= toMinutes(endTime)) {
      throw httpError(400, `${day}: startTime must be before endTime`);
    }
    if (!Number.isInteger(slotDurationMins) || slotDurationMins <= 0) {
      throw httpError(400, `${day}: slotDurationMins must be a positive whole number`);
    }
    (byDay[day] ||= []).push(entry);
  }

  // Overlap check, per day: sort by start time, reject if any entry starts
  // before the previous one ends.
  for (const [day, dayEntries] of Object.entries(byDay)) {
    const sorted = [...dayEntries].sort((a, b) => toMinutes(a.startTime) - toMinutes(b.startTime));
    for (let i = 1; i < sorted.length; i++) {
      if (toMinutes(sorted[i].startTime) < toMinutes(sorted[i - 1].endTime)) {
        throw httpError(
          400,
          `${day}: ${sorted[i - 1].startTime}–${sorted[i - 1].endTime} overlaps ${sorted[i].startTime}–${sorted[i].endTime}`
        );
      }
    }
  }

  await db.collection('doctors').doc(doctorId).update({ schedule: entries, breakMinutes: normalizedBreakMinutes });
  return getById(doctorId);
}

/**
 * Blocks a date/time range (spec 6.5, Part 8 Task 2). ALWAYS saves the
 * block — a conflict with existing bookings is never silently dropped, it's
 * returned to the caller as `conflictingAppointments` so staff can review
 * and handle those appointments themselves (reschedule/cancel/contact the
 * patient) rather than the system doing it for them.
 */
async function addBlockedSlot(doctorId, { date, startTime, endTime, reason }, actor) {
  const staffMember = await getById(doctorId);
  if (!staffMember) throw httpError(404, 'Doctor not found');
  if (staffMember.role !== ROLES.DOCTOR) throw httpError(400, 'This staff member is not a doctor');
  assertAccess(staffMember, actor.scope);

  if (!date) throw httpError(400, 'date is required');
  assertValidTime(startTime, 'startTime');
  assertValidTime(endTime, 'endTime');
  if (toMinutes(startTime) >= toMinutes(endTime)) {
    throw httpError(400, 'startTime must be before endTime');
  }

  const blockedSlot = { date, startTime, endTime, reason: reason || null };
  const doctorDoc = await db.collection('doctors').doc(doctorId).get();
  const existingBlocked = doctorDoc.data()?.blockedSlots || [];
  await db
    .collection('doctors')
    .doc(doctorId)
    .update({ blockedSlots: [...existingBlocked, blockedSlot] });

  // appointments isn't built yet (Part 9+), so this query is always empty
  // for now — it's wired ahead of time so the flag-don't-drop behavior is
  // correct the moment bookings exist, with nothing left to revisit.
  const apptSnap = await db
    .collection('appointments')
    .where('doctorId', '==', doctorId)
    .where('date', '==', date)
    .where('status', 'in', ACTIVE_APPOINTMENT_STATUSES)
    .get();

  const conflictingAppointments = apptSnap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((appt) => toMinutes(appt.startTime) < toMinutes(endTime) && toMinutes(appt.endTime) > toMinutes(startTime));

  return { blockedSlot, conflictingAppointments };
}

module.exports = {
  STAFF_ROLES,
  list,
  getById,
  create,
  update,
  setStatus,
  setSchedule,
  addBlockedSlot,
};
