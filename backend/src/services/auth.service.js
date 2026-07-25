// Service layer for auth/account creation (spec section 5 / 6.1).
// PATCH (2026-07-23): the invite-link flow (createStaffInvite) is removed
// entirely — every account is created DIRECTLY and active immediately with
// a password the creating Admin set or generated. No email/SMS is ever
// sent as part of account creation.
const { auth, db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');

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

  const userRecord = await auth.createUser({
    email,
    password,
    displayName: name,
  });

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

module.exports = { createStaffAccountWithPassword, setUserClaims };
