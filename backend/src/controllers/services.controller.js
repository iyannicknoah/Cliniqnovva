// Controller for /api/v1/services — spec section 6.4 / 9 (Part 7).
const servicesService = require('../services/services.service');

function resolveOrganizationId(req, explicit) {
  return req.scope.level === 'platform' ? explicit : req.scope.organizationId;
}

async function list(req, res, next) {
  try {
    const organizationId = resolveOrganizationId(req, req.query.organizationId);
    if (!organizationId) return res.status(400).json({ error: 'organizationId is required' });

    // Branch-level users only ever see their own branch's catalog.
    const branchId = req.scope.level === 'branch' ? req.scope.branchId : req.query.branchId;
    const departmentId = req.query.departmentId;

    const services = await servicesService.list({ organizationId, branchId, departmentId });
    res.json({ services });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const service = await servicesService.getById(req.params.id);
    if (!service) return res.status(404).json({ error: 'Service not found' });
    if (req.scope.level !== 'platform' && service.organizationId !== req.scope.organizationId) {
      return res.status(403).json({ error: 'This service belongs to a different organization' });
    }
    res.json({ service });
  } catch (err) {
    next(err);
  }
}

async function create(req, res, next) {
  try {
    const organizationId = resolveOrganizationId(req, req.body.organizationId);
    if (!organizationId) return res.status(400).json({ error: 'organizationId is required' });

    const branchId = req.scope.level === 'branch' ? req.scope.branchId : req.body.branchId;

    const service = await servicesService.create(
      {
        organizationId,
        branchId,
        departmentId: req.body.departmentId,
        name: req.body.name,
        defaultDurationMins: req.body.defaultDurationMins,
        defaultPriceRwf: req.body.defaultPriceRwf,
      },
      { actorId: req.user?.uid, actorRole: req.user?.role }
    );
    res.status(201).json({ service });
  } catch (err) {
    next(err);
  }
}

async function update(req, res, next) {
  try {
    const service = await servicesService.update(
      req.params.id,
      {
        name: req.body.name,
        departmentId: req.body.departmentId,
        defaultDurationMins: req.body.defaultDurationMins,
        defaultPriceRwf: req.body.defaultPriceRwf,
        isActive: req.body.isActive,
      },
      { actorId: req.user?.uid, actorRole: req.user?.role, scope: req.scope }
    );
    res.json({ service });
  } catch (err) {
    next(err);
  }
}

async function remove(req, res, next) {
  try {
    await servicesService.remove(req.params.id, {
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
