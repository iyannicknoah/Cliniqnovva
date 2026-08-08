// Controller for /api/v1/doctors — Part 20. Read side is now real (patient-
// safe, cross-clinic); write side stays a stub — doctor accounts are
// created/edited through /api/v1/staff (staff.controller.js), not here.
const doctorsService = require('../services/doctors.service');

async function list(req, res, next) {
  try {
    // Branch-scoped staff callers (branch_admin/receptionist/doctor) get
    // their own branch for free from req.scope; a patient has no scope
    // branchId (see branchScope.middleware.js's 'patient' level), so must
    // supply one explicitly — this is the cross-clinic Browse case.
    const branchId = req.scope.level === 'branch' ? req.scope.branchId : req.query.branchId;
    const doctors = await doctorsService.list({ branchId });
    res.json({ doctors });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const doctor = await doctorsService.getById(req.params.id);
    if (!doctor) return res.status(404).json({ error: 'Doctor not found' });
    res.json({ doctor });
  } catch (err) {
    next(err);
  }
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented: create a doctor via POST /api/v1/staff instead' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented: edit a doctor via PATCH /api/v1/staff/:id instead' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented: doctors are deactivated via /api/v1/staff, never deleted' });
}

module.exports = { list, getById, create, update, remove };
