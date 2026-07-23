// Controller for /api/v1/departments — spec section 6.4 / 9.
// Part 6: list/create are real (the onboarding wizard needs create).
// getById/update/remove stay stubs until the Departments screen part.
const departmentsService = require('../services/departments.service');

async function list(req, res, next) {
  try {
    const organizationId =
      req.scope.level === 'platform' ? req.query.organizationId : req.scope.organizationId;
    if (!organizationId) return res.status(400).json({ error: 'organizationId is required' });

    // Branch-level users only ever see their own branch's departments.
    const branchId = req.scope.level === 'branch' ? req.scope.branchId : req.query.branchId;

    const departments = await departmentsService.list({ organizationId, branchId });
    res.json({ departments });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get departments by id' });
}

async function create(req, res, next) {
  try {
    const organizationId =
      req.scope.level === 'platform' ? req.body.organizationId : req.scope.organizationId;
    if (!organizationId) return res.status(400).json({ error: 'organizationId is required' });

    const branchId = req.scope.level === 'branch' ? req.scope.branchId : req.body.branchId;

    const department = await departmentsService.create(
      { organizationId, branchId, name: req.body.name },
      { actorId: req.user?.uid, actorRole: req.user?.role }
    );
    res.status(201).json({ department });
  } catch (err) {
    next(err);
  }
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update departments' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove departments' });
}

module.exports = { list, getById, create, update, remove };
