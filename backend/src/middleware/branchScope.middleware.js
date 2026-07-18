const { ROLES } = require('./role.middleware');

/**
 * Enforces org/branch data isolation (spec section 8/10/11): a Branch-level user
 * only ever touches their own branchId; an Organization Admin only their own
 * organizationId; Super Admin is unrestricted. This does not run a query itself —
 * it stamps req.scope so every controller/service builds its Firestore query
 * from req.scope instead of trusting client-supplied branchId/organizationId.
 */
function attachScope(req, res, next) {
  const { role, organizationId, branchId } = req.user || {};

  if (role === ROLES.SUPER_ADMIN) {
    req.scope = { level: 'platform' };
  } else if (role === ROLES.ORGANIZATION_ADMIN) {
    req.scope = { level: 'organization', organizationId };
  } else {
    req.scope = { level: 'branch', organizationId, branchId };
  }

  if (req.scope.level !== 'platform' && !req.scope.organizationId) {
    return res.status(403).json({ error: 'Account is missing an organization assignment' });
  }
  if (req.scope.level === 'branch' && !req.scope.branchId) {
    return res.status(403).json({ error: 'Account is missing a branch assignment' });
  }

  next();
}

module.exports = { attachScope };
