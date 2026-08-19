// One-off/reusable script (2026-08-19, explicit user request: "make
// [admin@cliniqnova.rw] get way to access superadmin dashboard") — grants
// the super_admin role to an EXISTING Firebase Auth user, i.e. one created
// directly in the Firebase console rather than through this app's normal
// POST /api/auth/create-user flow. That normal flow can't bootstrap the
// very first Super Admin at all: auth.controller.js#createUser rejects any
// SUPER_ADMIN/CLINIC_ADMIN request unless the caller is ALREADY
// platform-scoped (req.scope.level === 'platform'), which nothing is until
// one exists. This script is the deliberate side door for that one-time
// bootstrap — mirrors auth.service.js#createStaffAccountWithPassword's
// custom-claims + /users doc shape exactly, minus the "create the Auth
// user" step (already done manually in the console).
//
// Usage: node scripts/grantSuperAdmin.js admin@cliniqnova.rw "Admin Name"
//   - email: required, must already exist as a Firebase Auth user.
//   - name: optional display name for the /users doc; falls back to the
//     Auth user's existing displayName, then the email's local part.
//
// Idempotent — safe to re-run (uses Firestore `set(..., {merge:true})` and
// setCustomUserClaims, which both overwrite rather than duplicate).
const { auth, db } = require('../src/config/firebase-admin');
const { ROLES } = require('../src/middleware/requireRole');

async function main() {
  const email = process.argv[2];
  const nameArg = process.argv[3];

  if (!email) {
    console.error('Usage: node scripts/grantSuperAdmin.js <email> [displayName]');
    process.exitCode = 1;
    return;
  }

  const userRecord = await auth.getUserByEmail(email).catch((err) => {
    if (err.code === 'auth/user-not-found') {
      throw new Error(
        `No Firebase Auth user exists for "${email}" — create it in the Firebase console first, then re-run this script.`
      );
    }
    throw err;
  });

  const name = nameArg || userRecord.displayName || email.split('@')[0];

  await auth.setCustomUserClaims(userRecord.uid, {
    role: ROLES.SUPER_ADMIN,
    clinicId: null,
    branchId: null,
  });

  await db
    .collection('users')
    .doc(userRecord.uid)
    .set(
      {
        role: ROLES.SUPER_ADMIN,
        clinicId: null,
        branchId: null,
        name,
        email,
        phone: null,
        preferredLanguage: 'en',
        isActive: true,
        createdAt: new Date().toISOString(),
      },
      { merge: true }
    );

  console.log(`Granted super_admin to ${email} (uid: ${userRecord.uid}).`);
  console.log('Sign out and back in (or wait ~1hr for the ID token to refresh) for the new role to take effect.');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err.message || err);
    process.exit(1);
  });
