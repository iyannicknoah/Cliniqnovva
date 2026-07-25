// In-memory stand-in for the Firebase Admin Auth SDK, covering only what
// auth.service.js / staff.service.js / verifyToken.js actually call:
// createUser, setCustomUserClaims, updateUser, getUser, and a simplified
// verifyIdToken good enough to exercise verifyToken.js's own branching
// (checkRevoked -> auth/user-disabled) — it does not simulate real JWT
// signing/verification, since that's Firebase's concern, not this app's.
class MockAuth {
  constructor() {
    this.users = new Map(); // uid -> record
    this._counter = 0;
  }

  async createUser({ email, password, displayName }) {
    if (!email || !password) {
      const err = new Error('The email address and password are required.');
      err.code = 'auth/invalid-argument';
      throw err;
    }
    for (const existing of this.users.values()) {
      if (existing.email === email) {
        const err = new Error('The email address is already in use by another account.');
        err.code = 'auth/email-already-exists';
        throw err;
      }
    }
    const uid = `uid_${++this._counter}`;
    this.users.set(uid, { uid, email, password, displayName, disabled: false, customClaims: {} });
    return { uid };
  }

  async setCustomUserClaims(uid, claims) {
    const user = this.users.get(uid);
    if (!user) throw new Error(`mockAuth: no user record found for uid ${uid}`);
    user.customClaims = { ...claims };
  }

  async updateUser(uid, updates) {
    const user = this.users.get(uid);
    if (!user) throw new Error(`mockAuth: no user record found for uid ${uid}`);
    Object.assign(user, updates);
    return { ...user };
  }

  async getUser(uid) {
    const user = this.users.get(uid);
    if (!user) {
      const err = new Error(`mockAuth: no user record found for uid ${uid}`);
      err.code = 'auth/user-not-found';
      throw err;
    }
    return { ...user };
  }

  // Tests pass the uid directly as the "token" — this mock only needs to
  // prove verifyToken.js's OWN logic (checkRevoked -> user-disabled
  // rejection) behaves correctly, not re-implement JWT verification.
  async verifyIdToken(token, checkRevoked) {
    const user = this.users.get(token);
    if (!user) {
      const err = new Error('mockAuth: invalid token');
      err.code = 'auth/argument-error';
      throw err;
    }
    if (checkRevoked && user.disabled) {
      const err = new Error('mockAuth: user disabled');
      err.code = 'auth/user-disabled';
      throw err;
    }
    return {
      uid: user.uid,
      email: user.email,
      role: user.customClaims.role,
      clinicId: user.customClaims.clinicId,
      branchId: user.customClaims.branchId ?? null,
    };
  }
}

module.exports = { MockAuth };
