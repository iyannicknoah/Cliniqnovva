// Controller for /api/v1/branches — spec section 4 / 6.2 / 9
// list/getById/create are real (Part 3 needs them); update/remove stay
// stubs — full branch management is Part 6's scope.
const branchesService = require('../services/branches.service');

async function list(req, res, next) {
  try {
    const organizationId = req.query.organizationId || req.scope.organizationId;
    if (!organizationId) return res.status(400).json({ error: 'organizationId is required' });
    const branches = await branchesService.list(organizationId);
    res.json({ branches });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const branch = await branchesService.getById(req.params.id);
    if (!branch) return res.status(404).json({ error: 'Branch not found' });
    res.json({ branch });
  } catch (err) {
    next(err);
  }
}

// Normally an Organization Admin creates their own branches (req.scope
// supplies organizationId). Super Admin has no organization scope, so it
// must come from the request body — that's the "on this org's behalf" path.
async function create(req, res, next) {
  try {
    const { organizationId, name, address, phone } = req.body;
    const targetOrganizationId = req.scope.level === 'organization' ? req.scope.organizationId : organizationId;

    if (!targetOrganizationId || !name) {
      return res.status(400).json({ error: 'organizationId and name are required' });
    }

    const branch = await branchesService.create(
      { organizationId: targetOrganizationId, name, address, phone },
      { actorId: req.user?.uid, actorRole: req.user?.role }
    );
    res.status(201).json({ branch });
  } catch (err) {
    next(err);
  }
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update branches' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove branches' });
}

module.exports = { list, getById, create, update, remove };
