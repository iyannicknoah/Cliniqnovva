// Service layer for appointments (spec section 6.7 / 9 — Part 11).
// The central booking engine. Every write that could race (booking,
// rescheduling, check-in's queue-number assignment) goes through a
// Firestore transaction that RE-READS availability immediately before
// writing — never trusts a slot list the client fetched moments earlier.
const { db } = require('../config/firebase-admin');
const invoicesService = require('./invoices.service');
const notificationsService = require('./notifications.service');

// Statuses that "hold" a slot — a cancelled appointment never blocks
// anything, so it's deliberately excluded (spec 6.7: "cancelling frees the
// slot").
const ACTIVE_STATUSES = ['pending', 'confirmed', 'checkedIn', 'completed'];

const VALID_TRANSITIONS = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['checkedIn', 'cancelled'],
  // Mark Complete only enabled after Check-In (Part 11 Task 3 DONE
  // CONDITION) — this state machine IS that rule; 'completed' is reachable
  // from nowhere else.
  checkedIn: ['completed', 'cancelled'],
  completed: [],
  cancelled: [],
};

// JS Date#getUTCDay() order (0=Sunday), matching how dates are compared below.
const DAY_NAMES = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

function toMinutes(hhmm) {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

function fromMinutes(mins) {
  const h = Math.floor(mins / 60)
    .toString()
    .padStart(2, '0');
  const m = (mins % 60).toString().padStart(2, '0');
  return `${h}:${m}`;
}

/**
 * True if [aStart,aEnd) overlaps `b` (an existing booked appointment or
 * blocked slot) padded by `bufferMins` on BOTH sides — this is what
 * enforces a doctor's required recovery time between one appointment and
 * the next (2026-07-26, explicit user instruction; pass 0 for a plain,
 * unbuffered overlap check). Padding both sides of `b`, not just after it,
 * means the gap holds no matter which of two appointments for the same
 * doctor got booked first.
 */
function overlapsWithBuffer(aStart, aEnd, bStart, bEnd, bufferMins) {
  return toMinutes(aStart) < toMinutes(bEnd) + bufferMins && toMinutes(aEnd) > toMinutes(bStart) - bufferMins;
}

/** True Saturday whose date+7 falls in the next month — the last Saturday. */
function isLastSaturdayOfMonth(dateStr) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  if (d.getUTCDay() !== 6) return false;
  const next = new Date(d);
  next.setUTCDate(d.getUTCDate() + 7);
  return next.getUTCMonth() !== d.getUTCMonth();
}

/** Africa/Kigali is UTC+2 year-round (no DST) — spec section 1. */
function kigaliDateString(date = new Date()) {
  return new Date(date.getTime() + 2 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

/**
 * The real UTC instant a Kigali-local `date`+`startTime` refers to (Part
 * 22's reminder job needs an actual timestamp to compare against "now",
 * unlike isPastInKigali()'s same-day-only string/minute comparison above).
 * Kigali local = UTC + 2h (fixed, no DST), so the reverse is UTC = Kigali
 * local - 2h — same ±2h convention as kigaliDateString()/isPastInKigali()
 * above, just solved for the opposite direction.
 */
function kigaliDateTimeToUtcMs(date, startTime) {
  return Date.parse(`${date}T${startTime}:00Z`) - 2 * 60 * 60 * 1000;
}

/**
 * True if `date`+`startTime` (Africa/Kigali) has already passed. Used to
 * keep today's already-elapsed slots out of `getAvailableSlots`, and to
 * reject `book()`/`reschedule()` calls that slip a past time through
 * anyway (2026-07-26, explicit user instruction — an 08:00 slot was still
 * showing as bookable at 16:30 the same day; nothing anywhere checked the
 * current time against the requested one).
 */
function isPastInKigali(date, startTime) {
  const nowKigali = new Date(Date.now() + 2 * 60 * 60 * 1000);
  const todayKigali = nowKigali.toISOString().slice(0, 10);
  if (date < todayKigali) return true;
  if (date > todayKigali) return false;
  const nowMinutes = nowKigali.getUTCHours() * 60 + nowKigali.getUTCMinutes();
  return toMinutes(startTime) < nowMinutes;
}

/**
 * The doctor's working window(s) for one date, after applying
 * Umuganda-Saturday clipping (Part 8 Task 2's rule, actually enforced
 * against real bookable slots):
 *   - The last Saturday of the month → clipped to the branch's
 *     umugandaSaturdayHours if set, else defaults to "closed until midday"
 *     (starts no earlier than 12:00, unless the override is is24Hours).
 *
 * Public holidays no longer close the day (2026-07-26, explicit user
 * instruction — Rwandan clinics operate on public holidays same as any
 * other day) — this used to also return [] for an un-overridden holiday.
 */
async function effectiveScheduleWindows({ doctor, branch, dateStr }) {
  const dayName = DAY_NAMES[new Date(`${dateStr}T00:00:00Z`).getUTCDay()];
  let entries = (doctor.schedule || []).filter((e) => e.day === dayName);
  if (entries.length === 0) return [];

  if (dayName === 'saturday' && isLastSaturdayOfMonth(dateStr)) {
    const override = branch.umugandaSaturdayHours;
    if (!override?.is24Hours) {
      const effectiveStartMin = toMinutes(override?.start || '12:00');
      const effectiveEndMin = override?.end ? toMinutes(override.end) : null;
      entries = entries
        .map((e) => {
          const startMin = Math.max(toMinutes(e.startTime), effectiveStartMin);
          const endMin = effectiveEndMin !== null ? Math.min(toMinutes(e.endTime), effectiveEndMin) : toMinutes(e.endTime);
          return startMin < endMin ? { ...e, startTime: fromMinutes(startMin), endTime: fromMinutes(endMin) } : null;
        })
        .filter(Boolean);
    }
  }

  return entries;
}

/**
 * Every candidate slot start/end for one doctor/date/service, minus
 * whatever's already booked or blocked, and minus the doctor's own
 * `breakMinutes` buffer around each of those (2026-07-26, explicit user
 * instruction — e.g. a 60-min appointment at 2:00 with a 10-min break makes
 * 3:10 the next real slot, not 3:00). Slot START times step at the doctor's
 * own configured slotDurationMins (booking granularity); each slot's actual
 * span is the SELECTED SERVICE's defaultDurationMins (a 30-min consultation
 * reserves more of the doctor's day than a 10-min vaccination, even on a
 * clinic that offers slots every 15 minutes).
 */
async function getAvailableSlots({ doctorId, branchId, serviceId, date }) {
  const [doctorDoc, branchDoc, serviceDoc] = await Promise.all([
    db.collection('doctors').doc(doctorId).get(),
    db.collection('branches').doc(branchId).get(),
    db.collection('services').doc(serviceId).get(),
  ]);
  if (!doctorDoc.exists) throw httpError(404, 'Doctor not found');
  if (!branchDoc.exists) throw httpError(404, 'Branch not found');
  if (!serviceDoc.exists) throw httpError(404, 'Service not found');

  const doctor = doctorDoc.data();
  const branch = branchDoc.data();
  const durationMins = serviceDoc.data().defaultDurationMins;
  const bufferMins = doctor.breakMinutes || 0;

  const windows = await effectiveScheduleWindows({ doctor, branch, dateStr: date });
  if (windows.length === 0) return [];

  const apptSnap = await db
    .collection('appointments')
    .where('doctorId', '==', doctorId)
    .where('date', '==', date)
    .where('status', 'in', ACTIVE_STATUSES)
    .get();
  const booked = apptSnap.docs.map((d) => d.data());
  const blocked = (doctor.blockedSlots || []).filter((b) => b.date === date);

  const slots = [];
  for (const w of windows) {
    const windowEndMin = toMinutes(w.endTime);
    for (let cursor = toMinutes(w.startTime); cursor + durationMins <= windowEndMin; cursor += w.slotDurationMins) {
      const startTime = fromMinutes(cursor);
      const endTime = fromMinutes(cursor + durationMins);
      if (isPastInKigali(date, startTime)) continue;
      const taken =
        booked.some((b) => overlapsWithBuffer(startTime, endTime, b.startTime, b.endTime, bufferMins)) ||
        blocked.some((b) => overlapsWithBuffer(startTime, endTime, b.startTime, b.endTime, bufferMins));
      if (!taken) slots.push({ startTime, endTime });
    }
  }
  return slots;
}

async function getRawById(id) {
  const doc = await db.collection('appointments').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

// Part 21 — a patient's scope carries no clinicId to compare against (see
// branchScope.middleware.js's 'patient' level); the controller already ran
// the real check for a patient caller (assertPatientOwnsAppointment, keyed
// on the appointment's patientId, not clinic/branch) before ever calling
// into setStatus()/reschedule() below, so this guard simply steps aside for
// that scope the same way it already does for 'platform'.
function assertAccess(appt, scope) {
  if (scope.level === 'platform' || scope.level === 'patient') return;
  if (appt.clinicId !== scope.clinicId) {
    throw httpError(403, 'This appointment belongs to a different clinic');
  }
  if (scope.level === 'branch' && appt.branchId !== scope.branchId) {
    throw httpError(403, 'This appointment belongs to a different branch');
  }
}

/**
 * The ONE shared booking endpoint (Part 11 Task 5 — "keep this as the one
 * true booking path even though only staff call it for now, so a future
 * Patient App can reuse it unchanged"). Double-booking prevention (Task 2,
 * CRITICAL): re-checks for a conflicting appointment INSIDE a Firestore
 * transaction, immediately before writing — the read and the write are
 * atomic, so two near-simultaneous calls for the same slot can't both
 * succeed. If the query's result would change (a conflicting appointment
 * committed by a concurrent transaction), Firestore aborts and retries this
 * transaction, so the retry sees the fresh conflict and rejects cleanly.
 * Re-applies the doctor's `breakMinutes` buffer here too (not just in
 * `getAvailableSlots`), for the same never-trust-a-client-fetched-list
 * reason: two near-simultaneous bookings could each look buffer-valid
 * against the slot list they fetched moments earlier. Same reasoning for
 * the past-time check (2026-07-26) — reject here too, not just filter it
 * out of the slot list.
 */
async function book({ clinicId, branchId, patientId, doctorId, serviceId, date, startTime, endTime }, actor) {
  if (isPastInKigali(date, startTime)) {
    throw httpError(400, 'That time has already passed — please pick another.');
  }

  const apptRef = db.collection('appointments').doc();
  const doctorDoc = await db.collection('doctors').doc(doctorId).get();
  const bufferMins = doctorDoc.data()?.breakMinutes || 0;

  await db.runTransaction(async (tx) => {
    const conflictSnap = await tx.get(
      db
        .collection('appointments')
        .where('doctorId', '==', doctorId)
        .where('date', '==', date)
        .where('status', 'in', ACTIVE_STATUSES)
    );
    const conflict = conflictSnap.docs.some((doc) => {
      const d = doc.data();
      return overlapsWithBuffer(startTime, endTime, d.startTime, d.endTime, bufferMins);
    });
    if (conflict) {
      throw httpError(409, 'That slot was just taken — please pick another.');
    }

    tx.set(apptRef, {
      clinicId,
      branchId,
      patientId,
      doctorId,
      serviceId,
      date,
      startTime,
      endTime,
      status: 'pending',
      queueNumber: null,
      createdBy: actor.actorId || null,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  });

  const booked = await getRawById(apptRef.id);

  // Part 14 Task 1 — "New booking alert to receptionist/doctor". Best-effort,
  // same non-blocking try/catch hook pattern as Part 12's invoice
  // auto-generation below: a notification failure must never fail a booking.
  try {
    await notificationsService.notifyNewBooking(booked, actor);
  } catch (err) {
    console.warn(`[appointments] notifyNewBooking failed for ${apptRef.id}: ${err.message}`);
  }

  return booked;
}

/**
 * Confirm/Cancel/Check-In/Mark-Complete — one state machine (spec 6.7:
 * "every status change logged with timestamp"; "cannot be marked completed
 * until check-in has occurred" — enforced structurally by
 * VALID_TRANSITIONS, not a bolted-on special case). Check-in additionally
 * assigns the day's next queueNumber for the branch, atomically (Part 11
 * Task 4).
 */
async function setStatus(id, newStatus, actor) {
  const appt = await getRawById(id);
  if (!appt) throw httpError(404, 'Appointment not found');
  assertAccess(appt, actor.scope);

  const allowed = VALID_TRANSITIONS[appt.status] || [];
  if (!allowed.includes(newStatus)) {
    throw httpError(400, `Cannot move from "${appt.status}" to "${newStatus}"`);
  }

  if (newStatus === 'checkedIn') {
    const counterId = `${appt.branchId}_${appt.date}`;
    const counterRef = db.collection('queueCounters').doc(counterId);
    const apptRef = db.collection('appointments').doc(id);
    await db.runTransaction(async (tx) => {
      const counterDoc = await tx.get(counterRef);
      const next = (counterDoc.exists ? counterDoc.data().lastNumber : 0) + 1;
      tx.set(counterRef, { lastNumber: next, branchId: appt.branchId, date: appt.date }, { merge: true });
      tx.update(apptRef, {
        status: newStatus,
        queueNumber: next,
        updatedAt: new Date().toISOString(),
      });
    });
  } else {
    await db.collection('appointments').doc(id).update({
      status: newStatus,
      updatedAt: new Date().toISOString(),
    });
  }

  const updated = await getRawById(id);

  // Part 12 Task 1 — auto-generate an invoice the moment an appointment is
  // marked completed, pre-filled from the service's defaultPriceRwf.
  // Best-effort: a billing hiccup must never block staff from recording
  // that a visit actually happened, so a failure here is logged, not
  // thrown. createFromAppointment() is idempotent (keyed on appointmentId),
  // so this is always safe to attempt even if it somehow ran twice.
  if (newStatus === 'completed') {
    try {
      const invoice = await invoicesService.createFromAppointment(updated, actor);
      updated.invoiceId = invoice.id;
    } catch (err) {
      console.error(`[appointments] auto-invoice generation failed for appointment ${id}:`, err);
    }
  }

  // Part 21 Task 4 — clinic-side alert on cancellation, fired the same way
  // regardless of whether staff or a patient triggered it (see
  // notifications.service.js#notifyCancellation). Same best-effort
  // try/catch as notifyNewBooking above — a notification failure must never
  // block the cancellation itself from taking effect.
  if (newStatus === 'cancelled') {
    try {
      await notificationsService.notifyCancellation(updated, actor);
    } catch (err) {
      console.warn(`[appointments] notifyCancellation failed for ${id}: ${err.message}`);
    }
  }

  return updated;
}

/**
 * Re-validates CURRENT availability (spec 6.7) — same transactional
 * conflict re-check as book(), excluding the appointment being moved from
 * its own conflict set. Status is left untouched; only date/time change.
 */
async function reschedule(id, { date, startTime, endTime }, actor) {
  const appt = await getRawById(id);
  if (!appt) throw httpError(404, 'Appointment not found');
  assertAccess(appt, actor.scope);
  if (['completed', 'cancelled'].includes(appt.status)) {
    throw httpError(400, `Cannot reschedule a ${appt.status} appointment`);
  }
  if (isPastInKigali(date, startTime)) {
    throw httpError(400, 'That time has already passed — please pick another.');
  }

  const doctorDoc = await db.collection('doctors').doc(appt.doctorId).get();
  const bufferMins = doctorDoc.data()?.breakMinutes || 0;

  const apptRef = db.collection('appointments').doc(id);
  await db.runTransaction(async (tx) => {
    const conflictSnap = await tx.get(
      db
        .collection('appointments')
        .where('doctorId', '==', appt.doctorId)
        .where('date', '==', date)
        .where('status', 'in', ACTIVE_STATUSES)
    );
    const conflict = conflictSnap.docs.some((doc) => {
      if (doc.id === id) return false;
      const d = doc.data();
      return overlapsWithBuffer(startTime, endTime, d.startTime, d.endTime, bufferMins);
    });
    if (conflict) {
      throw httpError(409, 'That slot is no longer available — please pick another.');
    }

    tx.update(apptRef, { date, startTime, endTime, updatedAt: new Date().toISOString() });
  });

  const updated = await getRawById(id);

  // Part 21 Task 4 — same clinic-side alert pattern as cancellation above.
  try {
    await notificationsService.notifyReschedule(updated, actor);
  } catch (err) {
    console.warn(`[appointments] notifyReschedule failed for ${id}: ${err.message}`);
  }

  return updated;
}

async function list({ clinicId, branchId, doctorId, patientId, tab }) {
  let query = db.collection('appointments').where('clinicId', '==', clinicId);
  if (branchId) query = query.where('branchId', '==', branchId);
  if (doctorId) query = query.where('doctorId', '==', doctorId);
  if (patientId) query = query.where('patientId', '==', patientId);

  const snap = await query.get();
  const appts = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  if (!tab) return appts;
  const today = kigaliDateString();
  switch (tab) {
    case 'today':
      return appts.filter((a) => a.date === today);
    case 'upcoming':
      return appts.filter((a) => a.date > today || (a.date === today && !['completed', 'cancelled'].includes(a.status)));
    case 'history':
      return appts.filter((a) => a.date < today || ['completed', 'cancelled'].includes(a.status));
    default:
      return appts;
  }
}

/**
 * "Now Serving #N" (Part 11 Task 4) — the checked-in appointment with the
 * smallest queueNumber today is the front of the line; the highest
 * completed number is what was "just called" for context.
 */
async function getQueueDisplay(branchId, date) {
  const snap = await db
    .collection('appointments')
    .where('branchId', '==', branchId)
    .where('date', '==', date)
    .where('status', 'in', ['checkedIn', 'completed'])
    .get();

  const waiting = snap.docs
    .map((doc) => doc.data())
    .filter((a) => a.status === 'checkedIn' && a.queueNumber != null)
    .sort((a, b) => a.queueNumber - b.queueNumber);
  const completedNumbers = snap.docs
    .map((doc) => doc.data())
    .filter((a) => a.status === 'completed' && a.queueNumber != null)
    .map((a) => a.queueNumber);

  return {
    nowServingNumber: waiting[0]?.queueNumber ?? null,
    waitingCount: waiting.length,
    lastCompletedNumber: completedNumbers.length > 0 ? Math.max(...completedNumbers) : null,
  };
}

const REMINDER_STATUSES = ['confirmed', 'checkedIn'];
const REMINDER_WINDOWS_MS = {
  twentyFourHour: 24 * 60 * 60 * 1000,
  twoHour: 2 * 60 * 60 * 1000,
};

async function fetchNameSafe(collection, id) {
  if (!id) return null;
  const doc = await db.collection(collection).doc(id).get();
  return doc.exists ? doc.data().name || null : null;
}

/**
 * Part 22 Task 3 — the hourly reminder job's actual work (registered via
 * jobs/appointmentReminders.job.js). For every confirmed/checkedIn
 * appointment starting within the next 24h or 2h, sends (at most) one
 * reminder per threshold, tracked on the appointment's own `sentReminders`
 * map so a later run of this same hourly job never double-sends — the
 * DONE CONDITION this whole function exists to satisfy. `pending`
 * appointments are deliberately excluded (spec: nothing to remind about
 * until staff have actually confirmed it).
 */
async function sendDueReminders(now = new Date()) {
  const nowMs = now.getTime();
  const snap = await db.collection('appointments').where('status', 'in', REMINDER_STATUSES).get();

  let sent = 0;
  for (const doc of snap.docs) {
    const appt = { id: doc.id, ...doc.data() };
    const apptMs = kigaliDateTimeToUtcMs(appt.date, appt.startTime);
    if (apptMs <= nowMs) continue; // already started/passed — nothing to remind about

    const existing = appt.sentReminders || { twentyFourHour: false, twoHour: false };
    const due = Object.keys(REMINDER_WINDOWS_MS).filter(
      (threshold) => !existing[threshold] && apptMs - nowMs <= REMINDER_WINDOWS_MS[threshold]
    );
    if (due.length === 0) continue;

    const [doctorName, clinicName] = await Promise.all([
      fetchNameSafe('users', appt.doctorId),
      fetchNameSafe('branches', appt.branchId),
    ]);

    const updatedSentReminders = { ...existing };
    for (const threshold of due) {
      try {
        await notificationsService.notifyAppointmentReminder(appt, { threshold, doctorName, clinicName });
      } catch (err) {
        console.warn(`[appointments] notifyAppointmentReminder(${threshold}) failed for ${appt.id}: ${err.message}`);
      }
      updatedSentReminders[threshold] = true;
      sent++;
    }
    await db.collection('appointments').doc(appt.id).update({ sentReminders: updatedSentReminders });
  }

  return { sent };
}

module.exports = {
  getAvailableSlots,
  book,
  setStatus,
  reschedule,
  list,
  getById: getRawById,
  getQueueDisplay,
  sendDueReminders,
  ACTIVE_STATUSES,
  VALID_TRANSITIONS,
};
