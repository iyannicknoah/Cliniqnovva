// Controller for /api/v1/appointments — spec section 6.7 / 9 (Part 11).
// Part 21 — Patient App booking/reschedule/cancel: reuses this exact
// controller/service, no separate patient booking path. The double-booking
// transaction in appointments.service.js is UNTOUCHED; every Part 21 change
// below lives here, in the request-shaping layer, not the transaction.
const appointmentsService = require('../services/appointments.service');
const patientsService = require('../services/patients.service');
const { ROLES } = require('../middleware/requireRole');

// A patient's scope carries no clinicId (branchScope.middleware.js's
// 'patient' level — patients aren't tied to one clinic), so — like Super
// Admin's 'platform' level — the client-supplied value must be trusted here
// instead of being silently discarded to `undefined`.
function resolveClinicId(req, explicit) {
  return ['platform', 'patient'].includes(req.scope.level) ? explicit : req.scope.clinicId;
}

function resolveBranchId(req, explicit) {
  return req.scope.level === 'branch' ? req.scope.branchId : explicit;
}

function actorFrom(req) {
  return { actorId: req.user?.uid, role: req.user?.role, actorRole: req.user?.role, scope: req.scope };
}

/**
 * Ownership check for a Patient App caller (Part 21) — an appointment's
 * `patientId` is a /patients walk-in-record id, not the caller's own uid
 * (see patients.service.js), so "is this my appointment" means "is this
 * /patients record linked to my account", not a direct id comparison.
 */
async function assertPatientOwnsAppointment(appt, uid) {
  const owns = await patientsService.isPatientRecordOwnedBy(appt.patientId, uid);
  if (!owns) {
    const err = new Error('You can only manage your own appointments');
    err.status = 403;
    throw err;
  }
}

async function getAvailableSlots(req, res, next) {
  try {
    const { doctorId, branchId, serviceId, date } = req.query;
    if (!doctorId || !branchId || !serviceId || !date) {
      return res.status(400).json({ error: 'doctorId, branchId, serviceId, and date are required' });
    }
    const slots = await appointmentsService.getAvailableSlots({ doctorId, branchId, serviceId, date });
    res.json({ slots });
  } catch (err) {
    next(err);
  }
}

async function book(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.body.clinicId);
    const branchId = resolveBranchId(req, req.body.branchId);
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    if (!branchId) return res.status(400).json({ error: 'branchId is required' });

    const { doctorId, serviceId, date, startTime, endTime } = req.body;
    if (!doctorId || !serviceId || !date || !startTime || !endTime) {
      return res.status(400).json({ error: 'doctorId, serviceId, date, startTime, and endTime are required' });
    }

    // A patient caller NEVER supplies patientId directly (Part 21) — it's
    // resolved server-side from their own account, so nothing they send in
    // the request body can book an appointment under someone else's
    // /patients record. Staff (Receptionist etc.) still pass patientId
    // explicitly, unchanged.
    let patientId;
    if (req.user?.role === ROLES.PATIENT) {
      const record = await patientsService.getOrCreatePatientRecordForClinic({
        uid: req.user.uid,
        clinicId,
        branchId,
      });
      patientId = record.id;
    } else {
      patientId = req.body.patientId;
      if (!patientId) return res.status(400).json({ error: 'patientId is required' });
    }

    const appointment = await appointmentsService.book(
      { clinicId, branchId, patientId, doctorId, serviceId, date, startTime, endTime },
      actorFrom(req)
    );
    res.status(201).json({ appointment });
  } catch (err) {
    next(err);
  }
}

// A Doctor may only move their own appointment to 'completed' (spec 6.7:
// "Doctor: view own, mark complete") — never confirm/cancel/check-in, and
// never someone else's. Every other allowed role can drive the full state
// machine; the service layer still enforces which transitions are legal.
async function setStatus(req, res, next) {
  try {
    const { status } = req.body;
    if (!status) return res.status(400).json({ error: 'status is required' });

    if (req.user?.role === ROLES.DOCTOR) {
      if (status !== 'completed') {
        return res.status(403).json({ error: 'Doctors can only mark an appointment complete' });
      }
      const existing = await appointmentsService.getById(req.params.id);
      if (existing?.doctorId !== req.user.uid) {
        return res.status(403).json({ error: 'You can only update your own appointments' });
      }
    }

    // A patient (Part 21, Task 3) can only ever cancel — confirm/check-in/
    // complete stay staff/doctor-only actions — and only their own
    // appointment. appointments.service.js's own VALID_TRANSITIONS still
    // rejects cancelling an already-completed/cancelled appointment; this
    // is strictly an extra caller-identity restriction on top of that.
    if (req.user?.role === ROLES.PATIENT) {
      if (status !== 'cancelled') {
        return res.status(403).json({ error: 'You can only cancel an appointment, not change its status' });
      }
      const existing = await appointmentsService.getById(req.params.id);
      if (!existing) return res.status(404).json({ error: 'Appointment not found' });
      await assertPatientOwnsAppointment(existing, req.user.uid);
    }

    const appointment = await appointmentsService.setStatus(req.params.id, status, actorFrom(req));
    res.json({ appointment });
  } catch (err) {
    next(err);
  }
}

async function reschedule(req, res, next) {
  try {
    const { date, startTime, endTime } = req.body;
    if (!date || !startTime || !endTime) {
      return res.status(400).json({ error: 'date, startTime, and endTime are required' });
    }

    if (req.user?.role === ROLES.PATIENT) {
      const existing = await appointmentsService.getById(req.params.id);
      if (!existing) return res.status(404).json({ error: 'Appointment not found' });
      await assertPatientOwnsAppointment(existing, req.user.uid);
    }

    const appointment = await appointmentsService.reschedule(
      req.params.id,
      { date, startTime, endTime },
      actorFrom(req)
    );
    res.json({ appointment });
  } catch (err) {
    next(err);
  }
}

async function list(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.query.clinicId);
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    const branchId = resolveBranchId(req, req.query.branchId);

    // A Doctor only ever sees their own appointments (spec 6.7: "view own").
    const doctorId = req.user?.role === ROLES.DOCTOR ? req.user.uid : req.query.doctorId;

    const appointments = await appointmentsService.list({
      clinicId,
      branchId,
      doctorId,
      patientId: req.query.patientId,
      tab: req.query.tab,
    });
    res.json({ appointments });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const appointment = await appointmentsService.getById(req.params.id);
    if (!appointment) return res.status(404).json({ error: 'Appointment not found' });

    if (req.user?.role === ROLES.PATIENT) {
      // A patient's scope has no clinicId to compare against (unlike every
      // other role) — ownership is the only check that applies to them.
      await assertPatientOwnsAppointment(appointment, req.user.uid);
    } else if (req.scope.level !== 'platform' && appointment.clinicId !== req.scope.clinicId) {
      return res.status(403).json({ error: 'This appointment belongs to a different clinic' });
    }
    if (req.user?.role === ROLES.DOCTOR && appointment.doctorId !== req.user.uid) {
      return res.status(403).json({ error: 'You can only view your own appointments' });
    }
    res.json({ appointment });
  } catch (err) {
    next(err);
  }
}

async function getQueueDisplay(req, res, next) {
  try {
    const branchId = resolveBranchId(req, req.query.branchId);
    if (!branchId) return res.status(400).json({ error: 'branchId is required' });
    const date = req.query.date;
    if (!date) return res.status(400).json({ error: 'date is required' });

    const queue = await appointmentsService.getQueueDisplay(branchId, date);
    res.json({ queue });
  } catch (err) {
    next(err);
  }
}

module.exports = { getAvailableSlots, book, setStatus, reschedule, list, getById, getQueueDisplay };
