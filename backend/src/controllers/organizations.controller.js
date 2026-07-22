// Controller for /api/v1/organizations — spec section 4 / 6.2 / 9, Part 3.
// Keep thin: parse/validate req, call organizations.service.js, shape the response.
const organizationsService = require('../services/organizations.service');
const authService = require('../services/auth.service');
const { ROLES } = require('../middleware/requireRole');

async function list(req, res, next) {
  try {
    const organizations = await organizationsService.list();
    res.json({ organizations });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const organization = await organizationsService.getById(req.params.id);
    if (!organization) return res.status(404).json({ error: 'Organization not found' });
    res.json({ organization });
  } catch (err) {
    next(err);
  }
}

// Part 3 Task 2: creates the organization, then invites its Organization
// Admin (Part 2 Task 6's staff-invite flow) — no password is set here.
async function create(req, res, next) {
  try {
    const { name, subscriptionPlan, ownerContactName, ownerContactPhone, adminEmail } = req.body;
    if (!name || !subscriptionPlan || !adminEmail) {
      return res.status(400).json({ error: 'name, subscriptionPlan, and adminEmail are required' });
    }

    const organization = await organizationsService.create({ name, subscriptionPlan, ownerContactName, ownerContactPhone });

    const invite = await authService.createStaffInvite({
      email: adminEmail,
      name: ownerContactName || name,
      role: ROLES.ORGANIZATION_ADMIN,
      organizationId: organization.id,
      branchId: null,
      invitedBy: req.user?.uid,
    });

    res.status(201).json({ organization, invite });
  } catch (err) {
    next(err);
  }
}

async function update(req, res, next) {
  try {
    const organization = await organizationsService.update(req.params.id, req.body);
    res.json({ organization });
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
    const organization = await organizationsService.setStatus(req.params.id, isActive, req.user?.uid);
    res.json({ organization });
  } catch (err) {
    next(err);
  }
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove organizations' });
}

module.exports = { list, getById, create, update, setStatus, remove };
