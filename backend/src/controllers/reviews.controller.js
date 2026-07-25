// Controller for /api/v1/reviews — spec section 6.13(sibling) / 7 (Part 16).
const reviewsService = require('../services/reviews.service');

function resolveClinicId(req, explicit) {
  return req.scope.level === 'platform' ? explicit : req.scope.clinicId;
}

function resolveBranchId(req, explicit) {
  return req.scope.level === 'branch' ? req.scope.branchId : explicit;
}

function actorFrom(req) {
  return { actorId: req.user?.uid, role: req.user?.role, actorRole: req.user?.role, scope: req.scope };
}

async function list(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.query.clinicId);
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    const branchId = resolveBranchId(req, req.query.branchId);

    // Part 17 Task 2 — a doctor's /doctor-reviews only ever shows reviews
    // about THEM: force doctorId to their own uid, overriding whatever the
    // client sent (or omitted), so a doctor can never read another
    // doctor's reviews by passing/forging a different id.
    const doctorId = req.user?.role === 'doctor' ? req.user.uid : req.query.doctorId;

    const reviews = await reviewsService.list({ clinicId, branchId, doctorId });
    res.json({ reviews });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const review = await reviewsService.getById(req.params.id, actorFrom(req));
    if (!review) return res.status(404).json({ error: 'Review not found' });
    res.json({ review });
  } catch (err) {
    next(err);
  }
}

async function create(req, res, next) {
  try {
    const review = await reviewsService.create(
      {
        appointmentId: req.body.appointmentId,
        branchRating: req.body.branchRating,
        branchComment: req.body.branchComment,
        doctorRating: req.body.doctorRating,
        doctorComment: req.body.doctorComment,
      },
      actorFrom(req)
    );
    res.status(201).json({ review });
  } catch (err) {
    next(err);
  }
}

async function update(req, res, next) {
  try {
    const review = await reviewsService.update(
      req.params.id,
      {
        branchRating: req.body.branchRating,
        branchComment: req.body.branchComment,
        doctorRating: req.body.doctorRating,
        doctorComment: req.body.doctorComment,
      },
      actorFrom(req)
    );
    res.json({ review });
  } catch (err) {
    next(err);
  }
}

async function remove(req, res, next) {
  try {
    const result = await reviewsService.remove(req.params.id, actorFrom(req));
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function reply(req, res, next) {
  try {
    const review = await reviewsService.reply(req.params.id, req.body.text, actorFrom(req));
    res.json({ review });
  } catch (err) {
    next(err);
  }
}

async function hide(req, res, next) {
  try {
    const review = await reviewsService.hide(
      req.params.id,
      { hidden: req.body.hidden, reason: req.body.reason },
      actorFrom(req)
    );
    res.json({ review });
  } catch (err) {
    next(err);
  }
}

async function popularityRank(req, res, next) {
  try {
    const branchId = resolveBranchId(req, req.query.branchId);
    if (!branchId) return res.status(400).json({ error: 'branchId is required' });
    const result = await reviewsService.popularityRank(branchId);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function recalculatePopularity(req, res, next) {
  try {
    const result = await reviewsService.recalculatePopularityForAllBranches();
    res.json(result);
  } catch (err) {
    next(err);
  }
}

module.exports = { list, getById, create, update, remove, reply, hide, popularityRank, recalculatePopularity };
