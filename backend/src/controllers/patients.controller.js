// Controller for /api/v1/patients — spec section 6.5A / 6.6 / 6.6A / 9 (Part 9).
const patientsService = require('../services/patients.service');
const appointmentsService = require('../services/appointments.service');
const invoicesService = require('../services/invoices.service');
const reviewsService = require('../services/reviews.service');
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

/**
 * POST /resolve-for-clinic — Part 25. The Patient App's chat feature
 * writes /chats docs directly to Firestore (see firestore.rules), but a
 * chat's `patientId` field must be the caller's walk-in /patients record
 * id for that clinic (same convention appointments/reviews/invoices/
 * medical-records already use) — this is the one step that still needs
 * the backend first, reusing the exact same
 * getOrCreatePatientRecordForClinic() the booking flow already calls.
 */
async function resolveForClinic(req, res, next) {
  try {
    const { clinicId, branchId } = req.body;
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    const record = await patientsService.getOrCreatePatientRecordForClinic({
      uid: req.user.uid,
      clinicId,
      branchId,
    });
    res.json({ patientId: record.id });
  } catch (err) {
    next(err);
  }
}

// Part 10 Task 3 — POST (was GET in Part 9; the request now carries the
// same shape POST /api/patients itself checks against, so this stays a
// reusable pre-flight the client can call any time, e.g. before opening
// the merge tool's search).
async function checkDuplicate(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.body.clinicId);
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    const matches = await patientsService.checkDuplicate({
      clinicId,
      phone: req.body.phone,
      nationalId: req.body.nationalId,
    });
    res.json({ matches });
  } catch (err) {
    next(err);
  }
}

// GET /api/patients/:clinicId — search, per the Part 9 Task 4 route
// shape. Scoped users ignore the path param and use their own clinic;
// only Super Admin's explicit value is trusted.
async function search(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.params.clinicId);
    const branchId = resolveBranchId(req, req.query.branchId);
    const patients = await patientsService.search({ clinicId, branchId, q: req.query.q });
    res.json({ patients });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const patient = await patientsService.getById(req.params.patientId, actorFrom(req));
    if (!patient) return res.status(404).json({ error: 'Patient not found' });
    res.json({ patient });
  } catch (err) {
    next(err);
  }
}

// Part 10 Task 1 — a possible-duplicate hit is a distinguishable response
// shape ({possibleDuplicate: true, matches}), not the generic error
// envelope, so it's handled here rather than falling through to next(err).
async function create(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.body.clinicId);
    const branchId = resolveBranchId(req, req.body.branchId);
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    if (!branchId) return res.status(400).json({ error: 'branchId is required' });

    const patient = await patientsService.create(
      {
        clinicId,
        branchId,
        name: req.body.name,
        phone: req.body.phone,
        dateOfBirth: req.body.dateOfBirth,
        gender: req.body.gender,
        nationalId: req.body.nationalId,
        emergencyContact: req.body.emergencyContact,
        location: req.body.location,
        confirmedDuplicate: req.body.confirmedDuplicate === true,
      },
      actorFrom(req)
    );
    res.status(201).json({ patient });
  } catch (err) {
    if (err.possibleDuplicate) {
      return res.status(409).json({ possibleDuplicate: true, matches: err.matches });
    }
    next(err);
  }
}

async function update(req, res, next) {
  try {
    const patient = await patientsService.update(req.params.patientId, req.body, actorFrom(req));
    res.json({ patient });
  } catch (err) {
    next(err);
  }
}

async function addMedicalRecord(req, res, next) {
  try {
    const record = await patientsService.addMedicalRecord(
      req.params.patientId,
      {
        appointmentId: req.body.appointmentId,
        diagnosis: req.body.diagnosis,
        prescriptions: req.body.prescriptions,
        notes: req.body.notes,
        vitals: req.body.vitals,
      },
      actorFrom(req)
    );
    res.status(201).json({ record });
  } catch (err) {
    next(err);
  }
}

async function addDocument(req, res, next) {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file provided (field name must be "file")' });
    const document = await patientsService.addDocument(
      req.params.patientId,
      {
        buffer: req.file.buffer,
        originalName: req.file.originalname,
        contentType: req.file.mimetype,
      },
      actorFrom(req)
    );
    res.status(201).json({ document });
  } catch (err) {
    next(err);
  }
}

// req.params.key arrives already decoded by Express (the client must
// encodeURIComponent() the key — which contains slashes — into a single
// path segment; %2F round-trips correctly through Express's router).
async function getDocumentSignedUrl(req, res, next) {
  try {
    const result = await patientsService.getDocumentSignedUrl(
      req.params.patientId,
      req.params.key,
      actorFrom(req)
    );
    res.json(result);
  } catch (err) {
    next(err);
  }
}

// Part 10 Task 3 — POST /api/patients/merge (branch_admin/clinic_admin
// only, enforced by the route's requireRole).
async function merge(req, res, next) {
  try {
    const { survivingPatientId, mergedPatientId } = req.body;
    const result = await patientsService.mergePatients(
      { survivingPatientId, mergedPatientId },
      actorFrom(req)
    );
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented: patients are never hard-deleted' });
}

/**
 * GET /:patientId/appointments — Part 22 Task 4, backs the Patient App's My
 * Bookings screen. `:patientId` is one /patients walk-in-record id, NOT a
 * patient's own uid (see patients.service.js's module docstring) — a
 * patient with appointments at several clinics has one linked patientId per
 * clinic, so the app calls this once per linked id and merges the results
 * client-side, rather than this endpoint trying to be cross-clinic itself
 * (appointmentsService.list() is deliberately single-clinic, same as every
 * other staff-facing appointments read).
 */
async function getAppointments(req, res, next) {
  try {
    const patient = await patientsService.getRawById(req.params.patientId);
    if (!patient) return res.status(404).json({ error: 'Patient not found' });

    if (req.user?.role === ROLES.PATIENT) {
      const owns = await patientsService.isPatientRecordOwnedBy(patient.id, req.user.uid);
      if (!owns) return res.status(403).json({ error: 'You can only view your own appointments' });
    } else {
      if (req.scope.level !== 'platform' && patient.clinicId !== req.scope.clinicId) {
        return res.status(403).json({ error: 'This patient belongs to a different clinic' });
      }
      if (req.scope.level === 'branch' && patient.branchId !== req.scope.branchId) {
        return res.status(403).json({ error: 'This patient belongs to a different branch' });
      }
    }

    const appointments = await appointmentsService.list({
      clinicId: patient.clinicId,
      patientId: patient.id,
      tab: req.query.tab,
    });
    res.json({ appointments });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /:patientId/medical-records — Part 23 Task 3. Patient-only (unlike
 * getAppointments above, staff already have a full path to this same data
 * via GET /detail/:patientId's role-shaped getById) — the DONE CONDITION
 * ("only ever retrieve their OWN medical records... enforced server-side")
 * is `patientsService.getMedicalRecordsAndDocumentsForPatient`'s ownership
 * check, not a route-level role restriction alone.
 */
async function getMedicalRecords(req, res, next) {
  try {
    const result = await patientsService.getMedicalRecordsAndDocumentsForPatient(req.params.patientId, req.user.uid);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

/** GET /:patientId/invoices — Part 23 Task 3, the Receipts screen. Same ownership-not-role gate as getMedicalRecords. */
async function getInvoices(req, res, next) {
  try {
    const patient = await patientsService.getRawById(req.params.patientId);
    if (!patient) return res.status(404).json({ error: 'Patient not found' });

    const owns = await patientsService.isPatientRecordOwnedBy(patient.id, req.user.uid);
    if (!owns) return res.status(403).json({ error: 'You can only view your own invoices' });

    const invoices = await invoicesService.listForPatient(patient.id);
    res.json({ invoices });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /:patientId/reviews — Part 24, the Patient App's My Reviews screen.
 * Same single-clinic-per-call, ownership-not-role gate as
 * getAppointments/getMedicalRecords/getInvoices — the app fans this out
 * across every linked record client-side.
 */
async function getReviews(req, res, next) {
  try {
    const patient = await patientsService.getRawById(req.params.patientId);
    if (!patient) return res.status(404).json({ error: 'Patient not found' });

    const owns = await patientsService.isPatientRecordOwnedBy(patient.id, req.user.uid);
    if (!owns) return res.status(403).json({ error: 'You can only view your own reviews' });

    const reviews = await reviewsService.list({ clinicId: patient.clinicId, patientId: patient.id });
    res.json({ reviews });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  checkDuplicate,
  search,
  getById,
  create,
  update,
  addMedicalRecord,
  addDocument,
  getDocumentSignedUrl,
  merge,
  remove,
  getAppointments,
  getMedicalRecords,
  getInvoices,
  getReviews,
  resolveForClinic,
};
