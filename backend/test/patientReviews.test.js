// Part 24 — Reviews and Ratings, Patient side.
// Confirms the real bug the Part 24 survey found: create()/update()/
// remove() previously compared `appointment.patientId`/`review.patientId`
// (a /patients walk-in-record id) directly against `actor.actorId` (the
// caller's Firebase uid) — the same two values Parts 21-23 already found
// broken for appointments/invoices/medical-records. These tests use a
// REAL patient uid + a REAL linked walk-in record, exactly like a genuine
// Patient App caller, not the pre-Part-19 `actor({role:'patient'})`
// shortcut other test files use (which set `actorId` to an arbitrary
// string that happened to equal `patientId` — that shortcut would have
// masked this exact bug).
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, reset } = require('./support/setup');
const reviewsService = require('../src/services/reviews.service');
const patientsController = require('../src/controllers/patients.controller');

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

function seedCompletedAppointment(uid) {
  db.seed('patients/walkin1', { clinicId: 'org1', branchId: 'branch1', linkedAppAccountId: uid });
  db.seed('appointments/appt1', {
    patientId: 'walkin1',
    clinicId: 'org1',
    branchId: 'branch1',
    doctorId: 'doc1',
    status: 'completed',
  });
  db.seed('branches/branch1', { clinicId: 'org1' });
  db.seed('doctors/doc1', {});
}

function patientActor(uid) {
  return { actorId: uid, role: 'patient', actorRole: 'patient', scope: { level: 'patient' } };
}

test('reviews.create: a real Patient App caller (uid, not patientId) can review their own completed appointment', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);

  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'Great', doctorRating: 4, doctorComment: 'Good' },
    patientActor(uid)
  );

  assert.equal(review.patientId, 'walkin1', 'stored patientId is the walk-in record id, not the uid');
  assert.equal(review.branchRating, 5);
});

test('reviews.create: a different patient account cannot review someone else\'s appointment', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);
  const otherUid = await makePatientUser();

  await assert.rejects(
    () =>
      reviewsService.create(
        { appointmentId: 'appt1', branchRating: 5, branchComment: 'x', doctorRating: 5, doctorComment: 'x' },
        patientActor(otherUid)
      ),
    (err) => {
      assert.equal(err.status, 403);
      return true;
    }
  );
});

test('reviews.create: rejects a second review for the same appointment (real uid path)', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);
  await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'x', doctorRating: 5, doctorComment: 'x' },
    patientActor(uid)
  );

  await assert.rejects(
    () =>
      reviewsService.create(
        { appointmentId: 'appt1', branchRating: 3, branchComment: 'again', doctorRating: 3, doctorComment: 'again' },
        patientActor(uid)
      ),
    (err) => {
      assert.equal(err.status, 409);
      return true;
    }
  );
});

test('reviews.update: the owning patient (real uid) can edit within the 48h window; a different account cannot', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);
  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 3, branchComment: 'ok', doctorRating: 3, doctorComment: 'ok' },
    patientActor(uid)
  );

  const updated = await reviewsService.update(review.id, { branchRating: 4 }, patientActor(uid));
  assert.equal(updated.branchRating, 4);

  const otherUid = await makePatientUser();
  await assert.rejects(
    () => reviewsService.update(review.id, { branchRating: 1 }, patientActor(otherUid)),
    (err) => {
      assert.equal(err.status, 403);
      return true;
    }
  );
});

test('reviews.update: rejected past the 48-hour window (real uid path)', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);
  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 3, branchComment: 'ok', doctorRating: 3, doctorComment: 'ok' },
    patientActor(uid)
  );

  const staleCreatedAt = new Date(Date.now() - 49 * 60 * 60 * 1000).toISOString();
  db.seed(`reviews/${review.id}`, { ...db.peek(`reviews/${review.id}`), createdAt: staleCreatedAt });

  await assert.rejects(
    () => reviewsService.update(review.id, { branchRating: 5 }, patientActor(uid)),
    (err) => {
      assert.match(err.message, /48-hour/);
      return true;
    }
  );
});

test('reviews.remove: the owning patient (real uid) can soft-delete their own review; a different account cannot', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);
  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 3, branchComment: 'ok', doctorRating: 3, doctorComment: 'ok' },
    patientActor(uid)
  );

  const otherUid = await makePatientUser();
  await assert.rejects(
    () => reviewsService.remove(review.id, patientActor(otherUid)),
    (err) => {
      assert.equal(err.status, 403);
      return true;
    }
  );

  const result = await reviewsService.remove(review.id, patientActor(uid));
  assert.equal(result.removed, true);
  assert.equal(db.peek(`reviews/${review.id}`).isHidden, true);
});

test('reviews.flag: a different patient can flag a review; the review is not auto-hidden', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);
  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'x', doctorRating: 5, doctorComment: 'x' },
    patientActor(uid)
  );
  const reporterUid = await makePatientUser();

  const flagged = await reviewsService.flag(review.id, { reason: 'Spam' }, patientActor(reporterUid));

  assert.equal(flagged.flags.length, 1);
  assert.equal(flagged.flags[0].reportedBy, reporterUid);
  assert.equal(flagged.flags[0].reason, 'Spam');
  assert.equal(db.peek(`reviews/${review.id}`).isHidden, false, 'flagging must never auto-hide');
});

test('reviews.flag: cannot report your own review', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);
  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'x', doctorRating: 5, doctorComment: 'x' },
    patientActor(uid)
  );

  await assert.rejects(
    () => reviewsService.flag(review.id, { reason: 'x' }, patientActor(uid)),
    (err) => {
      assert.equal(err.status, 400);
      return true;
    }
  );
});

test('reviews.flag: the same reporter flagging twice does not duplicate the entry', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);
  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'x', doctorRating: 5, doctorComment: 'x' },
    patientActor(uid)
  );
  const reporterUid = await makePatientUser();

  await reviewsService.flag(review.id, { reason: 'Spam' }, patientActor(reporterUid));
  const second = await reviewsService.flag(review.id, { reason: 'Still spam' }, patientActor(reporterUid));

  assert.equal(second.flags.length, 1);
});

test('reviews.flag: 404s for a missing review', async () => {
  const uid = await makePatientUser();
  await assert.rejects(
    () => reviewsService.flag('missing', { reason: 'x' }, patientActor(uid)),
    (err) => {
      assert.equal(err.status, 404);
      return true;
    }
  );
});

test('reviews.list({patientId}): filters to just this patient\'s reviews, hidden ones included', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);
  db.seed('appointments/appt2', { patientId: 'walkinOther', clinicId: 'org1', branchId: 'branch1', doctorId: 'doc1', status: 'completed' });
  db.seed('patients/walkinOther', { clinicId: 'org1', branchId: 'branch1', linkedAppAccountId: 'someOtherUid' });

  const mine = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'mine', doctorRating: 5, doctorComment: 'mine' },
    patientActor(uid)
  );
  await reviewsService.create(
    { appointmentId: 'appt2', branchRating: 1, branchComment: 'not mine', doctorRating: 1, doctorComment: 'not mine' },
    { actorId: 'someOtherUid', role: 'patient', actorRole: 'patient', scope: { level: 'patient' } }
  );
  await reviewsService.hide(mine.id, { hidden: true, reason: 'test' }, { actorId: 'admin1', role: 'clinic_admin', actorRole: 'clinic_admin', scope: { level: 'clinic', clinicId: 'org1' } });

  const results = await reviewsService.list({ clinicId: 'org1', patientId: 'walkin1' });

  assert.equal(results.length, 1);
  assert.equal(results[0].id, mine.id);
  assert.equal(results[0].isHidden, true, 'a patient\'s own hidden review is still returned to them');
});

test('GET /:patientId/reviews controller — a different patient account is rejected, the owner sees their reviews', async () => {
  const uid = await makePatientUser();
  seedCompletedAppointment(uid);
  await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'x', doctorRating: 5, doctorComment: 'x' },
    patientActor(uid)
  );
  const otherUid = await makePatientUser();

  const badReq = { user: { uid: otherUid, role: 'patient' }, params: { patientId: 'walkin1' } };
  const badRes = mockRes();
  await patientsController.getReviews(badReq, badRes, () => {});
  assert.equal(badRes.statusCode, 403);

  const goodReq = { user: { uid, role: 'patient' }, params: { patientId: 'walkin1' } };
  const goodRes = mockRes();
  await patientsController.getReviews(goodReq, goodRes, () => {});
  assert.equal(goodRes.body.reviews.length, 1);
});
