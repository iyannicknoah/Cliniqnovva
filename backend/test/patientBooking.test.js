// Part 21 — Patient App booking/reschedule/cancel. Tests the
// controller-level request-shaping (patientId resolution, ownership checks)
// added on top of the UNCHANGED appointments.service.js transaction logic —
// same mockRes() controller-testing pattern as test/patientAuth.test.js,
// since this logic lives in the controller, not something service-level
// tests alone would exercise.
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, reset, actor } = require('./support/setup');
const patientsService = require('../src/services/patients.service');
const appointmentsController = require('../src/controllers/appointments.controller');
const departmentsController = require('../src/controllers/departments.controller');
const servicesController = require('../src/controllers/services.controller');

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

function seedBookable() {
  db.seed('doctors/doc1', {
    schedule: [{ day: 'monday', startTime: '08:00', endTime: '12:00', slotDurationMins: 15 }],
    blockedSlots: [],
  });
  db.seed('branches/branch1', { clinicId: 'org1', umugandaSaturdayHours: null, holidayOverrides: [] });
  db.seed('services/svc1', { defaultDurationMins: 15, defaultPriceRwf: 5000, name: 'Consultation' });
}

// --- patients.service.js: record resolution -------------------------------

test('getOrCreatePatientRecordForClinic: creates a fresh app-originated record on first call', async () => {
  const uid = await makePatientUser();
  const record = await patientsService.getOrCreatePatientRecordForClinic({ uid, clinicId: 'org1', branchId: 'branch1' });

  assert.equal(record.registeredVia, 'app');
  assert.equal(record.linkedAppAccountId, uid);
  assert.equal(record.name, 'Alice Uwase');
  assert.deepEqual(db.peek(`users/${uid}`).linkedPatientIds, [record.id]);
});

test('getOrCreatePatientRecordForClinic: a second call for the same clinic reuses the same record', async () => {
  const uid = await makePatientUser();
  const first = await patientsService.getOrCreatePatientRecordForClinic({ uid, clinicId: 'org1', branchId: 'branch1' });
  const second = await patientsService.getOrCreatePatientRecordForClinic({ uid, clinicId: 'org1', branchId: 'branch2' });

  assert.equal(second.id, first.id);
  const patientsForOrg1 = (await db.collection('patients').where('clinicId', '==', 'org1').get()).size;
  assert.equal(patientsForOrg1, 1);
});

test('getOrCreatePatientRecordForClinic: a linked walk-in record from registration is reused, not duplicated', async () => {
  db.seed('patients/walkin1', { clinicId: 'org1', name: 'Alice Uwase', isActive: true, linkedAppAccountId: 'preset' });
  const uid = await makePatientUser({ linkedPatientIds: ['walkin1'] });

  const record = await patientsService.getOrCreatePatientRecordForClinic({ uid, clinicId: 'org1', branchId: 'branch1' });

  assert.equal(record.id, 'walkin1');
  const patientsForOrg1 = (await db.collection('patients').where('clinicId', '==', 'org1').get()).size;
  assert.equal(patientsForOrg1, 1);
});

test('isPatientRecordOwnedBy: true only when linkedAppAccountId matches', async () => {
  db.seed('patients/p1', { linkedAppAccountId: 'uidA' });
  assert.equal(await patientsService.isPatientRecordOwnedBy('p1', 'uidA'), true);
  assert.equal(await patientsService.isPatientRecordOwnedBy('p1', 'uidB'), false);
  assert.equal(await patientsService.isPatientRecordOwnedBy('missing', 'uidA'), false);
});

// --- appointments.controller.js: book() ------------------------------------

test('appointments.book (patient): resolves patientId server-side, ignoring a spoofed patientId in the body', async () => {
  seedBookable();
  const uid = await makePatientUser();
  const req = patientReq({
    uid,
    body: {
      clinicId: 'org1',
      branchId: 'branch1',
      doctorId: 'doc1',
      serviceId: 'svc1',
      date: '2027-01-04', // a Monday
      startTime: '09:00',
      endTime: '09:15',
      patientId: 'someone-elses-record', // must be ignored
    },
  });
  const res = mockRes();

  await appointmentsController.book(req, res, (err) => {
    throw err;
  });

  assert.equal(res.statusCode, 201);
  assert.notEqual(res.body.appointment.patientId, 'someone-elses-record');
  const ownRecord = db.peek(`users/${uid}`).linkedPatientIds[0];
  assert.equal(res.body.appointment.patientId, ownRecord);
});

test('appointments.book (patient): a second booking at the same clinic reuses the same patient record', async () => {
  seedBookable();
  const uid = await makePatientUser();
  const req1 = patientReq({
    uid,
    body: { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', serviceId: 'svc1', date: '2027-01-04', startTime: '09:00', endTime: '09:15' },
  });
  const res1 = mockRes();
  await appointmentsController.book(req1, res1, (err) => { throw err; });

  const req2 = patientReq({
    uid,
    body: { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', serviceId: 'svc1', date: '2027-01-04', startTime: '09:15', endTime: '09:30' },
  });
  const res2 = mockRes();
  await appointmentsController.book(req2, res2, (err) => { throw err; });

  assert.equal(res1.body.appointment.patientId, res2.body.appointment.patientId);
});

test('appointments.book (patient): the existing double-booking transaction still rejects a taken slot', async () => {
  seedBookable();
  const uidA = await makePatientUser();
  const uidB = await makePatientUser();
  const args = { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', serviceId: 'svc1', date: '2027-01-04', startTime: '09:00', endTime: '09:15' };

  const res1 = mockRes();
  await appointmentsController.book(patientReq({ uid: uidA, body: args }), res1, (err) => { throw err; });
  assert.equal(res1.statusCode, 201);

  let caught = null;
  const res2 = mockRes();
  await appointmentsController.book(patientReq({ uid: uidB, body: args }), res2, (err) => { caught = err; });
  assert.ok(caught);
  assert.equal(caught.status, 409);
});

// --- appointments.controller.js: setStatus() (cancel) ----------------------

test('appointments.setStatus (patient): can cancel their own appointment, and it fires a clinic notification', async () => {
  seedBookable();
  db.seed('users/receptionist1', { role: 'receptionist', clinicId: 'org1', branchId: 'branch1', isActive: true });
  const uid = await makePatientUser();
  const bookRes = mockRes();
  await appointmentsController.book(
    patientReq({ uid, body: { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', serviceId: 'svc1', date: '2027-01-04', startTime: '09:00', endTime: '09:15' } }),
    bookRes,
    (err) => { throw err; }
  );
  const apptId = bookRes.body.appointment.id;

  const res = mockRes();
  await appointmentsController.setStatus(
    patientReq({ uid, params: { id: apptId }, body: { status: 'cancelled' } }),
    res,
    (err) => { throw err; }
  );

  assert.equal(res.body.appointment.status, 'cancelled');
  const notifs = (await db.collection('notifications').get()).docs.map((d) => d.data());
  assert.ok(notifs.some((n) => n.recipientId === 'receptionist1' && n.type === 'appointmentCancelled'));
  assert.ok(notifs.some((n) => n.recipientId === 'doc1' && n.type === 'appointmentCancelled'));
});

test('appointments.setStatus (patient): cannot set any status other than cancelled', async () => {
  seedBookable();
  const uid = await makePatientUser();
  const bookRes = mockRes();
  await appointmentsController.book(
    patientReq({ uid, body: { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', serviceId: 'svc1', date: '2027-01-04', startTime: '09:00', endTime: '09:15' } }),
    bookRes,
    (err) => { throw err; }
  );

  const res = mockRes();
  await appointmentsController.setStatus(
    patientReq({ uid, params: { id: bookRes.body.appointment.id }, body: { status: 'confirmed' } }),
    res,
    (err) => { throw err; }
  );
  assert.equal(res.statusCode, 403);
});

test('appointments.setStatus (patient): cannot cancel an appointment that is not theirs', async () => {
  seedBookable();
  const owner = await makePatientUser();
  const intruder = await makePatientUser();
  const bookRes = mockRes();
  await appointmentsController.book(
    patientReq({ uid: owner, body: { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', serviceId: 'svc1', date: '2027-01-04', startTime: '09:00', endTime: '09:15' } }),
    bookRes,
    (err) => { throw err; }
  );

  let caught = null;
  const res = mockRes();
  await appointmentsController.setStatus(
    patientReq({ uid: intruder, params: { id: bookRes.body.appointment.id }, body: { status: 'cancelled' } }),
    res,
    (err) => { caught = err; }
  );
  assert.ok(caught);
  assert.equal(caught.status, 403);
});

// --- appointments.controller.js: reschedule() -------------------------------

test('appointments.reschedule (patient): can reschedule their own appointment and it re-validates availability', async () => {
  seedBookable();
  db.seed('users/receptionist1', { role: 'receptionist', clinicId: 'org1', branchId: 'branch1', isActive: true });
  const uid = await makePatientUser();
  const bookRes = mockRes();
  await appointmentsController.book(
    patientReq({ uid, body: { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', serviceId: 'svc1', date: '2027-01-04', startTime: '09:00', endTime: '09:15' } }),
    bookRes,
    (err) => { throw err; }
  );
  const apptId = bookRes.body.appointment.id;

  const res = mockRes();
  await appointmentsController.reschedule(
    patientReq({ uid, params: { id: apptId }, body: { date: '2027-01-04', startTime: '10:00', endTime: '10:15' } }),
    res,
    (err) => { throw err; }
  );

  assert.equal(res.body.appointment.startTime, '10:00');
  const notifs = (await db.collection('notifications').get()).docs.map((d) => d.data());
  assert.ok(notifs.some((n) => n.recipientId === 'receptionist1' && n.type === 'appointmentRescheduled'));
});

test('appointments.reschedule (patient): cannot reschedule someone else\'s appointment', async () => {
  seedBookable();
  const owner = await makePatientUser();
  const intruder = await makePatientUser();
  const bookRes = mockRes();
  await appointmentsController.book(
    patientReq({ uid: owner, body: { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', serviceId: 'svc1', date: '2027-01-04', startTime: '09:00', endTime: '09:15' } }),
    bookRes,
    (err) => { throw err; }
  );

  let caught = null;
  const res = mockRes();
  await appointmentsController.reschedule(
    patientReq({ uid: intruder, params: { id: bookRes.body.appointment.id }, body: { date: '2027-01-04', startTime: '10:00', endTime: '10:15' } }),
    res,
    (err) => { caught = err; }
  );
  assert.ok(caught);
  assert.equal(caught.status, 403);
});

// --- appointments.controller.js: getById() ----------------------------------

test('appointments.getById (patient): can view their own appointment, not someone else\'s', async () => {
  seedBookable();
  const owner = await makePatientUser();
  const intruder = await makePatientUser();
  const bookRes = mockRes();
  await appointmentsController.book(
    patientReq({ uid: owner, body: { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', serviceId: 'svc1', date: '2027-01-04', startTime: '09:00', endTime: '09:15' } }),
    bookRes,
    (err) => { throw err; }
  );
  const apptId = bookRes.body.appointment.id;

  const okRes = mockRes();
  await appointmentsController.getById(patientReq({ uid: owner, params: { id: apptId } }), okRes, (err) => { throw err; });
  assert.equal(okRes.body.appointment.id, apptId);

  let caught = null;
  const forbiddenRes = mockRes();
  await appointmentsController.getById(patientReq({ uid: intruder, params: { id: apptId } }), forbiddenRes, (err) => { caught = err; });
  assert.ok(caught);
  assert.equal(caught.status, 403);
});

// --- departments/services: patient scope no longer 400s/403s ---------------

test('departments.list / services.list (patient): clinicId is trusted from the query string, not discarded', async () => {
  db.seed('departments/dept1', { clinicId: 'org1', branchId: 'branch1', name: 'Dentistry', isActive: true });
  db.seed('services/svc1', { clinicId: 'org1', branchId: 'branch1', departmentId: 'dept1', name: 'Cleaning', defaultDurationMins: 30, defaultPriceRwf: 5000, isActive: true });
  const req1 = { scope: { level: 'patient' }, query: { clinicId: 'org1' }, user: { role: 'patient' } };
  const res1 = mockRes();
  await departmentsController.list(req1, res1, (err) => { throw err; });
  assert.equal(res1.body.departments.length, 1);

  const req2 = { scope: { level: 'patient' }, query: { clinicId: 'org1' }, user: { role: 'patient' } };
  const res2 = mockRes();
  await servicesController.list(req2, res2, (err) => { throw err; });
  assert.equal(res2.body.services.length, 1);
});

test('departments.getById / services.getById (patient): no longer always 403s', async () => {
  db.seed('departments/dept1', { clinicId: 'org1', branchId: 'branch1', name: 'Dentistry', isActive: true });
  db.seed('services/svc1', { clinicId: 'org1', branchId: 'branch1', departmentId: 'dept1', name: 'Cleaning', defaultDurationMins: 30, defaultPriceRwf: 5000, isActive: true });

  const res1 = mockRes();
  await departmentsController.getById({ scope: { level: 'patient' }, params: { id: 'dept1' }, user: { role: 'patient' } }, res1, (err) => { throw err; });
  assert.equal(res1.body.department.id, 'dept1');

  const res2 = mockRes();
  await servicesController.getById({ scope: { level: 'patient' }, params: { id: 'svc1' }, user: { role: 'patient' } }, res2, (err) => { throw err; });
  assert.equal(res2.body.service.id, 'svc1');
});
