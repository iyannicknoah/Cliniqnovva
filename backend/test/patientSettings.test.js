// Part 26 — Settings (profile editing, notification preferences) and the
// preference gate on every patient-targeting notification trigger.
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, messaging, reset } = require('./support/setup');
const authService = require('../src/services/auth.service');
const authController = require('../src/controllers/auth.controller');
const notificationsService = require('../src/services/notifications.service');
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

async function makePatientUser(profile = {}) {
  const { uid } = await auth.createUser({ email: `p${Date.now()}${Math.random()}@x.com`, password: 'x', displayName: 'P' });
  await db.collection('users').doc(uid).set({
    role: 'patient',
    name: 'Alice Uwase',
    phone: '0780000001',
    phoneDigits: '0780000001',
    email: 'alice@example.com',
    linkedPatientIds: [],
    ...profile,
  });
  return uid;
}

test('updatePatientProfile: partial update only touches the fields sent', async () => {
  const uid = await makePatientUser();
  const result = await authService.updatePatientProfile(uid, { phone: '0788999999' });

  assert.equal(result.phone, '0788999999');
  assert.equal(result.phoneDigits, '0788999999');
  assert.equal(result.name, 'Alice Uwase', 'untouched field must survive the partial update');
  assert.equal(result.email, 'alice@example.com');
});

test('updatePatientProfile: rejects an empty name', async () => {
  const uid = await makePatientUser();
  await assert.rejects(() => authService.updatePatientProfile(uid, { name: '   ' }), (err) => {
    assert.equal(err.status, 400);
    return true;
  });
});

test('updatePatientProfile: validates nationalId is exactly 16 digits', async () => {
  const uid = await makePatientUser();
  await assert.rejects(() => authService.updatePatientProfile(uid, { nationalId: '12345' }), (err) => {
    assert.equal(err.status, 400);
    return true;
  });

  const ok = await authService.updatePatientProfile(uid, { nationalId: '1234567890123456' });
  assert.equal(ok.nationalId, '1234567890123456');
});

test('updatePatientProfile: rejects a call with no editable fields at all', async () => {
  const uid = await makePatientUser();
  await assert.rejects(() => authService.updatePatientProfile(uid, {}), (err) => {
    assert.equal(err.status, 400);
    return true;
  });
});

test('updatePatientProfile: notificationPreferences merges one key at a time, never clobbering the others', async () => {
  const uid = await makePatientUser();
  await authService.updatePatientProfile(uid, { notificationPreferences: { chatMessages: false } });
  const afterFirst = await authService.updatePatientProfile(uid, { notificationPreferences: { reviewReplies: false } });

  assert.deepEqual(afterFirst.notificationPreferences, { chatMessages: false, reviewReplies: false });
});

test('PUT /patient/profile controller: returns the updated profile', async () => {
  const uid = await makePatientUser();
  const req = { user: { uid }, body: { name: 'Alice N. Uwase' } };
  const res = mockRes();

  await authController.updatePatientProfile(req, res, () => {});

  assert.equal(res.body.success, true);
  assert.equal(res.body.profile.name, 'Alice N. Uwase');
});

function seedLinkedPatientAndAppointment(uid) {
  db.seed('patients/walkin1', { clinicId: 'org1', branchId: 'branch1', linkedAppAccountId: uid });
  db.seed('users/' + uid, { fcmToken: 'device-token-1' });
}

test('notifications: a disabled preference stops BOTH the in-app notification and the push (Task 3)', async () => {
  const uid = await makePatientUser();
  seedLinkedPatientAndAppointment(uid);
  await authService.updatePatientProfile(uid, { notificationPreferences: { appointmentReminders: false } });

  const appointment = { id: 'appt1', clinicId: 'org1', branchId: 'branch1', patientId: 'walkin1', startTime: '10:00' };
  await notificationsService.notifyAppointmentReminder(appointment, { threshold: 'twoHour' });

  assert.equal(messaging.sent.length, 0, 'no push should have been sent');
  const notificationsSnap = await db.collection('notifications').where('recipientId', '==', uid).get();
  assert.equal(notificationsSnap.size, 0, 'no in-app notification doc should exist either — Task 3 says stop the whole thing');
});

test('notifications: the push FCM payload carries data (type/notificationId/appointmentId) for deep-linking a tapped notification (Task 3)', async () => {
  const uid = await makePatientUser();
  seedLinkedPatientAndAppointment(uid);
  const appointment = { id: 'appt1', clinicId: 'org1', branchId: 'branch1', patientId: 'walkin1', startTime: '10:00' };

  await notificationsService.notifyAppointmentReminder(appointment, { threshold: 'twoHour' });

  assert.equal(messaging.sent.length, 1);
  const sentData = messaging.sent[0].data;
  assert.equal(sentData.type, 'appointmentReminder');
  assert.equal(sentData.appointmentId, 'appt1');
  assert.ok(sentData.notificationId);
});

test('notifications: appointmentReminders enabled by default (no prior Settings visit) still notifies', async () => {
  const uid = await makePatientUser();
  seedLinkedPatientAndAppointment(uid);

  const appointment = { id: 'appt1', clinicId: 'org1', branchId: 'branch1', patientId: 'walkin1', startTime: '10:00' };
  await notificationsService.notifyAppointmentReminder(appointment, { threshold: 'twoHour' });

  assert.equal(messaging.sent.length, 1);
});

test('notifications: disabling one preference (e.g. chatMessages) does not affect a different type (e.g. reviewReplies)', async () => {
  const uid = await makePatientUser();
  seedLinkedPatientAndAppointment(uid);
  await authService.updatePatientProfile(uid, { notificationPreferences: { chatMessages: false } });

  db.seed('reviews/rev1', {
    patientId: 'walkin1',
    clinicId: 'org1',
    branchId: 'branch1',
    staffReply: { text: 'Thanks for the feedback!' },
  });
  await notificationsService.notifyReviewReply(db.peek('reviews/rev1'));

  assert.equal(messaging.sent.length, 1, 'reviewReplies preference was never touched, so it stays enabled');
});

test('reviews.reply(): fires notifyReviewReply — no trigger existed here before Part 26', async () => {
  const uid = await makePatientUser();
  seedLinkedPatientAndAppointment(uid);
  db.seed('appointments/appt1', { patientId: 'walkin1', clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', status: 'completed' });
  db.seed('branches/branch1', { clinicId: 'org1' });
  db.seed('doctors/doc1', {});

  const patientActor = { actorId: uid, role: 'patient', actorRole: 'patient', scope: { level: 'patient' } };
  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'Great', doctorRating: 5, doctorComment: 'Great' },
    patientActor
  );

  const staffActor = { actorId: 'staff1', role: 'branch_admin', actorRole: 'branch_admin', scope: { level: 'branch', clinicId: 'org1', branchId: 'branch1' } };
  await reviewsService.reply(review.id, 'Thank you for your feedback!', staffActor);

  assert.equal(messaging.sent.length, 1);
  assert.match(messaging.sent[0].notification.body, /Thank you for your feedback/);
});

test('notifications.list()/markRead already work for a patient recipient (no change needed, confirmed by this test)', async () => {
  const uid = await makePatientUser();
  seedLinkedPatientAndAppointment(uid);
  const appointment = { id: 'appt1', clinicId: 'org1', branchId: 'branch1', patientId: 'walkin1', startTime: '10:00' };
  await notificationsService.notifyAppointmentReminder(appointment, { threshold: 'twoHour' });

  const list = await notificationsService.list(uid);
  assert.equal(list.length, 1);
  assert.equal(list[0].isRead, false);

  const marked = await notificationsService.markRead(list[0].id, uid);
  assert.equal(marked.isRead, true);
});
