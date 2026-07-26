const { ROLES } = require('./requireRole');
const { db } = require('../config/firebase-admin');

// Same list as the Flutter router's `_orgScopedRolesForSuspension` — any role
// tied to one clinic's subscription. Patients aren't tied to one
// clinic's subscription status; Super Admin isn't tied to any clinic.
const ORG_SCOPED_ROLES_FOR_SUSPENSION = [
  ROLES.CLINIC_ADMIN,
  ROLES.BRANCH_ADMIN,
  ROLES.RECEPTIONIST,
  ROLES.ACCOUNTANT,
  ROLES.PHARMACIST,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

/**
 * Enforces org/branch data isolation (spec section 8/10/11): a Branch-level user
 * only ever touches their own branchId; a Clinic Admin only their own
 * clinicId; Super Admin is unrestricted. This does not run a query itself —
 * it stamps req.scope so every controller/service builds its Firestore query
 * from req.scope instead of trusting client-supplied branchId/clinicId.
 *
 * Also enforces the suspension block at the API layer (Part 3 Task 3 DONE
 * CONDITION: suspending a clinic must block its users immediately,
 * verifiable via a direct API call — not just a client-side redirect).
 */
async function attachScope(req, res, next) {
  const { role, clinicId, branchId } = req.user || {};

  if (role === ROLES.SUPER_ADMIN) {
    req.scope = { level: 'platform' };
  } else if (role === ROLES.CLINIC_ADMIN) {
    req.scope = { level: 'clinic', clinicId };
  } else {
    req.scope = { level: 'branch', clinicId, branchId };
  }

  if (req.scope.level !== 'platform' && !req.scope.clinicId) {
    return res.status(403).json({ error: 'Account is missing a clinic assignment' });
  }
  if (req.scope.level === 'branch' && !req.scope.branchId) {
    return res.status(403).json({ error: 'Account is missing a branch assignment' });
  }

  if (ORG_SCOPED_ROLES_FOR_SUSPENSION.includes(role) && req.scope.clinicId) {
    const orgDoc = await db.collection('clinics').doc(req.scope.clinicId).get();
    const isActive = orgDoc.exists ? (orgDoc.data().isActive ?? true) : true;
    if (!isActive) {
      return res.status(403).json({ error: 'This clinic has been suspended' });
    }
    // Already fetched for the suspension check above, so stashing the name
    // here is free — lets any org-scoped controller (e.g. the invoice
    // receipt, 2026-07-26) show the clinic's own name without a second
    // Firestore read or a new role-gated endpoint (GET /clinics/:id is
    // Clinic Admin/Super Admin only, since it also returns billing/
    // subscription fields no other role should see).
    req.scope.clinicName = orgDoc.exists ? orgDoc.data().name || null : null;
  }

  next();
}

module.exports = { attachScope, ORG_SCOPED_ROLES_FOR_SUSPENSION };
