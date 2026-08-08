// Service layer for the Patient App's Browse feature (Part 20). Cross-clinic,
// read-only, patient-safe. Every response is built from an explicit field
// allowlist (never a raw doc spread) so a later field added to /branches or
// /doctors for staff purposes (e.g. billing) can never leak here by accident
// — the DONE CONDITION is "public browse endpoints never leak internal/
// financial fields", verified against the raw API response, not just typed
// models on the client.
//
// No cursor-based pagination convention exists anywhere in this backend
// (see reviews.service.js#list, notifications.service.js#list) — this
// follows the same "fetch the where() set, sort/slice in JS" pattern rather
// than inventing one.
const { db } = require('../config/firebase-admin');
const doctorsService = require('./doctors.service');
const reviewsService = require('./reviews.service');

const DEFAULT_REVIEWS_LIMIT = 10;
const MAX_REVIEWS_LIMIT = 50;

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/** Explicit allowlist — the ONLY place a branch doc's fields reach a patient. */
function toPublicBranch(doc) {
  return {
    id: doc.id,
    clinicId: doc.clinicId,
    name: doc.name || null,
    address: doc.address || null,
    phone: doc.phone || null,
    location: doc.location || null,
    workingHours: doc.workingHours || null,
    umugandaSaturdayHours: doc.umugandaSaturdayHours || null,
    servicesOffered: Array.isArray(doc.servicesOffered) ? doc.servicesOffered : [],
    averageRating: doc.averageRating || 0,
    reviewCount: doc.reviewCount || 0,
    popularityScore: doc.popularityScore || 0,
  };
}

async function fetchActiveBranches() {
  const snap = await db.collection('branches').where('isActive', '==', true).get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

function distinctDepartments(branches) {
  const set = new Set();
  branches.forEach((b) => (b.servicesOffered || []).forEach((s) => s && set.add(s)));
  return [...set].sort((a, b) => a.localeCompare(b));
}

/**
 * Branch list for the Browse screen and Home screen's Popular/New sections
 * (Task 1/2). `search` matches branch name/address OR any doctor's
 * name/specialty at that branch (Task 2's exact wording). `department`
 * filters on the servicesOffered tag. `sortBy` is one of
 * 'popular' (default, by popularityScore), 'rating', or 'name'.
 */
async function listBranches({ search, sortBy, department }) {
  const active = await fetchActiveBranches();
  const availableDepartments = distinctDepartments(active);

  let matched = active;

  if (search && search.trim()) {
    const needle = search.trim().toLowerCase();
    const doctorMatchedBranchIds = await doctorsService.searchBranchIdsByNameOrSpecialty(search);
    matched = matched.filter(
      (b) =>
        (b.name || '').toLowerCase().includes(needle) ||
        (b.address || '').toLowerCase().includes(needle) ||
        doctorMatchedBranchIds.has(b.id)
    );
  }

  if (department) {
    matched = matched.filter((b) => (b.servicesOffered || []).includes(department));
  }

  const sorted = [...matched].sort((a, b) => {
    if (sortBy === 'rating') return (b.averageRating || 0) - (a.averageRating || 0);
    if (sortBy === 'name') return (a.name || '').localeCompare(b.name || '');
    return (b.popularityScore || 0) - (a.popularityScore || 0);
  });

  return {
    branches: sorted.map(toPublicBranch),
    availableDepartments,
    reviewCountThreshold: reviewsService.REVIEW_COUNT_THRESHOLD,
  };
}

/** Branch detail + its doctor list (Task 3). 404s on missing/inactive branch — nothing to browse there. */
async function getBranchDetail(branchId) {
  const doc = await db.collection('branches').doc(branchId).get();
  if (!doc.exists || doc.data().isActive !== true) throw httpError(404, 'Branch not found');

  const doctors = await doctorsService.list({ branchId });
  return { branch: toPublicBranch({ id: doc.id, ...doc.data() }), doctors };
}

/**
 * Paginated, isHidden-excluded reviews for a branch (Task 3). The existing
 * GET /api/v1/reviews (reviews.service.js#list) deliberately returns hidden
 * reviews too ("moderators need to see what they hid") — unsafe to reuse
 * as-is for a public read, so this is its own filtered path.
 */
async function listBranchReviews(branchId, { limit, offset } = {}) {
  const safeLimit = Math.min(Math.max(Number(limit) || DEFAULT_REVIEWS_LIMIT, 1), MAX_REVIEWS_LIMIT);
  const safeOffset = Math.max(Number(offset) || 0, 0);

  const snap = await db.collection('reviews').where('branchId', '==', branchId).get();
  const visible = snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((r) => !r.isHidden)
    .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));

  const page = visible.slice(safeOffset, safeOffset + safeLimit);

  return {
    reviews: page.map((r) => ({
      id: r.id,
      branchRating: r.branchRating,
      branchComment: r.branchComment,
      staffReply: r.staffReply,
      createdAt: r.createdAt,
    })),
    total: visible.length,
    hasMore: safeOffset + safeLimit < visible.length,
  };
}

module.exports = { listBranches, getBranchDetail, listBranchReviews };
