// Controller for /api/v1/patients — spec section 6.5A / 6.6 / 6.6A / 9 (Part 9).
const patientsService = require('../services/patients.service');

function resolveOrganizationId(req, explicit) {
  return req.scope.level === 'platform' ? explicit : req.scope.organizationId;
}

function resolveBranchId(req, explicit) {
  return req.scope.level === 'branch' ? req.scope.branchId : explicit;
}

function actorFrom(req) {
  return { actorId: req.user?.uid, role: req.user?.role, actorRole: req.user?.role, scope: req.scope };
}

async function checkDuplicate(req, res, next) {
  try {
    const organizationId = resolveOrganizationId(req, req.query.organizationId);
    if (!organizationId) return res.status(400).json({ error: 'organizationId is required' });
    const matches = await patientsService.checkDuplicate({
      organizationId,
      phone: req.query.phone,
      nationalId: req.query.nationalId,
    });
    res.json({ matches });
  } catch (err) {
    next(err);
  }
}

// GET /api/patients/:organizationId — search, per the Part 9 Task 4 route
// shape. Scoped users ignore the path param and use their own organization;
// only Super Admin's explicit value is trusted.
async function search(req, res, next) {
  try {
    const organizationId = resolveOrganizationId(req, req.params.organizationId);
    const branchId = resolveBranchId(req, req.query.branchId);
    const patients = await patientsService.search({ organizationId, branchId, q: req.query.q });
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

async function create(req, res, next) {
  try {
    const organizationId = resolveOrganizationId(req, req.body.organizationId);
    const branchId = resolveBranchId(req, req.body.branchId);
    if (!organizationId) return res.status(400).json({ error: 'organizationId is required' });
    if (!branchId) return res.status(400).json({ error: 'branchId is required' });

    const patient = await patientsService.create(
      {
        organizationId,
        branchId,
        name: req.body.name,
        phone: req.body.phone,
        dateOfBirth: req.body.dateOfBirth,
        gender: req.body.gender,
        nationalId: req.body.nationalId,
        emergencyContact: req.body.emergencyContact,
        location: req.body.location,
      },
      actorFrom(req)
    );
    res.status(201).json({ patient });
  } catch (err) {
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
  remove,
};
