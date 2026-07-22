const { ROLES } = require('./requireRole');
const { db } = require('../config/firebase-admin');

// Same list as the Flutter router's `_orgScopedRolesForSuspension` — any role
// tied to one organization's subscription. Patients aren't tied to one
// clinic's subscription status; Super Admin isn't tied to any organization.
const ORG_SCOPED_ROLES_FOR_SUSPENSION = [
  ROLES.ORGANIZATION_ADMIN,
  ROLES.BRANCH_ADMIN,
  ROLES.RECEPTIONIST,
  ROLES.ACCOUNTANT,
  ROLES.PHARMACIST,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

/**
 * Enforces org/branch data isolation (spec section 8/10/11): a Branch-level user
 * only ever touches their own branchId; an Organization Admin only their own
 * organizationId; Super Admin is unrestricted. This does not run a query itself —
 * it stamps req.scope so every controller/service builds its Firestore query
 * from req.scope instead of trusting client-supplied branchId/organizationId.
 *
 * Also enforces the suspension block at the API layer (Part 3 Task 3 DONE
 * CONDITION: suspending an organization must block its users immediately,
 * verifiable via a direct API call — not just a client-side redirect).
 */
async function attachScope(req, res, next) {
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

  if (ORG_SCOPED_ROLES_FOR_SUSPENSION.includes(role) && req.scope.organizationId) {
    const orgDoc = await db.collection('organizations').doc(req.scope.organizationId).get();
    const isActive = orgDoc.exists ? (orgDoc.data().isActive ?? true) : true;
    if (!isActive) {
      return res.status(403).json({ error: 'This organization has been suspended' });
    }
  }

  next();
}

module.exports = { attachScope, ORG_SCOPED_ROLES_FOR_SUSPENSION };
