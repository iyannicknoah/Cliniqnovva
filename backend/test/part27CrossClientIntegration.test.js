// Part 27 Task 1 — cross-client integration tests. The Patient App and the
// web Admin Dashboard are two separate Flutter clients sharing one backend
// and one Firestore; this suite proves the seven Part 27 scenarios by
// calling one actor's controller/service function, then a second actor's,
// against the SAME shared in-memory `db` from test/support/setup.js — same
// technique every prior part (19-26) has used for "does the other side see
// this", since there's no way to drive two real logged-in Flutter clients
// against a real Firebase project from this environment (the frontend
// Firebase project mismatch documented in docs/known-issues.md means no
// account can log into either LIVE app yet, so this is the actual
// verification for Task 1's cross-client claims, not a live end-to-end run).
//
// Four of the seven scenarios already have direct coverage elsewhere and are
// not duplicated here — see the comment above each skipped scenario below:
//   2. Simultaneous double-booking of the last slot  -> test/patientBooking.test.js
//      ("the existing double-booking transaction still rejects a taken slot")
//   3. Cancel from the app -> web sees it + existing notification fires -> test/patientBooking.test.js
//      ("can cancel their own appointment, and it fires a clinic notification")
//   5. Staff replies to a chat -> patient notified                      -> test/patientChat.test.js
//   5b. Staff replies to a review -> patient notified                   -> test/reviews.test.js
//      ("reviews.reply(): fires notifyReviewReply")
// This file covers the remaining three, which had no direct multi-actor test:
//   1. Book from the app -> appears correctly on the web dashboard
//   4. Doctor adds a diagnosis on the web -> patient sees it, and ONLY their own, in the app
//   6. A walk-in patient (staff-created) later self-registers on the app with the same
//      phone -> offered to link, not duplicated
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, reset } = require('./support/setup');
const patientsService = require('../src/services/patients.service');
const appointmentsController = require('../src/controllers/appointments.controller');
const patientsController = require('../src/controllers/patients.controller');
const authController = require('../src/controllers/auth.controller');

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
  res.send = () => res;
  return res;
}

async function makePatientUser(profile = {}) {
  const { uid } = await auth.createUser({ email: `p${Date.now()}${Math.random()}@x.com`, password: 'x', displayName: 'P' });
  await db.collection('users').doc(uid).set({
    role: 'patient',
    name: 'Alice Uwase',
    phone: '0780000001',
    phoneDigits: '0780000001',
    linkedPatientIds: [],
    ...profile,
  });
  return uid;
}

function patientReq({ uid, body = {}, params = {}, query = {} }) {
  return { user: { uid, role: 'patient' }, scope: { level: 'patient' }, body, params, query };
}

// A branch-scoped web-dashboard staff actor, e.g. a Receptionist viewing
// their branch's appointment list — the "web dashboard" side of every
// scenario below.
function staffReq({ uid = 'receptionist1', role = 'receptionist', clinicId = 'org1', branchId = 'branch1', body = {}, params = {}, query = {} }) {
  return { user: { uid, role }, scope: { level: 'branch', clinicId, branchId }, body, params, query };
}

function seedBookable() {
  db.seed('doctors/doc1', {
    schedule: [{ day: 'monday', startTime: '08:00', endTime: '12:00', slotDurationMins: 15 }],
    blockedSlots: [],
  });
  db.seed('branches/branch1', { clinicId: 'org1', umugandaSaturdayHours: null, holidayOverrides: [] });
  db.seed('services/svc1', { defaultDurationMins: 15, defaultPriceRwf: 5000, name: 'Consultation' });
}

// --- Scenario 1: Book from the app -> appears correctly on the web dashboard ---

test('cross-client: an appointment booked from the app is visible, with the right details, via the web dashboard\'s own list endpoint', async () => {
  seedBookable();
  const uid = await makePatientUser({ name: 'Alice Uwase' });

  const bookRes = mockRes();
  await appointmentsController.book(
    patientReq({
      uid,
      body: { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', serviceId: 'svc1', date: '2027-01-04', startTime: '09:00', endTime: '09:15' },
    }),
    bookRes,
    (err) => { throw err; }
  );
  assert.equal(bookRes.statusCode, 201);
  const apptId = bookRes.body.appointment.id;

  // Same appointment, viewed as staff through the web dashboard's own
  // appointments list for that branch.
  const listRes = mockRes();
  await appointmentsController.list(staffReq({ query: {} }), listRes, (err) => { throw err; });

  assert.equal(listRes.body.appointments.length, 1);
  const seenByStaff = listRes.body.appointments[0];
  assert.equal(seenByStaff.id, apptId);
  assert.equal(seenByStaff.doctorId, 'doc1');
  assert.equal(seenByStaff.date, '2027-01-04');
  assert.equal(seenByStaff.startTime, '09:00');
  assert.equal(seenByStaff.status, 'pending');

  // And staff's own getById agrees with what the patient got back at booking time.
  const getRes = mockRes();
  await appointmentsController.getById(staffReq({ params: { id: apptId } }), getRes, (err) => { throw err; });
  assert.equal(getRes.body.appointment.patientId, bookRes.body.appointment.patientId);
});

// --- Scenario 4: Doctor adds a diagnosis on the web -> patient sees it, and ONLY their own, in the app ---

test('cross-client: a diagnosis a doctor adds on the web dashboard shows up in the app\'s Medical Records for the right patient only', async () => {
  const uidA = await makePatientUser({ name: 'Alice Uwase', phone: '0780000001', phoneDigits: '0780000001' });
  const uidB = await makePatientUser({ name: 'Beatrice Mukamana', phone: '0780000002', phoneDigits: '0780000002' });

  // Each patient gets their own walk-in-style /patients record for the
  // clinic, same as a real booking would provision (Part 21).
  const recordA = await patientsService.getOrCreatePatientRecordForClinic({ uid: uidA, clinicId: 'org1', branchId: 'branch1' });
  const recordB = await patientsService.getOrCreatePatientRecordForClinic({ uid: uidB, clinicId: 'org1', branchId: 'branch1' });

  const doctorActor = { actorId: 'doc1', role: 'doctor', actorRole: 'doctor', scope: { level: 'branch', clinicId: 'org1', branchId: 'branch1' } };
  await patientsService.addMedicalRecord(recordA.id, { diagnosis: 'Malaria', notes: 'Rest and fluids' }, doctorActor);
  await patientsService.addMedicalRecord(recordB.id, { diagnosis: 'Sprained ankle', notes: 'Ice and elevate' }, doctorActor);

  const seenByA = await patientsService.getMedicalRecordsAndDocumentsForPatient(recordA.id, uidA);
  assert.equal(seenByA.records.length, 1);
  assert.equal(seenByA.records[0].diagnosis, 'Malaria');

  const seenByB = await patientsService.getMedicalRecordsAndDocumentsForPatient(recordB.id, uidB);
  assert.equal(seenByB.records.length, 1);
  assert.equal(seenByB.records[0].diagnosis, 'Sprained ankle');

  // Patient A can never read patient B's record, even by guessing the id.
  await assert.rejects(
    () => patientsService.getMedicalRecordsAndDocumentsForPatient(recordB.id, uidA),
    (err) => {
      assert.equal(err.status, 403);
      return true;
    }
  );
});

// --- Scenario 6: a staff-created walk-in later self-registers on the app with the same phone ---

test('cross-client: a walk-in patient created by Receptionist is offered a link (not duplicated) when they later self-register with the same phone', async () => {
  db.seed('clinics/org1', { name: 'Kigali Family Clinic' });

  // Staff side (web dashboard): Receptionist registers a walk-in.
  const createRes = mockRes();
  await patientsController.create(
    staffReq({ body: { name: 'Claudine Ingabire', phone: '0788123456', dateOfBirth: '1990-01-01', gender: 'female' } }),
    createRes,
    (err) => { throw err; }
  );
  assert.equal(createRes.statusCode, 201);
  const walkInId = createRes.body.patient.id;

  // App side: the same person later installs the app and registers with
  // the same phone number. The Flutter client always calls check-duplicate
  // right after creating the Firebase Auth account, before finalizing.
  const uid = await makePatientUser({ phone: '0788123456', phoneDigits: '0788123456' });
  const dupRes = mockRes();
  await authController.checkPatientDuplicate({ user: { uid }, body: { phone: '0788123456' } }, dupRes, (err) => { throw err; });

  assert.equal(dupRes.body.matches.length, 1);
  assert.equal(dupRes.body.matches[0].id, walkInId);
  assert.equal(dupRes.body.matches[0].clinicName, 'Kigali Family Clinic');

  // Patient confirms "yes, this is me" -> finalize-registration links
  // rather than creating a second record.
  const finalizeRes = mockRes();
  await authController.finalizePatientRegistration(
    { user: { uid }, body: { name: 'Claudine Ingabire', phone: '0788123456', linkPatientId: walkInId } },
    finalizeRes,
    (err) => { throw err; }
  );
  assert.equal(finalizeRes.statusCode, 201);
  assert.equal(finalizeRes.body.linkedPatientId, walkInId);

  // Staff side confirms: still exactly one /patients record for this
  // clinic (no duplicate), now linked to the app account.
  const patientsForOrg1 = (await db.collection('patients').where('clinicId', '==', 'org1').get()).size;
  assert.equal(patientsForOrg1, 1);
  assert.equal(db.peek(`patients/${walkInId}`).linkedAppAccountId, uid);

  const getRes = mockRes();
  await patientsController.getById(staffReq({ params: { patientId: walkInId } }), getRes, (err) => { throw err; });
  assert.equal(getRes.body.patient.id, walkInId);
});
