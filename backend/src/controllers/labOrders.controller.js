// Controller for /api/v1/labOrders (2026-07-29). Keep thin: parse/validate
// req, call labOrders.service.js, shape the response.
const labOrdersService = require('../services/labOrders.service');

function resolveClinicId(req, explicit) {
  return req.scope.level === 'platform' ? explicit : req.scope.clinicId;
}

function resolveBranchId(req, explicit) {
  return req.scope.level === 'branch' ? req.scope.branchId : explicit;
}

function actorFrom(req) {
  return { actorId: req.user?.uid, role: req.user?.role, actorRole: req.user?.role, scope: req.scope };
}

async function list(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.query.clinicId);
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    const branchId = resolveBranchId(req, req.query.branchId);

    const orders = await labOrdersService.list({
      clinicId,
      branchId,
      status: req.query.status,
      patientId: req.query.patientId,
    });
    res.json({ orders });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const order = await labOrdersService.getById(req.params.id, actorFrom(req));
    if (!order) return res.status(404).json({ error: 'Lab order not found' });
    res.json({ order });
  } catch (err) {
    next(err);
  }
}

async function create(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.body.clinicId);
    const branchId = resolveBranchId(req, req.body.branchId);

    const order = await labOrdersService.create(
      {
        clinicId,
        branchId,
        patientId: req.body.patientId,
        appointmentId: req.body.appointmentId,
        medicalRecordId: req.body.medicalRecordId,
        testName: req.body.testName,
        testCategory: req.body.testCategory,
        priceRwf: req.body.priceRwf,
      },
      actorFrom(req)
    );
    res.status(201).json({ order });
  } catch (err) {
    next(err);
  }
}

async function markCollected(req, res, next) {
  try {
    const order = await labOrdersService.markCollected(req.params.id, actorFrom(req));
    res.json({ order });
  } catch (err) {
    next(err);
  }
}

async function recordResult(req, res, next) {
  try {
    const order = await labOrdersService.recordResult(
      req.params.id,
      {
        resultValue: req.body.resultValue,
        resultUnit: req.body.resultUnit,
        resultNotes: req.body.resultNotes,
      },
      actorFrom(req)
    );
    res.json({ order });
  } catch (err) {
    next(err);
  }
}

async function markReviewed(req, res, next) {
  try {
    const order = await labOrdersService.markReviewed(req.params.id, actorFrom(req));
    res.json({ order });
  } catch (err) {
    next(err);
  }
}

module.exports = { list, getById, create, markCollected, recordResult, markReviewed };
