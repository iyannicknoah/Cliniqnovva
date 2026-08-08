// Part 23 — Medical Records and Receipts (read-only for the patient).
// DONE CONDITION: "a patient can only ever retrieve their OWN medical
// records and invoices" — every test here either proves the happy path or
// proves a different patient's account is rejected, not just filtered.
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, reset } = require('./support/setup');
const patientsService = require('../src/services/patients.service');
const patientsController = require('../src/controllers/patients.controller');
const invoicesService = require('../src/services/invoices.service');

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
  const { uid } = await auth.createUser({ email: `p${Date.now()}${Math.random()}@x.com`, password: 'x', displayName: 'P' });
  return uid;
}

function seedRecordsAndDocs(uid) {
  db.seed('patients/walkin1', { clinicId: 'org1', branchId: 'branch1', linkedAppAccountId: uid });
  db.seed('medicalRecords/rec1', {
    patientId: 'walkin1',
    doctorId: 'doc1',
    diagnosis: 'Flu',
    prescriptions: [{ medicine: 'Paracetamol', dosage: '500mg', duration: '5 days' }],
    notes: 'Rest and fluids',
    vitals: { tempC: 38.2 },
    createdAt: '2026-01-01T00:00:00.000Z',
  });
  db.seed('medicalRecords/rec2', {
    patientId: 'walkin1',
    doctorId: 'doc1',
    diagnosis: 'Follow-up',
    prescriptions: [],
    notes: null,
    createdAt: '2026-02-01T00:00:00.000Z',
  });
  db.seed('patients/walkin1/documents/doc1', {
    key: 'patients/walkin1/documents/doc1-xray.png',
    originalName: 'xray.png',
    contentType: 'image/png',
    uploadedAt: '2026-01-01T01:00:00.000Z',
  });
}

test('getMedicalRecordsAndDocumentsForPatient: the owning patient sees their records + documents, newest first', async () => {
  const uid = await makePatientUser();
  seedRecordsAndDocs(uid);

  const result = await patientsService.getMedicalRecordsAndDocumentsForPatient('walkin1', uid);

  assert.equal(result.records.length, 2);
  assert.equal(result.records[0].id, 'rec2', 'newest record first');
  assert.equal(result.records[0].diagnosis, 'Follow-up');
  assert.equal(result.documents.length, 1);
  assert.equal(result.documents[0].originalName, 'xray.png');
});

test('getMedicalRecordsAndDocumentsForPatient: a different patient account is rejected, not just filtered', async () => {
  const uid = await makePatientUser();
  seedRecordsAndDocs(uid);
  const otherUid = await makePatientUser();

  await assert.rejects(
    () => patientsService.getMedicalRecordsAndDocumentsForPatient('walkin1', otherUid),
    (err) => {
      assert.equal(err.status, 403);
      return true;
    }
  );
});

test('getMedicalRecordsAndDocumentsForPatient: 404s for a missing patient', async () => {
  const uid = await makePatientUser();
  await assert.rejects(
    () => patientsService.getMedicalRecordsAndDocumentsForPatient('missing', uid),
    (err) => {
      assert.equal(err.status, 404);
      return true;
    }
  );
});

test('GET /:patientId/medical-records controller — rejects a non-owner (via next(err)), 200s the owner', async () => {
  const uid = await makePatientUser();
  seedRecordsAndDocs(uid);
  const otherUid = await makePatientUser();

  const badReq = { user: { uid: otherUid, role: 'patient' }, params: { patientId: 'walkin1' } };
  const badRes = mockRes();
  let errPassed = null;
  await patientsController.getMedicalRecords(badReq, badRes, (err) => {
    errPassed = err;
  });
  assert.ok(errPassed);
  assert.equal(errPassed.status, 403);

  const goodReq = { user: { uid, role: 'patient' }, params: { patientId: 'walkin1' } };
  const goodRes = mockRes();
  await patientsController.getMedicalRecords(goodReq, goodRes, () => {});
  assert.equal(goodRes.body.records.length, 2);
});

test('getDocumentSignedUrl: the owning patient gets a real signed URL + contentType/originalName', async () => {
  const uid = await makePatientUser();
  seedRecordsAndDocs(uid);

  const result = await patientsService.getDocumentSignedUrl(
    'walkin1',
    'patients/walkin1/documents/doc1-xray.png',
    { role: 'patient', actorId: uid, scope: { level: 'patient' } }
  );

  assert.equal(typeof result.url, 'string');
  assert.ok(result.url.length > 0);
  assert.equal(result.contentType, 'image/png');
  assert.equal(result.originalName, 'xray.png');
});

test('getDocumentSignedUrl: a different patient account is rejected — never a permanent/reused link for them', async () => {
  const uid = await makePatientUser();
  seedRecordsAndDocs(uid);
  const otherUid = await makePatientUser();

  await assert.rejects(
    () =>
      patientsService.getDocumentSignedUrl('walkin1', 'patients/walkin1/documents/doc1-xray.png', {
        role: 'patient',
        actorId: otherUid,
        scope: { level: 'patient' },
      }),
    (err) => {
      assert.equal(err.status, 403);
      return true;
    }
  );
});

test('getDocumentSignedUrl: staff (clinical role, correct clinic/branch) path is unaffected', async () => {
  const uid = await makePatientUser();
  seedRecordsAndDocs(uid);

  const result = await patientsService.getDocumentSignedUrl(
    'walkin1',
    'patients/walkin1/documents/doc1-xray.png',
    { role: 'doctor', actorId: 'staffDoc', scope: { level: 'branch', clinicId: 'org1', branchId: 'branch1' } }
  );
  assert.equal(typeof result.url, 'string');
});

test('getDocumentSignedUrl: a receptionist (non-clinical staff) is still rejected, unchanged', async () => {
  const uid = await makePatientUser();
  seedRecordsAndDocs(uid);

  await assert.rejects(
    () =>
      patientsService.getDocumentSignedUrl('walkin1', 'patients/walkin1/documents/doc1-xray.png', {
        role: 'receptionist',
        actorId: 'staffR',
        scope: { level: 'branch', clinicId: 'org1', branchId: 'branch1' },
      }),
    (err) => {
      assert.equal(err.status, 403);
      return true;
    }
  );
});

function seedInvoices(uid) {
  db.seed('patients/walkin1', { clinicId: 'org1', branchId: 'branch1', linkedAppAccountId: uid });
  db.seed('clinics/org1', { name: 'Kigali Central Clinic' });
  db.seed('invoices/inv1', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkin1',
    lineItems: [{ description: 'Consultation', amountRwf: 5000 }],
    totalAmountRwf: 5000,
    cashPaidAmountRwf: 2000,
    insuranceCoveredAmountRwf: 0,
    insuranceScheme: 'none',
    status: 'partial',
    createdAt: '2026-01-01T00:00:00.000Z',
  });
  db.seed('invoices/inv2', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkin1',
    lineItems: [{ description: 'X-Ray', amountRwf: 10000 }],
    totalAmountRwf: 10000,
    cashPaidAmountRwf: 3000,
    insuranceCoveredAmountRwf: 7000,
    insuranceScheme: 'mutuelle',
    status: 'paid',
    createdAt: '2026-02-01T00:00:00.000Z',
  });
}

test('invoicesService.listForPatient: returns this patient\'s invoices, newest first, with clinicName resolved', async () => {
  const uid = await makePatientUser();
  seedInvoices(uid);

  const invoices = await invoicesService.listForPatient('walkin1');

  assert.equal(invoices.length, 2);
  assert.equal(invoices[0].id, 'inv2');
  assert.equal(invoices[0].clinicName, 'Kigali Central Clinic');
  assert.equal(invoices[0].insuranceCoveredAmountRwf, 7000);
  assert.equal(invoices[1].cashPaidAmountRwf, 2000);
});

test('GET /:patientId/invoices controller — a different patient account is rejected, the owner sees the cash/insurance split', async () => {
  const uid = await makePatientUser();
  seedInvoices(uid);
  const otherUid = await makePatientUser();

  const badReq = { user: { uid: otherUid, role: 'patient' }, params: { patientId: 'walkin1' } };
  const badRes = mockRes();
  await patientsController.getInvoices(badReq, badRes, () => {});
  assert.equal(badRes.statusCode, 403);

  const goodReq = { user: { uid, role: 'patient' }, params: { patientId: 'walkin1' } };
  const goodRes = mockRes();
  await patientsController.getInvoices(goodReq, goodRes, () => {});
  assert.equal(goodRes.body.invoices.length, 2);
  const paid = goodRes.body.invoices.find((inv) => inv.id === 'inv2');
  assert.equal(paid.cashPaidAmountRwf, 3000);
  assert.equal(paid.insuranceCoveredAmountRwf, 7000);
  assert.equal(paid.insuranceScheme, 'mutuelle');
});

test('GET /:patientId/invoices controller — 404s for a missing patient', async () => {
  const uid = await makePatientUser();
  const req = { user: { uid, role: 'patient' }, params: { patientId: 'missing' } };
  const res = mockRes();
  await patientsController.getInvoices(req, res, () => {});
  assert.equal(res.statusCode, 404);
});
