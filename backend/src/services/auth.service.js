// Service layer for auth/staff-onboarding (spec section 5 / 6.1, Part 2 Task 6).
const { auth, db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');

const ALL_ROLES = Object.values(ROLES);

/**
 * Creates the Firebase Auth user + Firestore /users doc for a new staff
 * member, sets their custom claims, and generates a password-setup link
 * (spec: "without Admin typing a password"). Email delivery isn't wired up
 * yet — the link is returned in the response and logged to console as a
 * stand-in until a real provider is chosen (see spec section 13).
 */
async function createStaffInvite({ email, phone, name, role, organizationId, branchId, invitedBy }) {
  if (!ALL_ROLES.includes(role)) {
    const err = new Error(`Unknown role "${role}"`);
    err.status = 400;
    throw err;
  }
  if (!email && !phone) {
    const err = new Error('Either email or phone is required');
    err.status = 400;
    throw err;
  }

  const userRecord = await auth.createUser({
    email: email || undefined,
    phoneNumber: phone || undefined,
    displayName: name,
  });

  await auth.setCustomUserClaims(userRecord.uid, { role, organizationId, branchId: branchId || null });

  await db
    .collection('users')
    .doc(userRecord.uid)
    .set({
      role,
      organizationId,
      branchId: branchId || null,
      name,
      email: email || null,
      phone: phone || null,
      preferredLanguage: 'en',
      isActive: true,
      inviteStatus: 'pending',
      createdAt: new Date().toISOString(),
    });

  await db.collection('auditLogs').add({
    actorId: invitedBy || null,
    actorRole: 'system',
    action: 'staff.invited',
    targetCollection: 'users',
    targetId: userRecord.uid,
    organizationId,
    timestamp: new Date().toISOString(),
  });

  let inviteLink = null;
  if (email) {
    inviteLink = await auth.generatePasswordResetLink(email);
    // Placeholder for real email delivery (spec: "provider is a later decision").
    console.log(`[auth] Password setup link for ${email}: ${inviteLink}`);
  } else {
    console.log(`[auth] SMS invite for ${phone} — no SMS provider wired up yet (spec section 13).`);
  }

  return { uid: userRecord.uid, inviteLink };
}

/**
 * Creates the Firebase Auth user + Firestore /users doc for a new clinic
 * (organization) admin using a password the Super Admin sets directly —
 * no invite link, no email. Used by organizations.controller.js's create()
 * so the Super Admin can hand the clinic admin working credentials on the spot.
 */
async function createStaffAccountWithPassword({ email, password, name, role, organizationId, branchId, invitedBy }) {
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

  await auth.setCustomUserClaims(userRecord.uid, { role, organizationId, branchId: branchId || null });

  await db
    .collection('users')
    .doc(userRecord.uid)
    .set({
      role,
      organizationId,
      branchId: branchId || null,
      name,
      email,
      phone: null,
      preferredLanguage: 'en',
      isActive: true,
      inviteStatus: 'active',
      createdAt: new Date().toISOString(),
    });

  await db.collection('auditLogs').add({
    actorId: invitedBy || null,
    actorRole: 'system',
    action: 'staff.accountCreated',
    targetCollection: 'users',
    targetId: userRecord.uid,
    organizationId,
    timestamp: new Date().toISOString(),
  });

  return { uid: userRecord.uid };
}

/**
 * Sets/updates a user's Firebase custom claims AND keeps the mirrored
 * Firestore /users doc fields in sync (Part 2 Task 6: POST /api/auth/set-claims).
 */
async function setUserClaims({ uid, role, organizationId, branchId }) {
  if (role && !ALL_ROLES.includes(role)) {
    const err = new Error(`Unknown role "${role}"`);
    err.status = 400;
    throw err;
  }

  const claims = { role, organizationId, branchId: branchId || null };
  await auth.setCustomUserClaims(uid, claims);

  await db
    .collection('users')
    .doc(uid)
    .set({ role, organizationId, branchId: branchId || null }, { merge: true });

  return claims;
}

module.exports = { createStaffInvite, createStaffAccountWithPassword, setUserClaims };
