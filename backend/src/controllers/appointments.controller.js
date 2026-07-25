// Controller for /api/v1/appointments — spec section 6.7 / 9 (Part 11).
const appointmentsService = require('../services/appointments.service');
const { ROLES } = require('../middleware/requireRole');

function resolveClinicId(req, explicit) {
  return req.scope.level === 'platform' ? explicit : req.scope.clinicId;
}

function resolveBranchId(req, explicit) {
  return req.scope.level === 'branch' ? req.scope.branchId : explicit;
}

function actorFrom(req) {
  return { actorId: req.user?.uid, role: req.user?.role, actorRole: req.user?.role, scope: req.scope };
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

    const { patientId, doctorId, serviceId, date, startTime, endTime } = req.body;
    if (!patientId || !doctorId || !serviceId || !date || !startTime || !endTime) {
      return res.status(400).json({ error: 'patientId, doctorId, serviceId, date, startTime, and endTime are required' });
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
    if (req.scope.level !== 'platform' && appointment.clinicId !== req.scope.clinicId) {
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
