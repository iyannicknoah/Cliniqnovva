// Controller for /api/v1/auth — spec section 5 / 6.1
// Project-setup phase: handlers are stubs (501).
// Real login itself happens client-side via Firebase Auth SDK; this controller
// only needs to cover what the backend must own: staff invites, role/claim
// assignment, deactivation, and password-reset triggering.

async function inviteStaff(req, res) {
  res.status(501).json({ error: 'Not implemented yet: invite staff (email/SMS invite link, spec section 5)' });
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

module.exports = { inviteStaff, completeInvite, requestPasswordReset, deactivateAccount, me };
