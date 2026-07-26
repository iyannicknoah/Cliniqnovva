// "Clinic suspension blocks access immediately" (Part 18 DONE
// CONDITION) is enforced by attachScope doing a LIVE Firestore read of
// clinics/{id}.isActive on every single request — not by anything
// token-based, so it can't be delayed by token caching the way staff
// deactivation could (see docs/security-review.md finding #5, fixed in
// verifyToken.js). This test exercises attachScope directly against a mock
// req/res/next, the same way Express would call it as middleware.
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, reset } = require('./support/setup');
const { attachScope } = require('../src/middleware/branchScope.middleware');
const clinicsService = require('../src/services/clinics.service');

beforeEach(() => reset());

function mockRes() {
  const res = { statusCode: null, body: null };
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (body) => {
    res.body = body;
    return res;
  };
  return res;
}

test('clinic suspension: an active clinic lets a branch-scoped user through', async () => {
  db.seed('clinics/org1', { isActive: true, name: 'Kigali Health' });
  const req = { user: { role: 'doctor', clinicId: 'org1', branchId: 'branch1' } };
  const res = mockRes();
  let nextCalled = false;

  await attachScope(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, true);
  assert.equal(res.statusCode, null);
  // clinicName (2026-07-26) — stashed onto req.scope from the same
  // Firestore read the suspension check above already does, so an
  // org-scoped receipt/PDF can show the clinic's own name instead of
  // "Cliniqnovva" without a second query or a new role-gated endpoint.
  assert.deepEqual(req.scope, {
    level: 'branch',
    clinicId: 'org1',
    branchId: 'branch1',
    clinicName: 'Kigali Health',
  });
});

test('clinic suspension: blocks EVERY org-scoped role immediately once isActive is false', async () => {
  db.seed('clinics/org1', { isActive: true, name: 'Kigali Health' });
  const req = { user: { role: 'clinic_admin', clinicId: 'org1' } };
  const res = mockRes();

  // Suspend the clinic — this is the actual write path Super Admin's
  // "suspend clinic" action uses.
  await clinicsService.setStatus('org1', false, 'superAdminUid');

  let nextCalled = false;
  await attachScope(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, false, 'the request must be blocked, not passed through');
  assert.equal(res.statusCode, 403);
  assert.match(res.body.error, /suspended/i);
});

test('clinic suspension: reactivating immediately restores access on the very next request', async () => {
  db.seed('clinics/org1', { isActive: false, name: 'Kigali Health' });
  const req = { user: { role: 'receptionist', clinicId: 'org1', branchId: 'branch1' } };

  const blocked = mockRes();
  await attachScope(req, blocked, () => {});
  assert.equal(blocked.statusCode, 403);

  await clinicsService.setStatus('org1', true, 'superAdminUid');

  const allowed = mockRes();
  let nextCalled = false;
  await attachScope(req, allowed, () => {
    nextCalled = true;
  });
  assert.equal(nextCalled, true);
});

test('clinic suspension: Super Admin is never org-scoped, so suspension can never lock them out', async () => {
  db.seed('clinics/org1', { isActive: false });
  const req = { user: { role: 'super_admin' } };
  const res = mockRes();
  let nextCalled = false;

  await attachScope(req, res, () => {
    nextCalled = true;
  });

  assert.equal(nextCalled, true);
  assert.deepEqual(req.scope, { level: 'platform' });
});
