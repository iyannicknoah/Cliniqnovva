// Controller for /api/auth (+ /api/v1/auth) — spec section 5 / 6.1.
// PATCH (2026-07-23): invite-link flow removed. createUser is now the ONLY
// account-creation path — direct, active immediately, password shown once.
const authService = require('../services/auth.service');
const { ROLES } = require('../middleware/requireRole');

// Roles a scope-limited creator is never allowed to hand out, regardless of
// what the request body asks for — a conservative default against privilege
// escalation until Part 5 defines the full staff-creation authorization
// matrix (organization_admin/branch_admin creating staff).
const ESCALATION_GUARDED_ROLES = [ROLES.SUPER_ADMIN, ROLES.ORGANIZATION_ADMIN];

/**
 * POST /api/auth/create-user — {email, password, role, organizationId,
 * branchId?, displayName} -> {uid, success: true}. The only account-
 * creation path: creates the Firebase Auth user directly with the given
 * password, sets custom claims, and returns immediately. No email/SMS is
 * sent; the account is active and can log in right away.
 */
async function createUser(req, res, next) {
  try {
    const { email, password, role, displayName } = req.body;
    let { organizationId, branchId } = req.body;

    if (!email || !password || !role || !displayName) {
      return res.status(400).json({ error: 'email, password, role, and displayName are required' });
    }
    if (role !== ROLES.SUPER_ADMIN && !organizationId && req.scope?.level !== 'organization' && req.scope?.level !== 'branch') {
      return res.status(400).json({ error: 'organizationId is required for this role' });
    }

    // Data-isolation guard (CRITICAL RULE — never trust a client-supplied
    // organizationId/branchId over the caller's own scope): an
    // Organization Admin can only create staff within their own
    // organization; a Branch Admin only within their own branch.
    if (req.scope?.level === 'organization') {
      organizationId = req.scope.organizationId;
    } else if (req.scope?.level === 'branch') {
      organizationId = req.scope.organizationId;
      branchId = req.scope.branchId;
    }

    if (req.scope?.level !== 'platform' && ESCALATION_GUARDED_ROLES.includes(role)) {
      return res.status(403).json({ error: 'You are not allowed to create an account with this role' });
    }

    const result = await authService.createStaffAccountWithPassword({
      email,
      password,
      name: displayName,
      role,
      organizationId: organizationId || null,
      branchId: branchId || null,
      createdBy: req.user?.uid,
    });

    res.status(201).json({ uid: result.uid, success: true });
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

async function requestPasswordReset(req, res) {
  res.status(501).json({ error: 'Not implemented yet: request password reset' });
}

async function deactivateAccount(req, res) {
  res.status(501).json({ error: 'Not implemented yet: deactivate account (isActive=false, spec section 6.1)' });
}

async function me(req, res) {
  res.status(501).json({ error: 'Not implemented yet: return current user profile from req.user' });
}

module.exports = { createUser, setClaims, requestPasswordReset, deactivateAccount, me };
