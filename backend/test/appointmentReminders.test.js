// Part 22 Task 3/DONE CONDITIONS — the hourly reminder job
// (appointmentsService.sendDueReminders, registered via
// jobs/appointmentReminders.job.js). Drives the mock messaging SDK
// directly so a push can actually be asserted on, not just "didn't throw".
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, messaging, reset } = require('./support/setup');
const appointmentsService = require('../src/services/appointments.service');

beforeEach(() => reset());

// Kigali is UTC+2 fixed — mirrors appointments.service.js's own
// kigaliDateTimeToUtcMs() so these tests build times the same way
// production code reads them.
function kigaliTimeString(msFromNow) {
  const utcMs = Date.now() + msFromNow + 2 * 60 * 60 * 1000;
  const d = new Date(utcMs);
  const date = d.toISOString().slice(0, 10);
  const startTime = `${String(d.getUTCHours()).padStart(2, '0')}:${String(d.getUTCMinutes()).padStart(2, '0')}`;
  return { date, startTime };
}

// notifications.service.js#sendPush() silently no-ops (by design — see its
// own docstring) whenever the recipient's /users doc has no fcmToken, so
// every reminder test needs one seeded to actually observe a push.
async function seedLinkedPatientAndDoctor() {
  const { uid } = await auth.createUser({ email: `p${Date.now()}@x.com`, password: 'x', displayName: 'P' });
  db.seed(`users/${uid}`, { role: 'patient', fcmToken: 'mock-fcm-token' });
  db.seed('patients/walkin1', { clinicId: 'org1', branchId: 'branch1', linkedAppAccountId: uid });
  db.seed('users/doc1', { name: 'Alice Uwase' });
  db.seed('branches/branch1', { name: 'Kigali Central Clinic' });
  return uid;
}

test('reminders: an appointment starting in 90 minutes is within BOTH windows on first contact — both fire, in one run', async () => {
  await seedLinkedPatientAndDoctor();
  const { date, startTime } = kigaliTimeString(90 * 60 * 1000);
  db.seed('appointments/appt1', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkin1',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date,
    startTime,
    endTime: startTime,
    status: 'confirmed',
  });

  const result = await appointmentsService.sendDueReminders();

  assert.equal(result.sent, 2, '90 minutes out is already inside the 24h window too, so both thresholds are due at once');
  assert.equal(messaging.sent.length, 2, 'a push must actually have been attempted for each');
  const bodies = messaging.sent.map((m) => m.notification.body);
  assert.ok(bodies.some((b) => /in 2 hours/.test(b)));
  assert.ok(bodies.some((b) => /tomorrow at/.test(b)));
  assert.ok(bodies.every((b) => /Alice Uwase/.test(b)));

  const stored = db.peek('appointments/appt1');
  assert.equal(stored.sentReminders.twoHour, true);
  assert.equal(stored.sentReminders.twentyFourHour, true);
});

test('reminders: running the job again immediately does not send a duplicate for either threshold', async () => {
  await seedLinkedPatientAndDoctor();
  const { date, startTime } = kigaliTimeString(90 * 60 * 1000);
  db.seed('appointments/appt1', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkin1',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date,
    startTime,
    endTime: startTime,
    status: 'confirmed',
  });

  await appointmentsService.sendDueReminders();
  assert.equal(messaging.sent.length, 2);

  const second = await appointmentsService.sendDueReminders();

  assert.equal(second.sent, 0);
  assert.equal(messaging.sent.length, 2, 'no additional push on the immediate re-run');
});

test('reminders: an appointment starting in 20 hours gets only the 24-hour reminder, not the 2-hour one', async () => {
  await seedLinkedPatientAndDoctor();
  const { date, startTime } = kigaliTimeString(20 * 60 * 60 * 1000);
  db.seed('appointments/appt1', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkin1',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date,
    startTime,
    endTime: startTime,
    status: 'confirmed',
  });

  const result = await appointmentsService.sendDueReminders();

  assert.equal(result.sent, 1);
  const stored = db.peek('appointments/appt1');
  assert.equal(stored.sentReminders.twentyFourHour, true);
  assert.equal(stored.sentReminders.twoHour, false);
  assert.equal(messaging.sent.length, 1);
  assert.match(messaging.sent[0].notification.body, /tomorrow at/);
});

test('reminders: an appointment more than 24 hours out gets no reminder yet', async () => {
  await seedLinkedPatientAndDoctor();
  const { date, startTime } = kigaliTimeString(48 * 60 * 60 * 1000);
  db.seed('appointments/appt1', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkin1',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date,
    startTime,
    endTime: startTime,
    status: 'confirmed',
  });

  const result = await appointmentsService.sendDueReminders();

  assert.equal(result.sent, 0);
  assert.equal(messaging.sent.length, 0);
});

test('reminders: a pending (not yet confirmed) appointment never gets a reminder', async () => {
  await seedLinkedPatientAndDoctor();
  const { date, startTime } = kigaliTimeString(30 * 60 * 1000);
  db.seed('appointments/appt1', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkin1',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date,
    startTime,
    endTime: startTime,
    status: 'pending',
  });

  const result = await appointmentsService.sendDueReminders();

  assert.equal(result.sent, 0);
  assert.equal(messaging.sent.length, 0);
});

test('reminders: an appointment already in the past is skipped even if it somehow lacks sentReminders', async () => {
  await seedLinkedPatientAndDoctor();
  const { date, startTime } = kigaliTimeString(-30 * 60 * 1000);
  db.seed('appointments/appt1', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkin1',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date,
    startTime,
    endTime: startTime,
    status: 'confirmed',
  });

  const result = await appointmentsService.sendDueReminders();

  assert.equal(result.sent, 0);
  assert.equal(messaging.sent.length, 0);
});

test('reminders: a walk-in patient with no linked app account is skipped silently — no error, no push', async () => {
  db.seed('patients/walkinNoLink', { clinicId: 'org1', branchId: 'branch1' }); // no linkedAppAccountId
  db.seed('users/doc1', { name: 'Alice Uwase' });
  db.seed('branches/branch1', { name: 'Kigali Central Clinic' });
  const { date, startTime } = kigaliTimeString(30 * 60 * 1000);
  db.seed('appointments/appt1', {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'walkinNoLink',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date,
    startTime,
    endTime: startTime,
    status: 'confirmed',
  });

  const result = await appointmentsService.sendDueReminders();

  assert.equal(messaging.sent.length, 0, 'nobody to push to');
  // sentReminders is still recorded true — the notify attempt itself
  // completed (a silent no-op, not an error), so this must not be retried
  // forever on every future hourly run.
  assert.equal(result.sent, 2, 'both thresholds are due at once for a 30-minute-out appointment, same as any other');
  const stored = db.peek('appointments/appt1');
  assert.equal(stored.sentReminders.twoHour, true);
  assert.equal(stored.sentReminders.twentyFourHour, true);
});
