const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, auth, reset, actor } = require('./support/setup');
const reviewsService = require('../src/services/reviews.service');

beforeEach(() => reset());

// Part 24 fixed a real bug where create()/update()/remove() compared
// `appointment.patientId`/`review.patientId` (a /patients walk-in-record
// id) directly against `actor.actorId` (the caller's Firebase uid) — two
// values that can never be equal for a genuine Patient App caller. These
// tests now seed a REAL linked walk-in record (`linkedAppAccountId: uid`)
// and use that uid as the actor, instead of the old shortcut of setting
// `patient.actorId = 'patientA'` to match a made-up patientId directly —
// that shortcut is exactly what masked the bug (see test/patientReviews.
// test.js for the dedicated ownership-bug regression tests).
async function makePatientActor() {
  const { uid } = await auth.createUser({ email: `p${Date.now()}${Math.random()}@x.com`, password: 'x', displayName: 'P' });
  db.seed('patients/patientA', { clinicId: 'org1', branchId: 'branch1', linkedAppAccountId: uid });
  return { actorId: uid, role: 'patient', actorRole: 'patient', scope: { level: 'patient' } };
}

function seedCompletedAppointment() {
  db.seed('appointments/appt1', {
    patientId: 'patientA',
    clinicId: 'org1',
    branchId: 'branch1',
    doctorId: 'doc1',
    status: 'completed',
  });
  db.seed('branches/branch1', { clinicId: 'org1' });
  db.seed('doctors/doc1', {});
}

test('reviews: one review per appointment — a second review for the same appointment is rejected', async () => {
  seedCompletedAppointment();
  const patient = await makePatientActor();

  await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'Great', doctorRating: 5, doctorComment: 'Great doc' },
    patient
  );

  await assert.rejects(
    () =>
      reviewsService.create(
        { appointmentId: 'appt1', branchRating: 4, branchComment: 'again', doctorRating: 4, doctorComment: 'again' },
        patient
      ),
    (err) => {
      assert.equal(err.status, 409);
      return true;
    }
  );
});

test('reviews: cannot review an appointment that has not been completed', async () => {
  const patient = await makePatientActor();
  db.seed('appointments/appt2', {
    patientId: 'patientA',
    clinicId: 'org1',
    branchId: 'branch1',
    doctorId: 'doc1',
    status: 'confirmed',
  });

  await assert.rejects(
    () => reviewsService.create({ appointmentId: 'appt2', branchRating: 5, doctorRating: 5 }, patient),
    (err) => {
      assert.equal(err.status, 400);
      return true;
    }
  );
});

test('reviews: edit window — an edit within 48h succeeds, past 48h is rejected', async () => {
  seedCompletedAppointment();
  const patient = await makePatientActor();

  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 3, branchComment: 'ok', doctorRating: 3, doctorComment: 'ok' },
    patient
  );

  const updated = await reviewsService.update(review.id, { branchRating: 4 }, patient);
  assert.equal(updated.branchRating, 4);

  // Force the review to look 49 hours old, simulating the window having passed.
  const staleCreatedAt = new Date(Date.now() - 49 * 60 * 60 * 1000).toISOString();
  db.seed(`reviews/${review.id}`, { ...db.peek(`reviews/${review.id}`), createdAt: staleCreatedAt });

  await assert.rejects(
    () => reviewsService.update(review.id, { branchRating: 5 }, patient),
    (err) => {
      assert.match(err.message, /48-hour/);
      return true;
    }
  );
});

test('reviews: staff replying never touches the patient-authored rating/comment fields', async () => {
  seedCompletedAppointment();
  const patient = await makePatientActor();
  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'Great', doctorRating: 5, doctorComment: 'Great doc' },
    patient
  );

  const staff = actor({ role: 'branch_admin', clinicId: 'org1', branchId: 'branch1' });
  const replied = await reviewsService.reply(review.id, 'Thank you for the feedback!', staff);

  assert.equal(replied.staffReply.text, 'Thank you for the feedback!');
  assert.equal(replied.branchRating, 5);
  assert.equal(replied.branchComment, 'Great');
});

test('reviews: hide() is soft-hide only — the document still exists, isHidden flips, aggregates exclude it', async () => {
  seedCompletedAppointment();
  const patient = await makePatientActor();
  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'Great', doctorRating: 5, doctorComment: 'Great doc' },
    patient
  );

  const staff = actor({ role: 'clinic_admin', clinicId: 'org1' });
  const hidden = await reviewsService.hide(review.id, { hidden: true, reason: 'Spam' }, staff);

  assert.equal(hidden.isHidden, true);
  assert.ok(db.peek(`reviews/${review.id}`), 'review document must still exist after hide()');
  const branch = db.peek('branches/branch1');
  assert.equal(branch.reviewCount, 0, 'a hidden review must not count toward the visible aggregate');
});

test('reviews: access scoping — a branch_admin from a different branch cannot read a review from another branch', async () => {
  seedCompletedAppointment();
  const patient = await makePatientActor();
  const review = await reviewsService.create(
    { appointmentId: 'appt1', branchRating: 5, branchComment: 'Great', doctorRating: 5, doctorComment: 'Great doc' },
    patient
  );

  const outsideBranchAdmin = actor({ role: 'branch_admin', clinicId: 'org1', branchId: 'branch2' });
  await assert.rejects(() => reviewsService.getById(review.id, outsideBranchAdmin), (err) => {
    assert.equal(err.status, 403);
    return true;
  });

  const sameBranchAdmin = actor({ role: 'branch_admin', clinicId: 'org1', branchId: 'branch1' });
  const seen = await reviewsService.getById(review.id, sameBranchAdmin);
  assert.equal(seen.id, review.id);
});
