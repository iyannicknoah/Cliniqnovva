// Controller for /api/v1/inventory — spec section 6.9 / 9 (Part 13).
const inventoryService = require('../services/inventory.service');

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

    const items = await inventoryService.list({ clinicId, branchId, q: req.query.q });
    res.json({ items });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const item = await inventoryService.getById(req.params.id, actorFrom(req));
    if (!item) return res.status(404).json({ error: 'Item not found' });
    res.json({ item });
  } catch (err) {
    next(err);
  }
}

async function create(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.body.clinicId);
    const branchId = resolveBranchId(req, req.body.branchId);

    const item = await inventoryService.create(
      {
        clinicId,
        branchId,
        name: req.body.name,
        unit: req.body.unit,
        category: req.body.category,
        quantity: req.body.quantity,
        reorderLevel: req.body.reorderLevel,
        expiryDate: req.body.expiryDate,
      },
      actorFrom(req)
    );
    res.status(201).json({ item });
  } catch (err) {
    next(err);
  }
}

async function update(req, res, next) {
  try {
    const item = await inventoryService.update(req.params.id, req.body, actorFrom(req));
    res.json({ item });
  } catch (err) {
    next(err);
  }
}

async function setActive(req, res, next) {
  try {
    const item = await inventoryService.setActive(req.params.id, !!req.body.isActive, actorFrom(req));
    res.json({ item });
  } catch (err) {
    next(err);
  }
}

async function adjust(req, res, next) {
  try {
    const item = await inventoryService.adjust(
      req.params.id,
      { quantityChange: req.body.quantityChange, reason: req.body.reason },
      actorFrom(req)
    );
    res.json({ item });
  } catch (err) {
    next(err);
  }
}

async function dispense(req, res, next) {
  try {
    const item = await inventoryService.dispense(
      {
        itemId: req.body.itemId,
        quantity: req.body.quantity,
        patientId: req.body.patientId,
        medicalRecordId: req.body.medicalRecordId,
        prescriptionIndex: req.body.prescriptionIndex,
        reason: req.body.reason,
      },
      actorFrom(req)
    );
    res.json({ item });
  } catch (err) {
    next(err);
  }
}

async function listAdjustments(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.query.clinicId);
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    const branchId = resolveBranchId(req, req.query.branchId);

    const adjustments = await inventoryService.listAdjustments({
      clinicId,
      branchId,
      itemId: req.query.itemId,
    });
    res.json({ adjustments });
  } catch (err) {
    next(err);
  }
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented: items are deactivated (PATCH /:id/status), never deleted' });
}

module.exports = { list, getById, create, update, setActive, adjust, dispense, listAdjustments, remove };
