const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, reset, actor } = require('./support/setup');
const patientsService = require('../src/services/patients.service');

beforeEach(() => reset());

function seedPatientWithClinicalHistory() {
  db.seed('patients/patientA', {
    clinicId: 'org1',
    branchId: 'branch1',
    name: 'Alice Uwase',
    phone: '0780000001',
    isActive: true,
  });
  db.seed('medicalRecords/rec1', {
    patientId: 'patientA',
    diagnosis: 'Malaria',
    prescriptions: [{ drug: 'Coartem', dosage: '4 tabs BID' }],
    notes: 'Patient reports fever for 3 days.',
    vitals: { tempC: 38.9 },
    authorId: 'doc1',
    createdAt: '2027-01-01T09:00:00.000Z',
  });
}

test('patients: receptionist cannot retrieve clinical notes (medicalRecords/documents omitted entirely)', async () => {
  seedPatientWithClinicalHistory();
  const receptionist = actor({ role: 'receptionist', clinicId: 'org1', branchId: 'branch1' });

  const seenByReceptionist = await patientsService.getById('patientA', receptionist);

  assert.equal(seenByReceptionist.name, 'Alice Uwase');
  assert.equal('medicalRecords' in seenByReceptionist, false, 'medicalRecords key must be absent, not just empty');
  assert.equal('documents' in seenByReceptionist, false, 'documents key must be absent, not just empty');
});

test('patients: a doctor DOES see full clinical notes for the same patient (control case)', async () => {
  seedPatientWithClinicalHistory();
  const doctor = actor({ role: 'doctor', clinicId: 'org1', branchId: 'branch1' });

  const seenByDoctor = await patientsService.getById('patientA', doctor);

  assert.ok(Array.isArray(seenByDoctor.medicalRecords));
  assert.equal(seenByDoctor.medicalRecords[0].diagnosis, 'Malaria');
  assert.equal(seenByDoctor.medicalRecords[0].notes, 'Patient reports fever for 3 days.');
});

test('patients: branch data isolation — a branch-level user cannot read a patient from a different branch', async () => {
  seedPatientWithClinicalHistory();
  const branchAdminElsewhere = actor({ role: 'branch_admin', clinicId: 'org1', branchId: 'branch2' });

  await assert.rejects(
    () => patientsService.getById('patientA', branchAdminElsewhere),
    (err) => {
      assert.equal(err.status, 403);
      return true;
    }
  );
});

test('patients: branch data isolation — a user from a different clinic entirely is rejected too', async () => {
  seedPatientWithClinicalHistory();
  const outsideOrgAdmin = actor({ role: 'clinic_admin', clinicId: 'org2' });

  await assert.rejects(() => patientsService.getById('patientA', outsideOrgAdmin), (err) => {
    assert.equal(err.status, 403);
    return true;
  });
});

test('patients: merge preserves history — appointments/medicalRecords/invoices are reassigned, not lost', async () => {
  db.seed('patients/survivor', { clinicId: 'org1', branchId: 'branch1', name: 'Survivor Record', isActive: true });
  db.seed('patients/duplicate', { clinicId: 'org1', branchId: 'branch1', name: 'Duplicate Record', isActive: true });
  db.seed('appointments/appt1', { patientId: 'duplicate', clinicId: 'org1', branchId: 'branch1', status: 'completed' });
  db.seed('medicalRecords/rec1', { patientId: 'duplicate', diagnosis: 'Flu' });
  db.seed('invoices/inv1', { patientId: 'duplicate', totalAmountRwf: 5000 });

  const admin = actor({ role: 'clinic_admin', clinicId: 'org1' });
  const result = await patientsService.mergePatients({ survivingPatientId: 'survivor', mergedPatientId: 'duplicate' }, admin);

  assert.deepEqual(result.reassignedCounts, { appointments: 1, medicalRecords: 1, invoices: 1 });
  assert.equal(db.peek('appointments/appt1').patientId, 'survivor');
  assert.equal(db.peek('medicalRecords/rec1').patientId, 'survivor');
  assert.equal(db.peek('invoices/inv1').patientId, 'survivor');

  // The merged-away record is deactivated, never deleted — its history stays reachable.
  const mergedRecord = db.peek('patients/duplicate');
  assert.equal(mergedRecord.isActive, false);
  assert.equal(mergedRecord.mergedInto, 'survivor');
  assert.ok(db.peek('patients/duplicate'), 'merged patient document must still exist (soft-merge, not deleted)');

  const mergeLogs = await db.collection('patientMergeLogs').get();
  assert.equal(mergeLogs.size, 1);
  assert.equal(mergeLogs.docs[0].data().survivingPatientId, 'survivor');
  assert.equal(mergeLogs.docs[0].data().mergedPatientId, 'duplicate');
});
