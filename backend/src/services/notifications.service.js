// Service layer for notifications (spec section 6.11, Part 14).
// Every notification is BACKEND-TRIGGERED (DONE CONDITION: "fire from
// backend events, not client-side, so they fire even if the app is
// closed") — called as a best-effort side effect from the relevant entity
// service (appointments/inventory/invoices), the same non-blocking
// try/catch "hook" pattern Part 12 established for auto-generating an
// invoice on appointment completion: a notification failure must never
// block the real write it's reporting on.
//
// Historically a web-only admin build with no Patient App — every trigger
// below targeted STAFF only (receptionist/doctor/pharmacist/accountant),
// even where the spec described a patient-facing message (e.g.
// "payment-recorded confirmation"), since there was no account/device to
// push to. notifyAppointmentReminder (Part 22) is the FIRST genuinely
// patient-facing trigger — it pushes to the appointment's own patient, not
// staff. It resolves its recipient via `/patients/{patientId}.
// linkedAppAccountId` (see patients.service.js), NOT `patientId` itself —
// an appointment's patientId is a walk-in record id, never a real
// `/users/{uid}` to push to directly.
const { db, messaging } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/**
 * Best-effort push (spec: "Push (FCM) is the default free channel"). Silent
 * no-op if the recipient has no `fcmToken` on their /users doc — there is
 * no client-side token-registration flow yet in this build, so this is
 * wired correctly for the moment one exists, with nothing to revisit. Never
 * throws — a push failure must not affect the in-app notification, which
 * has already been written by the time this runs.
 */
async function sendPush(recipientId, { title, body }) {
  try {
    const userDoc = await db.collection('users').doc(recipientId).get();
    const token = userDoc.exists ? userDoc.data().fcmToken : null;
    if (!token) return;
    await messaging.send({ token, notification: { title, body } });
  } catch (err) {
    console.warn(`[notifications] push to ${recipientId} failed: ${err.message}`);
  }
}

/** Writes one notification doc for one recipient, plus a best-effort push. */
async function create({ clinicId, branchId, recipientId, recipientRole, type, title, body, data }) {
  const doc = {
    clinicId,
    branchId: branchId || null,
    recipientId,
    recipientRole: recipientRole || null,
    type,
    title,
    body,
    data: data || {},
    isRead: false,
    createdAt: new Date().toISOString(),
  };
  const ref = await db.collection('notifications').add(doc);
  await sendPush(recipientId, { title, body });
  return { id: ref.id, ...doc };
}

/**
 * Fans out to every active staff member of [role] at [branchId] — "New
 * booking alert to receptionist/doctor", "Low-stock alert to pharmacist"
 * are role-broadcasts, not single-recipient (spec 6.11). [excludeActorId]
 * skips notifying whoever triggered the event themselves — pure noise
 * otherwise (e.g. the receptionist who just booked doesn't need to be told
 * they booked something).
 */
async function notifyRole({ clinicId, branchId, role, type, title, body, data, excludeActorId }) {
  const snap = await db
    .collection('users')
    .where('clinicId', '==', clinicId)
    .where('branchId', '==', branchId)
    .where('role', '==', role)
    .get();

  const recipients = snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((u) => u.isActive !== false && u.id !== excludeActorId);

  return Promise.all(
    recipients.map((u) =>
      create({ clinicId, branchId, recipientId: u.id, recipientRole: role, type, title, body, data })
    )
  );
}

/** New booking alert (spec 6.11) — receptionists AND the assigned doctor at the appointment's branch. */
async function notifyNewBooking(appointment, actor) {
  const title = 'New appointment booked';
  const body = `A new appointment was booked for ${appointment.date} at ${appointment.startTime}.`;
  const data = { appointmentId: appointment.id };

  await Promise.all([
    notifyRole({
      clinicId: appointment.clinicId,
      branchId: appointment.branchId,
      role: ROLES.RECEPTIONIST,
      type: 'newBooking',
      title,
      body,
      data,
      excludeActorId: actor.actorId,
    }),
    create({
      clinicId: appointment.clinicId,
      branchId: appointment.branchId,
      recipientId: appointment.doctorId,
      recipientRole: ROLES.DOCTOR,
      type: 'newBooking',
      title,
      body,
      data,
    }),
  ]);
}

/**
 * Cancellation alert (Part 21, Task 4) — same recipients as
 * notifyNewBooking (branch receptionists + the assigned doctor), fired from
 * appointments.service.js#setStatus() whenever an appointment moves to
 * 'cancelled'. Deliberately does NOT branch on `actor.role`/`actor.actorRole`
 * — a staff-triggered and a patient-triggered cancellation must look
 * identical to the clinic, which is exactly the DONE CONDITION this closes
 * (Part 21's own audit found no such trigger existed at all before now, for
 * either kind of caller).
 */
async function notifyCancellation(appointment, actor) {
  const title = 'Appointment cancelled';
  const body = `The appointment on ${appointment.date} at ${appointment.startTime} was cancelled.`;
  const data = { appointmentId: appointment.id };

  await Promise.all([
    notifyRole({
      clinicId: appointment.clinicId,
      branchId: appointment.branchId,
      role: ROLES.RECEPTIONIST,
      type: 'appointmentCancelled',
      title,
      body,
      data,
      excludeActorId: actor.actorId,
    }),
    create({
      clinicId: appointment.clinicId,
      branchId: appointment.branchId,
      recipientId: appointment.doctorId,
      recipientRole: ROLES.DOCTOR,
      type: 'appointmentCancelled',
      title,
      body,
      data,
    }),
  ]);
}

/** Reschedule alert (Part 21, Task 4) — same shape/recipients as notifyCancellation. */
async function notifyReschedule(appointment, actor) {
  const title = 'Appointment rescheduled';
  const body = `An appointment was rescheduled to ${appointment.date} at ${appointment.startTime}.`;
  const data = { appointmentId: appointment.id };

  await Promise.all([
    notifyRole({
      clinicId: appointment.clinicId,
      branchId: appointment.branchId,
      role: ROLES.RECEPTIONIST,
      type: 'appointmentRescheduled',
      title,
      body,
      data,
      excludeActorId: actor.actorId,
    }),
    create({
      clinicId: appointment.clinicId,
      branchId: appointment.branchId,
      recipientId: appointment.doctorId,
      recipientRole: ROLES.DOCTOR,
      type: 'appointmentRescheduled',
      title,
      body,
      data,
    }),
  ]);
}

/**
 * Appointment reminder (Part 22 Task 3) — pushes to the PATIENT, not staff
 * (see this module's header). Silently no-ops if the appointment's
 * /patients record was never linked to an app account (a pure walk-in
 * booking has nobody to push to) — never an error, since that's an
 * entirely expected, common case, not a failure.
 */
async function notifyAppointmentReminder(appointment, { threshold, doctorName, clinicName }) {
  const patientDoc = await db.collection('patients').doc(appointment.patientId).get();
  const linkedUid = patientDoc.exists ? patientDoc.data().linkedAppAccountId : null;
  if (!linkedUid) return;

  const doctorLabel = doctorName ? `Dr. ${doctorName}` : 'your doctor';
  const clinicLabel = clinicName || 'the clinic';
  const title = 'Appointment reminder';
  const body =
    threshold === 'twoHour'
      ? `Your appointment with ${doctorLabel} at ${clinicLabel} is in 2 hours.`
      : `Your appointment with ${doctorLabel} at ${clinicLabel} is tomorrow at ${appointment.startTime}.`;

  await create({
    clinicId: appointment.clinicId,
    branchId: appointment.branchId,
    recipientId: linkedUid,
    recipientRole: ROLES.PATIENT,
    type: 'appointmentReminder',
    title,
    body,
    data: { appointmentId: appointment.id, threshold },
  });
}

/** Low-stock alert (spec 6.11) — every pharmacist at the item's branch. */
async function notifyLowStock(item, actor) {
  await notifyRole({
    clinicId: item.clinicId,
    branchId: item.branchId,
    role: ROLES.PHARMACIST,
    type: 'lowStock',
    title: 'Low stock',
    body: `${item.name} is running low (${item.quantity} ${item.unit} left).`,
    data: { itemId: item.id },
    excludeActorId: actor.actorId,
  });
}

/**
 * Payment-recorded confirmation (spec 6.11) — the spec frames this as
 * patient-facing, but there's no Patient App/account in this build (see
 * module docstring), so it's redirected to the branch's front-desk staff
 * (Receptionist/Accountant) as an internal confirmation instead.
 */
async function notifyPaymentRecorded(invoice, amountRwf, method, actor) {
  const title = 'Payment recorded';
  const body = `${amountRwf} RWF (${method}) recorded on invoice ${invoice.id}.`;
  const data = { invoiceId: invoice.id };

  await Promise.all(
    [ROLES.RECEPTIONIST, ROLES.ACCOUNTANT].map((role) =>
      notifyRole({
        clinicId: invoice.clinicId,
        branchId: invoice.branchId,
        role,
        type: 'paymentRecorded',
        title,
        body,
        data,
        excludeActorId: actor.actorId,
      })
    )
  );
}

/** Newest first, for the Admin Dashboard bell (Task 1). */
async function list(recipientId, { limit = 50 } = {}) {
  const snap = await db.collection('notifications').where('recipientId', '==', recipientId).get();
  const notifications = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  return notifications.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1)).slice(0, limit);
}

/** The one narrow write this collection exposes to clients — toggling a recipient's OWN read flag, never the notification's content. */
async function markRead(id, recipientId) {
  const ref = db.collection('notifications').doc(id);
  const doc = await ref.get();
  if (!doc.exists) throw httpError(404, 'Notification not found');
  if (doc.data().recipientId !== recipientId) {
    throw httpError(403, 'This notification does not belong to you');
  }
  await ref.update({ isRead: true, readAt: new Date().toISOString() });
  return { id: doc.id, ...doc.data(), isRead: true };
}

async function markAllRead(recipientId) {
  const snap = await db
    .collection('notifications')
    .where('recipientId', '==', recipientId)
    .where('isRead', '==', false)
    .get();
  await Promise.all(snap.docs.map((doc) => doc.ref.update({ isRead: true, readAt: new Date().toISOString() })));
  return { updated: snap.size };
}

module.exports = {
  create,
  notifyRole,
  notifyNewBooking,
  notifyCancellation,
  notifyReschedule,
  notifyAppointmentReminder,
  notifyLowStock,
  notifyPaymentRecorded,
  list,
  markRead,
  markAllRead,
};
