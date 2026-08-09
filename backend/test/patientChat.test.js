// Part 25 — Patient-side chat. Chat messages themselves are written
// directly to Firestore by clients (see firestore.rules) — nothing to test
// at the backend layer for that. What IS backend-testable: resolving the
// walk-in patientId a new chat needs (resolveForClinic, reused from
// Part 21's getOrCreatePatientRecordForClinic), and the best-effort push
// trigger a client calls after writing a staff message (notifyNewMessage).
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, messaging, reset } = require('./support/setup');
const patientsController = require('../src/controllers/patients.controller');
const chatsService = require('../src/services/chats.service');
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
  return res;
}

async function makePatientUser() {
  const { uid } = await auth.createUser({ email: `p${Date.now()}${Math.random()}@x.com`, password: 'x', displayName: 'P' });
  await db.collection('users').doc(uid).set({
    role: 'patient',
    name: 'Alice Uwase',
    phone: '0780000001',
    phoneDigits: '0780000001',
    linkedPatientIds: [],
  });
  return uid;
}

test('POST /resolve-for-clinic: returns a walk-in patientId, reusing getOrCreatePatientRecordForClinic', async () => {
  const uid = await makePatientUser();
  const req = { user: { uid }, body: { clinicId: 'org1', branchId: 'branch1' } };
  const res = mockRes();

  await patientsController.resolveForClinic(req, res, () => {});

  assert.ok(res.body.patientId);
  assert.equal(db.peek(`patients/${res.body.patientId}`).linkedAppAccountId, uid);
  assert.equal(db.peek(`patients/${res.body.patientId}`).clinicId, 'org1');
});

test('POST /resolve-for-clinic: a second call for the same clinic reuses the same patientId', async () => {
  const uid = await makePatientUser();
  const req = { user: { uid }, body: { clinicId: 'org1', branchId: 'branch1' } };

  const res1 = mockRes();
  await patientsController.resolveForClinic(req, res1, () => {});
  const res2 = mockRes();
  await patientsController.resolveForClinic(req, res2, () => {});

  assert.equal(res1.body.patientId, res2.body.patientId);
});

test('POST /resolve-for-clinic: requires clinicId', async () => {
  const uid = await makePatientUser();
  const req = { user: { uid }, body: {} };
  const res = mockRes();
  await patientsController.resolveForClinic(req, res, () => {});
  assert.equal(res.statusCode, 400);
});

function seedChatWithMessage({ senderRole, linked = true }) {
  db.seed('patients/walkin1', {
    clinicId: 'org1',
    branchId: 'branch1',
    linkedAppAccountId: linked ? 'patientUid1' : null,
  });
  db.seed('users/patientUid1', { fcmToken: 'device-token-abc' });
  db.seed('chats/chat1', { patientId: 'walkin1', clinicId: 'org1', branchId: 'branch1' });
  db.seed('chats/chat1/messages/msg1', { senderId: 'someSender', senderRole, text: 'Hello from the clinic' });
}

test('chats.notifyNewMessage: a staff message pushes a notification to the linked patient account', async () => {
  seedChatWithMessage({ senderRole: 'receptionist' });

  const result = await chatsService.notifyNewMessage('chat1', 'msg1');

  assert.equal(result.notified, true);
  assert.equal(messaging.sent.length, 1);
  assert.equal(messaging.sent[0].token, 'device-token-abc');
  assert.match(messaging.sent[0].notification.body, /Hello from the clinic/);

  const notificationsSnap = await db.collection('notifications').where('recipientId', '==', 'patientUid1').get();
  assert.equal(notificationsSnap.size, 1);
  assert.equal(notificationsSnap.docs[0].data().type, 'newChatMessage');
});

test('chats.notifyNewMessage: a message sent by the patient themselves is a no-op, not an error', async () => {
  seedChatWithMessage({ senderRole: 'patient' });

  const result = await chatsService.notifyNewMessage('chat1', 'msg1');

  assert.equal(result.notified, false);
  assert.equal(result.reason, 'not_from_staff');
  assert.equal(messaging.sent.length, 0);
});

test('chats.notifyNewMessage: no-ops (does not throw) when the patient has no linked app account', async () => {
  seedChatWithMessage({ senderRole: 'doctor', linked: false });

  const result = await chatsService.notifyNewMessage('chat1', 'msg1');

  assert.equal(result.notified, false);
  assert.equal(result.reason, 'no_linked_account');
  assert.equal(messaging.sent.length, 0);
});

test('POST /fcm-token: saves the token onto the caller\'s own /users doc, since direct writes there are denied', async () => {
  const uid = await makePatientUser();
  const req = { user: { uid }, body: { token: 'device-token-xyz' } };
  const res = mockRes();

  await authController.setFcmToken(req, res, () => {});

  assert.equal(res.body.success, true);
  assert.equal(db.peek(`users/${uid}`).fcmToken, 'device-token-xyz');
});

test('POST /fcm-token: requires a token', async () => {
  const uid = await makePatientUser();
  const req = { user: { uid }, body: {} };
  const res = mockRes();
  await authController.setFcmToken(req, res, () => {});
  assert.equal(res.statusCode, 400);
});

test('chats.notifyNewMessage: 404s for a missing chat or message', async () => {
  await assert.rejects(() => chatsService.notifyNewMessage('missingChat', 'msg1'), (err) => {
    assert.equal(err.status, 404);
    return true;
  });

  seedChatWithMessage({ senderRole: 'doctor' });
  await assert.rejects(() => chatsService.notifyNewMessage('chat1', 'missingMessage'), (err) => {
    assert.equal(err.status, 404);
    return true;
  });
});
