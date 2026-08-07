// Audit log — restored 2026-07-29 (see auditLog.service.js for the removal/
// restoration history). write() is only ever called internally from other
// services (never exposed as a route), so these tests exercise it both
// directly and through the real mutation-point call sites it was wired
// into, the same "test through the real service, not just the helper in
// isolation" approach clinic-suspension.test.js already uses for setStatus.
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, reset, actor } = require('./support/setup');
const auditLogService = require('../src/services/auditLog.service');
const auditLogController = require('../src/controllers/auditLog.controller');
const clinicsService = require('../src/services/clinics.service');
const staffService = require('../src/services/staff.service');
const invoicesService = require('../src/services/invoices.service');

beforeEach(() => reset());

test('auditLog: write() stores actorId/actorRole/clinicId/action/target/timestamp, readable via list()', async () => {
  await auditLogService.write({
    actorId: 'user1',
    actorRole: 'super_admin',
    clinicId: 'org1',
    action: 'clinic.suspended',
    targetCollection: 'clinics',
    targetId: 'org1',
  });

  const logs = await auditLogService.list({ clinicId: 'org1' });
  assert.equal(logs.length, 1);
  assert.equal(logs[0].actorId, 'user1');
  assert.equal(logs[0].actorRole, 'super_admin');
  assert.equal(logs[0].clinicId, 'org1');
  assert.equal(logs[0].action, 'clinic.suspended');
  assert.equal(logs[0].targetCollection, 'clinics');
  assert.equal(logs[0].targetId, 'org1');
  assert.ok(logs[0].timestamp);
});

test('auditLog: list() with no clinicId is platform-wide (Super Admin view)', async () => {
  await auditLogService.write({ actorId: 'a', clinicId: 'org1', action: 'x', targetCollection: 'clinics', targetId: '1' });
  await auditLogService.write({ actorId: 'b', clinicId: 'org2', action: 'y', targetCollection: 'clinics', targetId: '2' });

  const all = await auditLogService.list({});
  assert.equal(all.length, 2);

  const scoped = await auditLogService.list({ clinicId: 'org1' });
  assert.equal(scoped.length, 1);
  assert.equal(scoped[0].clinicId, 'org1');
});

test('auditLog: filters by actorId and action', async () => {
  await auditLogService.write({ actorId: 'a', clinicId: 'org1', action: 'staff.created', targetCollection: 'users', targetId: '1' });
  await auditLogService.write({ actorId: 'a', clinicId: 'org1', action: 'staff.deactivated', targetCollection: 'users', targetId: '1' });
  await auditLogService.write({ actorId: 'b', clinicId: 'org1', action: 'staff.created', targetCollection: 'users', targetId: '2' });

  const byActor = await auditLogService.list({ clinicId: 'org1', actorId: 'a' });
  assert.equal(byActor.length, 2);

  const byAction = await auditLogService.list({ clinicId: 'org1', action: 'staff.created' });
  assert.equal(byAction.length, 2);
});

test('auditLog: write() failures never throw (best-effort, same as the notification hooks)', async () => {
  // Missing required fields would break a real Firestore write in
  // principle — write()'s own try/catch must swallow it either way, since
  // an audit-log failure must never block the action it's recording.
  await assert.doesNotReject(() => auditLogService.write({}));
});

test('auditLog: clinics.service.js#setStatus (suspend) records an entry', async () => {
  db.seed('clinics/org1', { isActive: true, name: 'Kigali Health' });
  const superAdmin = actor({ actorId: 'superAdminUid', role: 'super_admin' });

  await clinicsService.setStatus('org1', false, superAdmin);

  const logs = await auditLogService.list({ clinicId: 'org1' });
  assert.equal(logs.length, 1);
  assert.equal(logs[0].action, 'clinic.suspended');
  assert.equal(logs[0].actorId, 'superAdminUid');
  assert.equal(logs[0].targetId, 'org1');
});

test('auditLog: clinics.service.js#setStatus called with a bare actorId string (old call shape) does not throw', async () => {
  // clinic-suspension.test.js still calls setStatus with a bare string as
  // the third arg — this must keep working (actor?.actorId on a string is
  // just undefined, not a crash) so that existing test/call sites aren't
  // broken by widening this to an actor object.
  db.seed('clinics/org1', { isActive: true });
  await assert.doesNotReject(() => clinicsService.setStatus('org1', false, 'superAdminUid'));
  const logs = await auditLogService.list({});
  assert.equal(logs.length, 1);
  assert.equal(logs[0].actorId, null);
});

test('auditLog: staff.service.js#setStatus (deactivate) records an entry', async () => {
  // setStatus() also disables the Firebase Auth account, so the mock Auth
  // needs a matching user record, not just the Firestore doc — createUser()
  // gives us a real uid to seed both under.
  const { uid } = await auth.createUser({ email: 'nurse@clinic.rw', password: 'x', displayName: 'Nurse Uwase' });
  db.seed(`users/${uid}`, { role: 'nurse', clinicId: 'org1', branchId: 'branch1', name: 'Nurse Uwase', isActive: true });
  const branchAdmin = actor({ actorId: 'branchAdminUid', role: 'branch_admin', clinicId: 'org1', branchId: 'branch1' });

  await staffService.setStatus(uid, false, branchAdmin);

  const logs = await auditLogService.list({ clinicId: 'org1' });
  assert.equal(logs.length, 1);
  assert.equal(logs[0].action, 'staff.deactivated');
  assert.equal(logs[0].actorId, 'branchAdminUid');
  assert.equal(logs[0].targetId, uid);
});

test('auditLog: invoices.service.js#voidInvoice records an entry', async () => {
  const accountant = actor({ actorId: 'accountantUid', role: 'accountant', clinicId: 'org1', branchId: 'branch1' });
  const invoice = await invoicesService.create(
    { clinicId: 'org1', branchId: 'branch1', patientId: 'patientA', lineItems: [{ description: 'Consultation', amountRwf: 5000 }] },
    accountant
  );

  await invoicesService.voidInvoice(invoice.id, 'Entered in error', accountant);

  const logs = await auditLogService.list({ clinicId: 'org1' });
  assert.equal(logs.length, 1);
  assert.equal(logs[0].action, 'invoice.voided');
  assert.equal(logs[0].targetId, invoice.id);
});

test('auditLog: there is no write route — the controller only ever exposes list()', () => {
  assert.deepEqual(Object.keys(auditLogController), ['list']);
});
