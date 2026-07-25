const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, reset } = require('./support/setup');
const authService = require('../src/services/auth.service');
const { verifyToken } = require('../src/middleware/verifyToken');

beforeEach(() => reset());

function mockRes() {
  const res = { statusCode: null, body: null };
  res.status = (c) => {
    res.statusCode = c;
    return res;
  };
  res.json = (b) => {
    res.body = b;
    return res;
  };
  return res;
}

test('auth: direct account creation is active immediately with no pending/invite state', async () => {
  const { uid } = await authService.createStaffAccountWithPassword({
    email: 'nurse.jane@cliniqnovva.rw',
    password: 'TempPass123!',
    name: 'Jane Uwimana',
    role: 'nurse',
    clinicId: 'org1',
    branchId: 'branch1',
    createdBy: 'adminUid',
  });

  const authUser = await auth.getUser(uid);
  assert.equal(authUser.disabled, false, 'a freshly created account must be enabled, not pending activation');
  assert.equal(authUser.customClaims.role, 'nurse');

  const userDoc = db.peek(`users/${uid}`);
  assert.equal(userDoc.isActive, true);
  assert.equal(userDoc.role, 'nurse');
  // There is no "status: pending" / "inviteToken" / "invitedAt" field anywhere on the
  // created record — direct creation has no intermediate state at all.
  assert.equal('status' in userDoc, false);
  assert.equal('inviteToken' in userDoc, false);
});

test('auth: account creation never touches any email/SMS-sending code path', async () => {
  // There is no email/SMS library in package.json at all (no nodemailer,
  // sendgrid, twilio, ses, etc — confirmed by inspecting backend/package.json
  // during the Part 18 security review), so creating an account structurally
  // CANNOT send anything. Only side effects: the Auth user and the /users
  // Firestore doc (the audit-log write this test used to also check for was
  // removed along with the rest of that feature, 2026-07-24).
  const { uid } = await authService.createStaffAccountWithPassword({
    email: 'doctor.paul@cliniqnovva.rw',
    password: 'TempPass456!',
    name: 'Dr. Paul Habimana',
    role: 'doctor',
    clinicId: 'org1',
    branchId: 'branch1',
    createdBy: 'adminUid',
  });

  const authUser = await auth.getUser(uid);
  assert.equal(authUser.email, 'doctor.paul@cliniqnovva.rw');
  const userDoc = db.peek(`users/${uid}`);
  assert.equal(userDoc.role, 'doctor');
});

test('auth: verifyToken lets an active user through and stamps req.user from the claims', async () => {
  const { uid } = await auth.createUser({ email: 'a@b.com', password: 'x', displayName: 'A' });
  await auth.setCustomUserClaims(uid, { role: 'doctor', clinicId: 'org1', branchId: 'branch1' });

  const req = { headers: { authorization: `Bearer ${uid}` } };
  const res = mockRes();
  let nextCalled = false;
  await verifyToken(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, true);
  assert.equal(req.user.role, 'doctor');
});

test('auth: verifyToken immediately rejects a token for a deactivated (disabled) account', async () => {
  const { uid } = await auth.createUser({ email: 'c@d.com', password: 'x', displayName: 'C' });
  await auth.setCustomUserClaims(uid, { role: 'receptionist', clinicId: 'org1', branchId: 'branch1' });
  await auth.updateUser(uid, { disabled: true }); // what staff.service.js#setStatus does on deactivation

  const req = { headers: { authorization: `Bearer ${uid}` } };
  const res = mockRes();
  let nextCalled = false;
  await verifyToken(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, false, 'a deactivated account must be blocked, not passed through');
  assert.equal(res.statusCode, 403);
  assert.match(res.body.error, /deactivated/i);
});

test('auth: verifyToken rejects requests with no bearer token at all', async () => {
  const req = { headers: {} };
  const res = mockRes();
  let nextCalled = false;
  await verifyToken(req, res, () => {
    nextCalled = true;
  });
  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 401);
});
