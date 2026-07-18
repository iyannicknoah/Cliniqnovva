const ROLES = Object.freeze({
  SUPER_ADMIN: 'superAdmin',
  ORGANIZATION_ADMIN: 'organizationAdmin',
  BRANCH_ADMIN: 'branchAdmin',
  RECEPTIONIST: 'receptionist',
  ACCOUNTANT: 'accountant',
  PHARMACIST: 'pharmacist',
  DOCTOR: 'doctor',
  NURSE: 'nurse',
  PATIENT: 'patient',
});

/**
 * Usage: router.get('/x', requireAuth, requireRole(ROLES.DOCTOR, ROLES.NURSE), handler)
 * Must run after requireAuth so req.user.role (custom claim) is available.
 */
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient role permissions' });
    }
    next();
  };
}

module.exports = { ROLES, requireRole };
