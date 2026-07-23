// Service layer for staff (spec section 6.3 / 6.5 / 9 — Part 8).
// Staff = doctor, nurse, receptionist, pharmacist, accountant (Task 1's
// explicit role list — branch_admin/organization_admin/super_admin
// accounts are created elsewhere). Doctors additionally get a /doctors/{uid}
// document (specialty, departmentIds, schedule, blockedSlots, ratings).
// Accounts are created DIRECTLY via authService.createStaffAccountWithPassword
// — the one account-creation path, no invite flow (see auth.service.js).
const { db } = require('../config/firebase-admin');
const { auth } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');
const authService = require('./auth.service');

const STAFF_ROLES = [
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.RECEPTIONIST,
  ROLES.PHARMACIST,
  ROLES.ACCOUNTANT,
];

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

async function auditLog({ actorId, actorRole }, action, targetId, organizationId) {
  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: actorRole || null,
    action,
    targetCollection: 'users',
    targetId,
    organizationId,
    timestamp: new Date().toISOString(),
  });
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
      blockedSlots: d?.blockedSlots || [],
      averageRating: d?.averageRating || 0,
      reviewCount: d?.reviewCount || 0,
    };
  });
}

/** Staff (the 5 STAFF_ROLES only) for one branch — Part 8 Task 1. */
async function list({ organizationId, branchId }) {
  let query = db
    .collection('users')
    .where('organizationId', '==', organizationId)
    .where('role', 'in', STAFF_ROLES);
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
  if (staffMember.organizationId !== scope.organizationId) {
    throw httpError(403, 'This staff member belongs to a different organization');
  }
  if (scope.level === 'branch' && staffMember.branchId !== scope.branchId) {
    throw httpError(403, 'This staff member belongs to a different branch');
  }
}

/**
 * Creates a staff account directly, active immediately (Part 8 Task 1/3 —
 * no invite, password shown once by the caller after this returns). Doctors
 * additionally get a /doctors/{uid} document.
 */
async function create(
  { email, password, name, role, organizationId, branchId, phone, specialty, departmentIds },
  actor
) {
  if (!STAFF_ROLES.includes(role)) {
    throw httpError(400, `Role must be one of: ${STAFF_ROLES.join(', ')}`);
  }
  if (!branchId) throw httpError(400, 'branchId is required');

  const { uid } = await authService.createStaffAccountWithPassword({
    email,
    password,
    name,
    role,
    organizationId,
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
        blockedSlots: [],
        averageRating: 0,
        reviewCount: 0,
      });
  }

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

  await auditLog(actor, 'staff.updated', id, staffMember.organizationId);
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

  await auditLog(
    actor,
    isActive ? 'staff.activated' : 'staff.deactivated',
    id,
    staffMember.organizationId
  );
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
 * Organization Admin may write it (Doctor is view-own-only, enforced in the
 * controller/route role list).
 */
async function setSchedule(doctorId, entries, actor) {
  const staffMember = await getById(doctorId);
  if (!staffMember) throw httpError(404, 'Doctor not found');
  if (staffMember.role !== ROLES.DOCTOR) throw httpError(400, 'This staff member is not a doctor');
  assertAccess(staffMember, actor.scope);

  if (!Array.isArray(entries)) throw httpError(400, 'schedule must be an array');

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

  await db.collection('doctors').doc(doctorId).update({ schedule: entries });
  await auditLog(actor, 'doctor.scheduleUpdated', doctorId, staffMember.organizationId);
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

  await auditLog(actor, 'doctor.slotBlocked', doctorId, staffMember.organizationId);

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
