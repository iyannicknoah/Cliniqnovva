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

/**
 * Saves/updates the caller's OWN push token (Part 25 groundwork for Task
 * 4's "push arrives on the device" — notifications.service.js#sendPush()
 * reads this exact field). /users/{userId} writes are backend-only per
 * firestore.rules (`allow write: if false`), so even a user updating their
 * own token can't be a direct client write — this is the one place that
 * happens. Any authenticated role, not patient-only: nothing about this is
 * patient-specific, and a future staff-side push flow can reuse it as-is.
 */
async function setFcmToken(uid, token) {
  await db.collection('users').doc(uid).set({ fcmToken: token }, { merge: true });
}

const PATIENT_PROFILE_FIELDS = ['name', 'phone', 'email', 'dateOfBirth', 'nationalId'];
const NOTIFICATION_PREFERENCE_KEYS = ['appointmentReminders', 'chatMessages', 'reviewReplies'];

/**
 * Part 26 — a patient editing their OWN account profile. Deliberately
 * `/users/{uid}`, NOT `PUT /api/patients/:patientId` (the walk-in-record
 * endpoint every earlier part's Settings-adjacent work touches): a patient
 * can have several walk-in `/patients` docs, one per clinic
 * (getOrCreatePatientRecordForClinic), but exactly one account profile —
 * `/users/{uid}` is the only 1:1 place "my own settings" can mean.
 * `/users/{userId}` writes are backend-only per firestore.rules, same
 * reasoning as setFcmToken above.
 */
async function updatePatientProfile(uid, { name, phone, email, dateOfBirth, nationalId, notificationPreferences }) {
  const updates = {};
  if (name !== undefined) {
    if (!name || !name.trim()) {
      const e = new Error('Full name cannot be empty');
      e.status = 400;
      throw e;
    }
    updates.name = name.trim();
  }
  if (phone !== undefined) {
    updates.phone = phone ? phone.trim() : null;
    updates.phoneDigits = phone ? digitsOnly(phone) : null;
  }
  if (email !== undefined) updates.email = email || null;
  if (dateOfBirth !== undefined) updates.dateOfBirth = dateOfBirth || null;
  if (nationalId !== undefined) {
    if (nationalId && !/^\d{16}$/.test(nationalId)) {
      const e = new Error('National ID must be exactly 16 digits');
      e.status = 400;
      throw e;
    }
    updates.nationalId = nationalId || null;
  }

  if (notificationPreferences !== undefined) {
    const ref = db.collection('users').doc(uid);
    const existingDoc = await ref.get();
    const existingPrefs = (existingDoc.exists && existingDoc.data().notificationPreferences) || {};
    const merged = { ...existingPrefs };
    for (const key of NOTIFICATION_PREFERENCE_KEYS) {
      if (notificationPreferences[key] !== undefined) merged[key] = !!notificationPreferences[key];
    }
    updates.notificationPreferences = merged;
  }

  if (Object.keys(updates).length === 0) {
    const e = new Error('No editable fields provided');
    e.status = 400;
    throw e;
  }

  await db.collection('users').doc(uid).update(updates);
  const doc = await db.collection('users').doc(uid).get();
  return { id: doc.id, ...doc.data() };
}

module.exports = {
  createStaffAccountWithPassword,
  setUserClaims,
  registerPatientAccount,
  recordLinkedPatient,
  setFcmToken,
  updatePatientProfile,
  PATIENT_PROFILE_FIELDS,
};
