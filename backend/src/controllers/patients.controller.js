// Controller for /api/v1/patients — spec section 6.5A / 6.6 / 6.6A / 9 (Part 9).
const patientsService = require('../services/patients.service');

function resolveClinicId(req, explicit) {
  return req.scope.level === 'platform' ? explicit : req.scope.clinicId;
}

function resolveBranchId(req, explicit) {
  return req.scope.level === 'branch' ? req.scope.branchId : explicit;
}

function actorFrom(req) {
  return { actorId: req.user?.uid, role: req.user?.role, actorRole: req.user?.role, scope: req.scope };
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
    const url = await patientsService.getDocumentSignedUrl(
      req.params.patientId,
      req.params.key,
      actorFrom(req)
    );
    res.json({ url });
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
};
