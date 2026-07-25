// Role string values MUST match core/constants/app_constants.dart on the
// Flutter side exactly (snake_case) — these are compared as literal strings
// against Firebase custom claims / Firestore fields, not just internal enum
// keys, so a mismatch here silently breaks every role check.
const ROLES = Object.freeze({
  SUPER_ADMIN: 'super_admin',
  CLINIC_ADMIN: 'clinic_admin',
  BRANCH_ADMIN: 'branch_admin',
  RECEPTIONIST: 'receptionist',
  ACCOUNTANT: 'accountant',
  PHARMACIST: 'pharmacist',
  DOCTOR: 'doctor',
  NURSE: 'nurse',
  PATIENT: 'patient',
});

/**
 * Usage: router.get('/x', verifyToken, requireRole(ROLES.DOCTOR, ROLES.NURSE), handler)
 * Must run after verifyToken so req.user.role (custom claim) is available.
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
