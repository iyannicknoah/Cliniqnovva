// Controller for /api/auth (+ /api/v1/auth) — spec section 5 / 6.1.
// PATCH (2026-07-23): invite-link flow removed. createUser is now the ONLY
// account-creation path — direct, active immediately, password shown once.
const authService = require('../services/auth.service');
const patientsService = require('../services/patients.service');
const { ROLES } = require('../middleware/requireRole');

// Roles a scope-limited creator is never allowed to hand out, regardless of
// what the request body asks for — a conservative default against privilege
// escalation until Part 5 defines the full staff-creation authorization
// matrix (clinic_admin/branch_admin creating staff).
const ESCALATION_GUARDED_ROLES = [ROLES.SUPER_ADMIN, ROLES.CLINIC_ADMIN];

/**
 * POST /api/auth/create-user — {email, password, role, clinicId,
 * branchId?, displayName} -> {uid, success: true}. The only account-
 * creation path: creates the Firebase Auth user directly with the given
 * password, sets custom claims, and returns immediately. No email/SMS is
 * sent; the account is active and can log in right away.
 */
async function createUser(req, res, next) {
  try {
    const { email, password, role, displayName } = req.body;
    let { clinicId, branchId } = req.body;

    if (!email || !password || !role || !displayName) {
      return res.status(400).json({ error: 'email, password, role, and displayName are required' });
    }
    if (role !== ROLES.SUPER_ADMIN && !clinicId && req.scope?.level !== 'clinic' && req.scope?.level !== 'branch') {
      return res.status(400).json({ error: 'clinicId is required for this role' });
    }

    // Data-isolation guard (CRITICAL RULE — never trust a client-supplied
    // clinicId/branchId over the caller's own scope): an
    // Clinic Admin can only create staff within their own
    // clinic; a Branch Admin only within their own branch.
    if (req.scope?.level === 'clinic') {
      clinicId = req.scope.clinicId;
    } else if (req.scope?.level === 'branch') {
      clinicId = req.scope.clinicId;
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
      clinicId: clinicId || null,
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
    const { uid, role, clinicId, branchId } = req.body;
    if (!uid || !role) {
      return res.status(400).json({ error: 'uid and role are required' });
    }

    await authService.setUserClaims({ uid, role, clinicId, branchId });
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

/**
 * POST /api/auth/patient/check-duplicate — {phone?, nationalId?} ->
 * {matches}. Part 19 Task 3: called right after the Flutter app creates
 * the Firebase Auth account (client-side createUserWithEmailAndPassword)
 * but before finalize-registration, so the UI can show the "we found an
 * existing record at [Clinic]" prompt. verifyToken-only — deliberately NOT
 * behind attachScope, since this caller has no custom claims yet at all
 * (the token was just minted, no role has been set).
 */
async function checkPatientDuplicate(req, res, next) {
  try {
    const { phone, nationalId } = req.body;
    if (!phone && !nationalId) {
      return res.status(400).json({ error: 'phone or nationalId is required' });
    }
    // No clinicId -> patients.service.js#checkDuplicate searches across
    // every clinic and resolves each match's clinic name.
    const matches = await patientsService.checkDuplicate({ phone, nationalId });
    res.json({ matches });
  } catch (err) {
    next(err);
  }
}

/**
 * POST /api/auth/patient/finalize-registration — {name, phone?, email?,
 * nationalId?, preferredLanguage?, linkPatientId?} -> {uid, linkedPatientId}.
 * The one write-side step of Part 19 Task 3's registration flow: sets the
 * `patient` custom claim + /users/{uid} profile, and — if the caller chose
 * "Yes, link my account" against a match from check-duplicate above —
 * links to that walk-in record (re-verified server-side, see
 * patients.service.js#linkPatientAccount).
 */
async function finalizePatientRegistration(req, res, next) {
  try {
    const { name, phone, email, nationalId, preferredLanguage, linkPatientId } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Full name is required' });
    }
    if (!phone && !email) {
      return res.status(400).json({ error: 'Phone or email is required' });
    }
    const uid = req.user.uid;

    await authService.registerPatientAccount({ uid, name, phone, email, nationalId, preferredLanguage });

    let linkedPatientId = null;
    if (linkPatientId) {
      const linked = await patientsService.linkPatientAccount({ patientId: linkPatientId, uid, phone, nationalId });
      linkedPatientId = linked.id;
      await authService.recordLinkedPatient(uid, linkedPatientId);
    }

    res.status(201).json({ success: true, uid, linkedPatientId });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  createUser,
  setClaims,
  requestPasswordReset,
  deactivateAccount,
  me,
  checkPatientDuplicate,
  finalizePatientRegistration,
};
