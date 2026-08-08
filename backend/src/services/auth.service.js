// Service layer for auth/account creation (spec section 5 / 6.1).
// PATCH (2026-07-23): the invite-link flow (createStaffInvite) is removed
// entirely — every account is created DIRECTLY and active immediately with
// a password the creating Admin set or generated. No email/SMS is ever
// sent as part of account creation.
const { auth, db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');
const { digitsOnly } = require('./patients.service');

const ALL_ROLES = Object.values(ROLES);

/**
 * Creates the Firebase Auth user + Firestore /users doc directly with a
 * password the caller set or generated — no invite link, no email, no
 * pending state. The account can log in immediately. This is the ONLY
 * account-creation path (POST /api/auth/create-user, and internally reused
 * by clinics.controller.js's create() for the Clinic Admin
 * account).
 */
async function createStaffAccountWithPassword({
  email,
  password,
  name,
  role,
  clinicId,
  branchId,
  phone,
  createdBy,
}) {
  if (!ALL_ROLES.includes(role)) {
    const err = new Error(`Unknown role "${role}"`);
    err.status = 400;
    throw err;
  }
  if (!email || !password) {
    const err = new Error('Email and password are required');
    err.status = 400;
    throw err;
  }

  let userRecord;
  try {
    userRecord = await auth.createUser({ email, password, displayName: name });
  } catch (err) {
    if (err.code === 'auth/email-already-exists') {
      const e = new Error(`An account with email "${email}" already exists.`);
      e.status = 409;
      throw e;
    }
    if (err.code === 'auth/invalid-password') {
      const e = new Error('Password must be at least 6 characters.');
      e.status = 400;
      throw e;
    }
    if (err.code === 'auth/invalid-email') {
      const e = new Error(`"${email}" is not a valid email address.`);
      e.status = 400;
      throw e;
    }
    throw err;
  }

  await auth.setCustomUserClaims(userRecord.uid, { role, clinicId, branchId: branchId || null });

  await db
    .collection('users')
    .doc(userRecord.uid)
    .set({
      role,
      clinicId,
      branchId: branchId || null,
      name,
      email,
      phone: phone || null,
      preferredLanguage: 'en',
      isActive: true,
      createdAt: new Date().toISOString(),
    });

  return { uid: userRecord.uid };
}

/**
 * Sets/updates a user's Firebase custom claims AND keeps the mirrored
 * Firestore /users doc fields in sync (Part 2 Task 6: POST /api/auth/set-claims).
 */
async function setUserClaims({ uid, role, clinicId, branchId }) {
  if (role && !ALL_ROLES.includes(role)) {
    const err = new Error(`Unknown role "${role}"`);
    err.status = 400;
    throw err;
  }

  const claims = { role, clinicId, branchId: branchId || null };
  await auth.setCustomUserClaims(uid, claims);

  await db
    .collection('users')
    .doc(uid)
    .set({ role, clinicId, branchId: branchId || null }, { merge: true });

  return claims;
}

/**
 * Finishes a patient's self-registration (Part 19, POST /api/auth/patient/
 * finalize-registration). Unlike createStaffAccountWithPassword, the
 * Firebase Auth user already exists by this point — the Flutter app creates
 * it directly via createUserWithEmailAndPassword so it never has to send a
 * patient's chosen password to this backend. This just:
 *   1. Sets the `patient` custom claim (clinicId/branchId null — a patient
 *      is never tied to one clinic, per the /users schema).
 *   2. Writes/merges the /users/{uid} profile doc every other role already
 *      gets, so a patient's own identity is readable the same way (and
 *      Firestore rules already allow `request.auth.uid == userId` reads).
 * Idempotent by design (`set(..., { merge: true })`) — safe to call again
 * if e.g. the app retries after a dropped connection.
 */
async function registerPatientAccount({ uid, name, phone, email, nationalId, preferredLanguage }) {
  await auth.setCustomUserClaims(uid, { role: ROLES.PATIENT, clinicId: null, branchId: null });

  const data = {
    role: ROLES.PATIENT,
    clinicId: null,
    branchId: null,
    name: name.trim(),
    phone: phone ? phone.trim() : null,
    phoneDigits: phone ? digitsOnly(phone) : null,
    email: email || null,
    nationalId: nationalId || null,
    preferredLanguage: preferredLanguage || 'en',
    isActive: true,
    createdAt: new Date().toISOString(),
  };
  await db.collection('users').doc(uid).set(data, { merge: true });
  return data;
}

/**
 * Mirrors a successful patients.service.js#linkPatientAccount call onto the
 * account's own /users/{uid} doc, so the app can list which walk-in
 * records this identity is linked to without a separate collection scan.
 */
async function recordLinkedPatient(uid, patientId) {
  const ref = db.collection('users').doc(uid);
  const doc = await ref.get();
  const existing = (doc.exists && doc.data().linkedPatientIds) || [];
  if (existing.includes(patientId)) return;
  await ref.set({ linkedPatientIds: [...existing, patientId] }, { merge: true });
}

module.exports = {
  createStaffAccountWithPassword,
  setUserClaims,
  registerPatientAccount,
  recordLinkedPatient,
};
