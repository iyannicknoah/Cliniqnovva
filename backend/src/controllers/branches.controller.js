// Controller for /api/v1/branches — spec section 4 / 6.2 / 9 (Part 6).
// Route shapes per the Part 6 spec: POST /, GET / (or /:organizationId),
// GET /detail/:branchId, PUT /:branchId, PUT /:branchId/status.
const branchesService = require('../services/branches.service');

function resolveOrganizationId(req, explicit) {
  // Org- and branch-level users are ALWAYS pinned to their own organization
  // (never trust a client-supplied id); only Super Admin may pick one.
  if (req.scope.level === 'platform') return explicit;
  return req.scope.organizationId;
}

async function list(req, res, next) {
  try {
    const organizationId = resolveOrganizationId(req, req.query.organizationId);
    if (!organizationId) return res.status(400).json({ error: 'organizationId is required' });
    const result = await branchesService.listWithPlan(organizationId);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

// GET /:organizationId — the Part 6 spec's list shape. Same handler as
// list(), with the id in the path instead of the query string.
async function listByOrganization(req, res, next) {
  try {
    const organizationId = resolveOrganizationId(req, req.params.organizationId);
    const result = await branchesService.listWithPlan(organizationId);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const branch = await branchesService.getById(req.params.branchId || req.params.id);
    if (!branch) return res.status(404).json({ error: 'Branch not found' });
    // Non-super users may only read branches of their own organization.
    if (req.scope.level !== 'platform' && branch.organizationId !== req.scope.organizationId) {
      return res.status(403).json({ error: 'This branch belongs to a different organization' });
    }
    res.json({ branch });
  } catch (err) {
    next(err);
  }
}

// Normally an Organization Admin creates their own branches (req.scope
// supplies organizationId). Super Admin has no organization scope, so it
// must come from the request body — that's the "on this org's behalf" path
// (logged distinctly by the service).
async function create(req, res, next) {
  try {
    const { organizationId, name, address, phone, location, workingHours, umugandaSaturdayHours, servicesOffered } =
      req.body;
    const targetOrganizationId = resolveOrganizationId(req, organizationId);

    if (!targetOrganizationId || !name) {
      return res.status(400).json({ error: 'organizationId and name are required' });
    }

    const branch = await branchesService.create(
      {
        organizationId: targetOrganizationId,
        name,
        address,
        phone,
        location,
        workingHours,
        umugandaSaturdayHours,
        servicesOffered,
      },
      { actorId: req.user?.uid, actorRole: req.user?.role }
    );
    res.status(201).json({ branch });
  } catch (err) {
    next(err);
  }
}

async function update(req, res, next) {
  try {
    const branch = await branchesService.update(req.params.branchId || req.params.id, req.body, {
      actorId: req.user?.uid,
      actorRole: req.user?.role,
      scope: req.scope,
    });
    res.json({ branch });
  } catch (err) {
    next(err);
  }
}

async function setStatus(req, res, next) {
  try {
    const { isActive } = req.body;
    if (typeof isActive !== 'boolean') {
      return res.status(400).json({ error: 'isActive (boolean) is required' });
    }
    const branch = await branchesService.setStatus(req.params.branchId, isActive, {
      actorId: req.user?.uid,
      actorRole: req.user?.role,
      scope: req.scope,
    });
    res.json({ branch });
  } catch (err) {
    next(err);
  }
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented: branches are deactivated, not deleted' });
}

module.exports = { list, listByOrganization, getById, create, update, setStatus, remove };
