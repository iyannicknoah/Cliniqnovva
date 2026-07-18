// Controller for /api/auth (+ /api/v1/auth) — spec section 5 / 6.1, Part 2 Task 6.
const authService = require('../services/auth.service');

async function inviteStaff(req, res, next) {
  try {
    const { email, phone, name, role, organizationId, branchId } = req.body;
    if (!name || !role || !organizationId) {
      return res.status(400).json({ error: 'name, role, and organizationId are required' });
    }

    const result = await authService.createStaffInvite({
      email,
      phone,
      name,
      role,
      organizationId,
      branchId,
      invitedBy: req.user?.uid,
    });

    res.status(201).json({ success: true, ...result });
  } catch (err) {
    next(err);
  }
}

async function setClaims(req, res, next) {
  try {
    const { uid, role, organizationId, branchId } = req.body;
    if (!uid || !role) {
      return res.status(400).json({ error: 'uid and role are required' });
    }

    await authService.setUserClaims({ uid, role, organizationId, branchId });
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
}

async function completeInvite(req, res) {
  res.status(501).json({ error: 'Not implemented yet: complete staff invite / set first password' });
}

async function requestPasswordReset(req, res) {
  res.status(501).json({ error: 'Not implemented yet: request password reset' });
}

async function deactivateAccount(req, res) {
  res.status(501).json({ error: 'Not implemented yet: deactivate account (isActive=false, spec section 6.1)' });
}

async function me(req, res) {
  res.status(501).json({ error: 'Not implemented yet: return current user profile from req.user' });
}

module.exports = { inviteStaff, setClaims, completeInvite, requestPasswordReset, deactivateAccount, me };
