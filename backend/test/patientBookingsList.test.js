// Part 22 Task 4 — GET /:patientId/appointments (My Bookings) and the
// GET /reviews?appointmentId= "already reviewed?" check it also relies on.
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, reset } = require('./support/setup');
const patientsController = require('../src/controllers/patients.controller');
const reviewsService = require('../src/services/reviews.service');

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

function seedAppointments() {
  db.seed('patients/walkin1', { clinicId: 'org1', branchId: 'branch1', linkedAppAccountId: 'patientUid1' });
  db.seed('appointments/apptUpcoming', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkin1',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date: '2027-06-01',
    startTime: '09:00',
    endTime: '09:15',
    status: 'confirmed',
  });
  db.seed('appointments/apptPast', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkin1',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date: '2020-01-01',
    startTime: '09:00',
    endTime: '09:15',
    status: 'completed',
  });
}

test('GET /:patientId/appointments — a patient caller sees their own linked record\'s appointments', async () => {
  seedAppointments();
  const req = { user: { uid: 'patientUid1', role: 'patient' }, scope: { level: 'patient' }, params: { patientId: 'walkin1' }, query: {} };
  const res = mockRes();

  await patientsController.getAppointments(req, res, () => {});

  assert.equal(res.statusCode, null); // 200 default
  assert.equal(res.body.appointments.length, 2);
});

test('GET /:patientId/appointments — a different patient account is rejected (403), not just filtered', async () => {
  seedAppointments();
  const req = { user: { uid: 'someoneElse', role: 'patient' }, scope: { level: 'patient' }, params: { patientId: 'walkin1' }, query: {} };
  const res = mockRes();

  await patientsController.getAppointments(req, res, () => {});

  assert.equal(res.statusCode, 403);
});

test('GET /:patientId/appointments — a receptionist from the same clinic can still read it (staff path unaffected)', async () => {
  seedAppointments();
  const req = {
    user: { uid: 'staff1', role: 'receptionist' },
    scope: { level: 'branch', clinicId: 'org1', branchId: 'branch1' },
    params: { patientId: 'walkin1' },
    query: {},
  };
  const res = mockRes();

  await patientsController.getAppointments(req, res, () => {});

  assert.equal(res.body.appointments.length, 2);
});

test('GET /:patientId/appointments — a branch_admin from a different branch is rejected', async () => {
  seedAppointments();
  const req = {
    user: { uid: 'staff2', role: 'branch_admin' },
    scope: { level: 'branch', clinicId: 'org1', branchId: 'branch2' },
    params: { patientId: 'walkin1' },
    query: {},
  };
  const res = mockRes();

  await patientsController.getAppointments(req, res, () => {});

  assert.equal(res.statusCode, 403);
});

test('GET /:patientId/appointments — 404s for a missing patient', async () => {
  const req = { user: { uid: 'p1', role: 'patient' }, scope: { level: 'patient' }, params: { patientId: 'missing' }, query: {} };
  const res = mockRes();

  await patientsController.getAppointments(req, res, () => {});

  assert.equal(res.statusCode, 404);
});

test('reviews.list({appointmentId}) — filters to just the one appointment\'s review, for the "already reviewed?" check', async () => {
  db.seed('reviews/r1', { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', appointmentId: 'apptPast', isHidden: false, createdAt: '2026-01-01T00:00:00.000Z' });
  db.seed('reviews/r2', { clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', appointmentId: 'apptOther', isHidden: false, createdAt: '2026-01-02T00:00:00.000Z' });

  const reviewed = await reviewsService.list({ clinicId: 'org1', appointmentId: 'apptPast' });
  assert.equal(reviewed.length, 1);
  assert.equal(reviewed[0].id, 'r1');

  const notReviewed = await reviewsService.list({ clinicId: 'org1', appointmentId: 'apptUpcoming' });
  assert.equal(notReviewed.length, 0);
});
