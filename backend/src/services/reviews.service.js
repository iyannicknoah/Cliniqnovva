// Service layer for reviews (spec section 6.13(sibling) / 7 / 9, Part 16).
// One review per completed appointment, covering BOTH the branch and the
// assigned doctor in one document (branchRating/branchComment,
// doctorRating/doctorComment — Task 1's exact schema). branchId/doctorId/
// clinicId are always derived from the appointment server-side, never
// trusted from the client — same "server-derived, never client-supplied"
// pattern as invoices' totalAmountRwf.
//
// Two invariants:
//   1. Only the review's own author (the patient) may ever touch
//      branchRating/branchComment/doctorRating/doctorComment, and only
//      within a 48h window from creation. Staff never call the functions
//      that write those fields — reply()/hide() below literally cannot
//      touch them (DONE CONDITION: "patient's review stays unmodifiable by
//      staff").
//   2. averageRating/reviewCount on /branches and /doctors are CACHED,
//      recalculated by recalculateAggregates() on every create/update/
//      hide/unhide (Task 2: "not live-computed") — always excluding
//      isHidden reviews.
const { db } = require('../config/firebase-admin');
const patientsService = require('./patients.service');
const notificationsService = require('./notifications.service');

const EDIT_WINDOW_MS = 48 * 60 * 60 * 1000;

// Task 4 — popularityScore ingredients. A branch needs at least
// REVIEW_COUNT_THRESHOLD visible reviews to count at "full confidence";
// below that, its score is scaled down proportionally so a single 5-star
// review can't outrank a branch with dozens of solidly-good ones (a basic
// Bayesian-style confidence discount, not full Wilson-score math — simple
// and easy to reason about). Recency buckets: reviews from the last 90
// days count fully, 91-365 days count at half weight, anything older
// barely moves the score — "recency weighting" per the task.
const REVIEW_COUNT_THRESHOLD = 5;
const RECENCY_BUCKETS = [
  { withinDays: 90, weight: 1 },
  { withinDays: 365, weight: 0.5 },
  { withinDays: Infinity, weight: 0.2 },
];

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

function assertValidRating(value, label) {
  if (!Number.isInteger(value) || value < 1 || value > 5) {
    throw httpError(400, `${label} must be a whole number from 1 to 5`);
  }
}

async function getRawById(id) {
  const doc = await db.collection('reviews').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

function assertAccess(review, scope) {
  if (scope.level === 'platform') return;
  if (review.clinicId !== scope.clinicId) {
    throw httpError(403, 'This review belongs to a different clinic');
  }
  if (scope.level === 'branch' && review.branchId !== scope.branchId) {
    throw httpError(403, 'This review belongs to a different branch');
  }
}

function withinEditWindow(review) {
  return Date.now() - new Date(review.createdAt).getTime() <= EDIT_WINDOW_MS;
}

/**
 * Recomputes and stores averageRating/reviewCount on the branch and doctor
 * documents (Task 2) — the ONLY place these fields are ever written.
 * Hidden reviews are excluded entirely, so a hide/unhide always changes the
 * numbers (DONE CONDITION).
 */
async function recalculateAggregates(branchId, doctorId) {
  const [branchReviewsSnap, doctorReviewsSnap] = await Promise.all([
    db.collection('reviews').where('branchId', '==', branchId).get(),
    db.collection('reviews').where('doctorId', '==', doctorId).get(),
  ]);

  const visibleBranchRatings = branchReviewsSnap.docs
    .map((doc) => doc.data())
    .filter((r) => !r.isHidden)
    .map((r) => r.branchRating);
  const branchAverage = visibleBranchRatings.length
    ? visibleBranchRatings.reduce((sum, r) => sum + r, 0) / visibleBranchRatings.length
    : 0;

  const visibleDoctorRatings = doctorReviewsSnap.docs
    .map((doc) => doc.data())
    .filter((r) => !r.isHidden)
    .map((r) => r.doctorRating);
  const doctorAverage = visibleDoctorRatings.length
    ? visibleDoctorRatings.reduce((sum, r) => sum + r, 0) / visibleDoctorRatings.length
    : 0;

  await Promise.all([
    db.collection('branches').doc(branchId).update({
      averageRating: branchAverage,
      reviewCount: visibleBranchRatings.length,
    }),
    db.collection('doctors').doc(doctorId).update({
      averageRating: doctorAverage,
      reviewCount: visibleDoctorRatings.length,
    }),
  ]);
}

/**
 * Task 1 — one review per completed appointment. [actor] is always the
 * reviewing patient (role-gated in the route). `appointment.patientId` is
 * a /patients walk-in-record id, NOT the caller's own Firebase uid (see
 * patients.service.js's module docstring) — Part 24 found this function's
 * original ownership check (`appointment.patientId !== actor.actorId`)
 * compared the wrong two values and would NEVER have matched for a real
 * Patient App caller (same bug class fixed repeatedly in Parts 21-23:
 * appointments/invoices/medical-records all had it too). Fixed via
 * `isPatientRecordOwnedBy`, same as those.
 */
async function create({ appointmentId, branchRating, branchComment, doctorRating, doctorComment }, actor) {
  if (!appointmentId) throw httpError(400, 'appointmentId is required');
  assertValidRating(branchRating, 'branchRating');
  assertValidRating(doctorRating, 'doctorRating');

  const apptDoc = await db.collection('appointments').doc(appointmentId).get();
  if (!apptDoc.exists) throw httpError(404, 'Appointment not found');
  const appointment = apptDoc.data();

  const owns = await patientsService.isPatientRecordOwnedBy(appointment.patientId, actor.actorId);
  if (!owns) {
    throw httpError(403, 'You can only review your own appointments');
  }
  if (appointment.status !== 'completed') {
    throw httpError(400, 'You can only review a completed appointment');
  }

  const existingSnap = await db.collection('reviews').where('appointmentId', '==', appointmentId).limit(1).get();
  if (!existingSnap.empty) {
    throw httpError(409, 'This appointment has already been reviewed');
  }

  const data = {
    patientId: appointment.patientId,
    clinicId: appointment.clinicId,
    branchId: appointment.branchId,
    doctorId: appointment.doctorId,
    appointmentId,
    branchRating,
    branchComment: branchComment || null,
    doctorRating,
    doctorComment: doctorComment || null,
    isHidden: false,
    hiddenBy: null,
    hiddenAt: null,
    hiddenReason: null,
    staffReply: null,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
  const ref = await db.collection('reviews').add(data);
  await recalculateAggregates(appointment.branchId, appointment.doctorId);
  return { id: ref.id, ...data };
}

/** Author-only, 48h window, never touches isHidden/staffReply (Task 1). */
async function update(id, { branchRating, branchComment, doctorRating, doctorComment }, actor) {
  const review = await getRawById(id);
  if (!review) throw httpError(404, 'Review not found');
  if (!(await patientsService.isPatientRecordOwnedBy(review.patientId, actor.actorId))) {
    throw httpError(403, 'You can only edit your own review');
  }
  if (review.isHidden) throw httpError(400, 'This review has been hidden and can no longer be edited');
  if (!withinEditWindow(review)) throw httpError(400, 'The 48-hour edit window for this review has passed');

  if (branchRating !== undefined) assertValidRating(branchRating, 'branchRating');
  if (doctorRating !== undefined) assertValidRating(doctorRating, 'doctorRating');

  const updates = { updatedAt: new Date().toISOString() };
  if (branchRating !== undefined) updates.branchRating = branchRating;
  if (branchComment !== undefined) updates.branchComment = branchComment || null;
  if (doctorRating !== undefined) updates.doctorRating = doctorRating;
  if (doctorComment !== undefined) updates.doctorComment = doctorComment || null;

  await db.collection('reviews').doc(id).update(updates);
  await recalculateAggregates(review.branchId, review.doctorId);
  return getRawById(id);
}

/**
 * Author's own "delete" — a soft-hide, same as staff's hide() below (Task
 * 1: "soft-hide only", spec's master no-hard-delete rule). Still 48h-
 * windowed, same as update().
 */
async function remove(id, actor) {
  const review = await getRawById(id);
  if (!review) throw httpError(404, 'Review not found');
  if (!(await patientsService.isPatientRecordOwnedBy(review.patientId, actor.actorId))) {
    throw httpError(403, 'You can only remove your own review');
  }
  if (!withinEditWindow(review)) throw httpError(400, 'The 48-hour edit window for this review has passed');

  await db.collection('reviews').doc(id).update({
    isHidden: true,
    hiddenBy: actor.actorId,
    hiddenAt: new Date().toISOString(),
    hiddenReason: 'Removed by author',
  });
  await recalculateAggregates(review.branchId, review.doctorId);
  return { removed: true };
}

/**
 * Staff browsing (Task 3) — every review at the branch, including hidden
 * ones (moderators need to see what they hid). `appointmentId` (Part 22) —
 * lets the Patient App's My Bookings screen check "has this completed
 * appointment already been reviewed?" without a dedicated endpoint; note
 * this still returns a hidden review too (same as everything else here),
 * which is fine for an existence check, just not for display. `patientId`
 * (Part 24) — backs `GET /api/v1/patients/:patientId/reviews` (My Reviews
 * screen), same single-clinic-per-call + client-side fan-out-over-linked-
 * records shape as appointments/medical-records/invoices in Parts 22/23;
 * deliberately still includes this patient's own hidden reviews (they
 * should see their own review's fate, unlike another patient's hidden one).
 */
async function list({ clinicId, branchId, doctorId, appointmentId, patientId }) {
  let query = db.collection('reviews').where('clinicId', '==', clinicId);
  if (branchId) query = query.where('branchId', '==', branchId);

  const snap = await query.get();
  let reviews = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  if (doctorId) reviews = reviews.filter((r) => r.doctorId === doctorId);
  if (appointmentId) reviews = reviews.filter((r) => r.appointmentId === appointmentId);
  if (patientId) reviews = reviews.filter((r) => r.patientId === patientId);
  return reviews.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
}

async function getById(id, actor) {
  const review = await getRawById(id);
  if (!review) return null;
  assertAccess(review, actor.scope);
  return review;
}

/**
 * Staff reply (Task 3) — the ONLY field this function ever writes besides
 * bookkeeping. Structurally cannot touch branchRating/branchComment/
 * doctorRating/doctorComment (DONE CONDITION).
 */
async function reply(id, text, actor) {
  if (!text || !text.trim()) throw httpError(400, 'Reply text is required');
  const review = await getRawById(id);
  if (!review) throw httpError(404, 'Review not found');
  assertAccess(review, actor.scope);

  const staffReply = {
    text: text.trim(),
    repliedBy: actor.actorId || null,
    repliedAt: new Date().toISOString(),
  };
  await db.collection('reviews').doc(id).update({ staffReply });
  const updated = { ...review, staffReply };

  // Part 26 — no trigger of any kind existed here before (confirmed by
  // reading this function in full); best-effort, same non-blocking
  // try/catch pattern as every other notify* hook in this codebase.
  try {
    await notificationsService.notifyReviewReply(updated);
  } catch (err) {
    console.warn(`[reviews] notifyReviewReply failed for ${id}: ${err.message}`);
  }

  return updated;
}

/**
 * Hide/unhide (Task 3: "Org Admin/Super Admin" only, enforced by the route's
 * narrower role list). Recalculates aggregates both ways — DONE CONDITION:
 * "Ratings recalculate correctly on create/edit/delete/hide".
 */
async function hide(id, { hidden, reason }, actor) {
  const review = await getRawById(id);
  if (!review) throw httpError(404, 'Review not found');
  assertAccess(review, actor.scope);
  if (hidden && (!reason || !reason.trim())) {
    throw httpError(400, 'A reason is required to hide a review');
  }

  await db.collection('reviews').doc(id).update({
    isHidden: !!hidden,
    hiddenBy: hidden ? actor.actorId || null : null,
    hiddenAt: hidden ? new Date().toISOString() : null,
    hiddenReason: hidden ? reason.trim() : null,
  });
  await recalculateAggregates(review.branchId, review.doctorId);
  return getRawById(id);
}

/**
 * Part 24 Task 4 — reports a review for staff moderation. Deliberately
 * does NOT hide it (Task 3's own framing: "does not hide it immediately" —
 * moderation stays with Org Admin/Super Admin's existing hide() flow on
 * the web side). Append-only, same convention as auditLogs/
 * patientMergeLogs — a flag is never removed, only ever added to. A
 * patient can't flag their own review, and re-flagging by the same
 * reporter is a no-op rather than piling up duplicate entries.
 */
async function flag(id, { reason }, actor) {
  const review = await getRawById(id);
  if (!review) throw httpError(404, 'Review not found');

  const isOwnReview = await patientsService.isPatientRecordOwnedBy(review.patientId, actor.actorId);
  if (isOwnReview) throw httpError(400, 'You cannot report your own review');

  const existingFlags = review.flags || [];
  if (existingFlags.some((f) => f.reportedBy === actor.actorId)) {
    return { ...review, flags: existingFlags };
  }

  const flags = [
    ...existingFlags,
    { reportedBy: actor.actorId, reason: reason && reason.trim() ? reason.trim() : null, reportedAt: new Date().toISOString() },
  ];
  await db.collection('reviews').doc(id).update({ flags });
  return { ...review, flags };
}

function recencyWeight(createdAt, now) {
  const days = (now - new Date(createdAt).getTime()) / (1000 * 60 * 60 * 24);
  const bucket = RECENCY_BUCKETS.find((b) => days <= b.withinDays);
  return bucket.weight;
}

/**
 * Task 4 — popularityScore for one branch: recency-weighted average
 * branchRating (visible reviews only), scaled by a confidence multiplier
 * from the review-count threshold. Range stays 0-5, same scale as
 * averageRating, just weighted differently — this is a deliberately
 * separate number from Task 2's plain cached average, not a replacement
 * for it.
 */
async function computePopularityScore(branchId, now = Date.now()) {
  const snap = await db.collection('reviews').where('branchId', '==', branchId).get();
  const visible = snap.docs.map((doc) => doc.data()).filter((r) => !r.isHidden);

  if (visible.length === 0) return { popularityScore: 0, reviewCount: 0 };

  let weightedSum = 0;
  let weightTotal = 0;
  for (const review of visible) {
    const weight = recencyWeight(review.createdAt, now);
    weightedSum += review.branchRating * weight;
    weightTotal += weight;
  }
  const weightedAverage = weightTotal > 0 ? weightedSum / weightTotal : 0;
  const confidenceMultiplier = Math.min(visible.length / REVIEW_COUNT_THRESHOLD, 1);

  return {
    popularityScore: weightedAverage * confidenceMultiplier,
    reviewCount: visible.length,
  };
}

/** One branch, on demand (used by the manual recalculation endpoint too). */
async function recalculatePopularityForBranch(branchId) {
  const { popularityScore } = await computePopularityScore(branchId);
  await db.collection('branches').doc(branchId).update({
    popularityScore,
    popularityCalculatedAt: new Date().toISOString(),
  });
  return popularityScore;
}

/**
 * Every branch — what the daily node-cron job calls (Task 4: "recalculated
 * daily via node-cron, not per-request"). Also reachable via
 * POST /api/v1/reviews/recalculate-popularity for a manual trigger
 * (Task 6), using this exact same function either way.
 */
async function recalculatePopularityForAllBranches() {
  const branchesSnap = await db.collection('branches').get();
  const now = Date.now();

  const results = await Promise.all(
    branchesSnap.docs.map(async (doc) => {
      const { popularityScore } = await computePopularityScore(doc.id, now);
      await doc.ref.update({ popularityScore, popularityCalculatedAt: new Date().toISOString() });
      return { branchId: doc.id, popularityScore };
    })
  );
  return { recalculated: results.length, results };
}

/**
 * Task 5 — one branch's own score plus its rank among its clinic's
 * branches (highest popularityScore = rank 1). "Internal" per the task:
 * this is an operational metric for Org/Branch Admin, not a public
 * leaderboard.
 */
async function popularityRank(branchId) {
  const branchDoc = await db.collection('branches').doc(branchId).get();
  if (!branchDoc.exists) throw httpError(404, 'Branch not found');
  const branch = branchDoc.data();

  const siblingsSnap = await db
    .collection('branches')
    .where('clinicId', '==', branch.clinicId)
    .get();
  const ranked = siblingsSnap.docs
    .map((doc) => ({ id: doc.id, popularityScore: doc.data().popularityScore || 0 }))
    .sort((a, b) => b.popularityScore - a.popularityScore);

  const rank = ranked.findIndex((b) => b.id === branchId) + 1;

  return {
    branchId,
    popularityScore: branch.popularityScore || 0,
    averageRating: branch.averageRating || 0,
    reviewCount: branch.reviewCount || 0,
    popularityCalculatedAt: branch.popularityCalculatedAt || null,
    rank,
    totalBranchesRanked: ranked.length,
  };
}

module.exports = {
  EDIT_WINDOW_MS,
  REVIEW_COUNT_THRESHOLD,
  create,
  update,
  remove,
  list,
  getById,
  reply,
  hide,
  flag,
  recalculateAggregates,
  recalculatePopularityForBranch,
  recalculatePopularityForAllBranches,
  popularityRank,
};
