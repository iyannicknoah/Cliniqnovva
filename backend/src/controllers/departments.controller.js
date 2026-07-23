// Controller for /api/v1/departments — spec section 6.4 / 9 (Part 7).
// Full CRUD: list/create (Part 6), update + guarded remove (Part 7).
const departmentsService = require('../services/departments.service');

function resolveOrganizationId(req, explicit) {
  return req.scope.level === 'platform' ? explicit : req.scope.organizationId;
}

async function list(req, res, next) {
  try {
    const organizationId = resolveOrganizationId(req, req.query.organizationId);
    if (!organizationId) return res.status(400).json({ error: 'organizationId is required' });

    // Branch-level users only ever see their own branch's departments.
    const branchId = req.scope.level === 'branch' ? req.scope.branchId : req.query.branchId;

    const departments = await departmentsService.list({ organizationId, branchId });
    res.json({ departments });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const department = await departmentsService.getById(req.params.id);
    if (!department) return res.status(404).json({ error: 'Department not found' });
    if (req.scope.level !== 'platform' && department.organizationId !== req.scope.organizationId) {
      return res.status(403).json({ error: 'This department belongs to a different organization' });
    }
    res.json({ department });
  } catch (err) {
    next(err);
  }
}

async function create(req, res, next) {
  try {
    const organizationId = resolveOrganizationId(req, req.body.organizationId);
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

async function update(req, res, next) {
  try {
    const department = await departmentsService.update(
      req.params.id,
      { name: req.body.name, isActive: req.body.isActive },
      { actorId: req.user?.uid, actorRole: req.user?.role, scope: req.scope }
    );
    res.json({ department });
  } catch (err) {
    next(err);
  }
}

async function remove(req, res, next) {
  try {
    await departmentsService.remove(req.params.id, {
      actorId: req.user?.uid,
      actorRole: req.user?.role,
      scope: req.scope,
    });
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

module.exports = { list, getById, create, update, remove };
