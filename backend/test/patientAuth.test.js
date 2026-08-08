// Part 19 — Patient App self-registration: attachScope's new patient
// branch, cross-clinic checkDuplicate, linkPatientAccount, and the two new
// /api/auth/patient/* controller endpoints. Mirrors the DONE CONDITION
// "test both paths explicitly with a phone number that already exists in
// Firestore and one that doesn't" — this suite is the actual verification
// for that, since there's no way to drive a real Firebase project + a
// mobile emulator from this environment (see docs/known-issues.md).
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, reset } = require('./support/setup');
const patientsService = require('../src/services/patients.service');
const authService = require('../src/services/auth.service');
const authController = require('../src/controllers/auth.controller');
const { attachScope } = require('../src/middleware/branchScope.middleware');

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

async function makePatientUser() {
  const { uid } = await auth.createUser({ email: `p${Date.now()}@x.com`, password: 'x', displayName: 'P' });
  return uid;
}

test('attachScope: a patient-role request is not rejected for lacking a clinicId', async () => {
  const req = { user: { role: 'patient' } };
  const res = mockRes();
  let nextCalled = false;
  await attachScope(req, res, () => {
    nextCalled = true;
  });
  assert.equal(nextCalled, true);
  assert.equal(req.scope.level, 'patient');
  assert.equal(res.statusCode, null, 'must not 403');
});

test('attachScope: a branch-level role (e.g. receptionist) still requires a clinicId, unchanged', async () => {
  const req = { user: { role: 'receptionist', clinicId: undefined, branchId: undefined } };
  const res = mockRes();
  let nextCalled = false;
  await attachScope(req, res, () => {
    nextCalled = true;
  });
  assert.equal(nextCalled, false);
  assert.equal(res.statusCode, 403);
});

test('checkDuplicate: staff (clinic-scoped) path is unaffected by the cross-clinic addition', async () => {
  db.seed('patients/walkin1', { clinicId: 'org1', name: 'Alice', phone: '0780000001', phoneDigits: '0780000001', isActive: true });
  const matches = await patientsService.checkDuplicate({ clinicId: 'org1', phone: '0780000001' });
  assert.equal(matches.length, 1);
  assert.equal(matches[0].id, 'walkin1');
  // Staff already know their own clinic — clinicName isn't resolved for the scoped call.
  assert.equal('clinicName' in matches[0], false);
});

test('checkDuplicate: cross-clinic (no clinicId) finds a match at another clinic and resolves its name', async () => {
  db.seed('clinics/org1', { name: 'Ya Clinic' });
  db.seed('patients/walkin1', { clinicId: 'org1', name: 'Alice Uwase', phone: '0780000001', phoneDigits: '0780000001', isActive: true });

  const matches = await patientsService.checkDuplicate({ phone: '0780000001' });

  assert.equal(matches.length, 1);
  assert.equal(matches[0].id, 'walkin1');
  assert.equal(matches[0].clinicId, 'org1');
  assert.equal(matches[0].clinicName, 'Ya Clinic');
});

test('checkDuplicate: a phone number with no existing record anywhere returns no matches', async () => {
  db.seed('patients/walkin1', { clinicId: 'org1', name: 'Alice', phone: '0780000001', phoneDigits: '0780000001', isActive: true });
  const matches = await patientsService.checkDuplicate({ phone: '0789999999' });
  assert.deepEqual(matches, []);
});

test('checkDuplicate: excludes merged-away (isActive: false) records from cross-clinic results too', async () => {
  db.seed('clinics/org1', { name: 'Ya Clinic' });
  db.seed('patients/merged1', { clinicId: 'org1', name: 'Old', phone: '0780000002', phoneDigits: '0780000002', isActive: false });
  const matches = await patientsService.checkDuplicate({ phone: '0780000002' });
  assert.deepEqual(matches, []);
});

test('linkPatientAccount: matching phone links successfully and sets linkedAppAccountId', async () => {
  db.seed('patients/walkin1', { clinicId: 'org1', name: 'Alice Uwase', phone: '0780000001', phoneDigits: '0780000001', isActive: true });
  const uid = await makePatientUser();

  const linked = await patientsService.linkPatientAccount({ patientId: 'walkin1', uid, phone: '0780000001' });

  assert.equal(linked.linkedAppAccountId, uid);
  assert.equal(db.peek('patients/walkin1').linkedAppAccountId, uid);
  // registeredVia is untouched — linking doesn't change how the record originated.
  assert.equal('registeredVia' in db.peek('patients/walkin1'), false);
});

test('linkPatientAccount: rejects when the submitted phone/nationalId does not actually match the target record', async () => {
  db.seed('patients/walkin1', { clinicId: 'org1', name: 'Alice Uwase', phone: '0780000001', phoneDigits: '0780000001', isActive: true });
  const uid = await makePatientUser();

  await assert.rejects(
    () => patientsService.linkPatientAccount({ patientId: 'walkin1', uid, phone: '0799999999' }),
    (err) => {
      assert.equal(err.status, 403);
      return true;
    }
  );
  assert.equal('linkedAppAccountId' in db.peek('patients/walkin1'), false);
});

test('linkPatientAccount: 404s for a patientId that does not exist', async () => {
  const uid = await makePatientUser();
  await assert.rejects(
    () => patientsService.linkPatientAccount({ patientId: 'nope', uid, phone: '0780000001' }),
    (err) => {
      assert.equal(err.status, 404);
      return true;
    }
  );
});

test('registerPatientAccount: sets the patient custom claim (no clinicId/branchId) and writes /users/{uid}', async () => {
  const uid = await makePatientUser();

  await authService.registerPatientAccount({
    uid,
    name: 'Alice Uwase',
    phone: '0780000009',
    preferredLanguage: 'rw',
  });

  const authUser = await auth.getUser(uid);
  assert.equal(authUser.customClaims.role, 'patient');
  assert.equal(authUser.customClaims.clinicId, null);
  assert.equal(authUser.customClaims.branchId, null);

  const userDoc = db.peek(`users/${uid}`);
  assert.equal(userDoc.role, 'patient');
  assert.equal(userDoc.name, 'Alice Uwase');
  assert.equal(userDoc.preferredLanguage, 'rw');
  assert.equal(userDoc.isActive, true);
});

test('POST /api/auth/patient/finalize-registration: "no match" path creates the account with no linked patient', async () => {
  const uid = await makePatientUser();
  const req = { user: { uid }, body: { name: 'Brand New Patient', phone: '0788888888', preferredLanguage: 'en' } };
  const res = mockRes();

  await authController.finalizePatientRegistration(req, res, () => {});

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.success, true);
  assert.equal(res.body.linkedPatientId, null);
  assert.equal(db.peek(`users/${uid}`).role, 'patient');
});

test('POST /api/auth/patient/finalize-registration: "yes, link" path links the walk-in record and mirrors it onto /users', async () => {
  db.seed('patients/walkin1', { clinicId: 'org1', name: 'Alice Uwase', phone: '0780000001', phoneDigits: '0780000001', isActive: true });
  const uid = await makePatientUser();
  const req = {
    user: { uid },
    body: { name: 'Alice Uwase', phone: '0780000001', preferredLanguage: 'rw', linkPatientId: 'walkin1' },
  };
  const res = mockRes();

  await authController.finalizePatientRegistration(req, res, () => {});

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.linkedPatientId, 'walkin1');
  assert.equal(db.peek('patients/walkin1').linkedAppAccountId, uid);
  assert.deepEqual(db.peek(`users/${uid}`).linkedPatientIds, ['walkin1']);
});

test('POST /api/auth/patient/finalize-registration: rejects a linkPatientId that does not match the submitted phone (tampered request)', async () => {
  db.seed('patients/walkin1', { clinicId: 'org1', name: 'Alice Uwase', phone: '0780000001', phoneDigits: '0780000001', isActive: true });
  const uid = await makePatientUser();
  const req = {
    user: { uid },
    body: { name: 'Someone Else', phone: '0799999999', linkPatientId: 'walkin1' },
  };
  const res = mockRes();
  let errPassed = null;

  await authController.finalizePatientRegistration(req, res, (err) => {
    errPassed = err;
  });

  assert.ok(errPassed);
  assert.equal(errPassed.status, 403);
});

test('POST /api/auth/patient/check-duplicate: requires phone or nationalId', async () => {
  const req = { user: { uid: 'u1' }, body: {} };
  const res = mockRes();
  await authController.checkPatientDuplicate(req, res, () => {});
  assert.equal(res.statusCode, 400);
});

test('POST /api/auth/patient/check-duplicate: returns matches with clinic name for an existing phone', async () => {
  db.seed('clinics/org1', { name: 'Ya Clinic' });
  db.seed('patients/walkin1', { clinicId: 'org1', name: 'Alice Uwase', phone: '0780000001', phoneDigits: '0780000001', isActive: true });
  const req = { user: { uid: 'u1' }, body: { phone: '0780000001' } };
  const res = mockRes();

  await authController.checkPatientDuplicate(req, res, () => {});

  assert.equal(res.statusCode, null); // res.json() was called, no explicit status override (200 default)
  assert.equal(res.body.matches.length, 1);
  assert.equal(res.body.matches[0].clinicName, 'Ya Clinic');
});

test('POST /api/auth/patient/check-duplicate: a phone with no match anywhere returns an empty array', async () => {
  const req = { user: { uid: 'u1' }, body: { phone: '0700000000' } };
  const res = mockRes();
  await authController.checkPatientDuplicate(req, res, () => {});
  assert.deepEqual(res.body.matches, []);
});
