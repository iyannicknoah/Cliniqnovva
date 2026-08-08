const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, reset } = require('./support/setup');
const browseService = require('../src/services/browse.service');

beforeEach(() => reset());

function seedClinicAndBranches() {
  // Financial/internal fields on the clinic doc — must NEVER surface in a
  // browse response, since browse never even reads /clinics.
  db.seed('clinics/org1', {
    name: 'Cliniqnovva Rwanda',
    subscriptionPlan: 'enterprise',
    billingStatus: 'active',
    subscriptionAmountRwf: 500000,
    branchLimit: null,
  });

  db.seed('branches/branch1', {
    clinicId: 'org1',
    name: 'Kigali Central Clinic',
    address: 'Gasabo, Kigali',
    phone: '0788000111',
    location: { lat: -1.94, lng: 30.06 },
    workingHours: { start: '08:00', end: '18:00' },
    servicesOffered: ['Dentistry', 'Pediatrics'],
    isActive: true,
    averageRating: 4.5,
    reviewCount: 10,
    popularityScore: 4.2,
  });
  db.seed('branches/branch2', {
    clinicId: 'org1',
    name: 'Huye Health Point',
    address: 'Huye, Southern Province',
    servicesOffered: ['Cardiology'],
    isActive: true,
    averageRating: 3.0,
    reviewCount: 2,
    popularityScore: 0.5,
  });
  db.seed('branches/branch3', {
    clinicId: 'org1',
    name: 'Closed Branch',
    servicesOffered: [],
    isActive: false,
    averageRating: 5,
    reviewCount: 20,
    popularityScore: 5,
  });

  db.seed('users/doc1', {
    role: 'doctor',
    name: 'Dr. Alice Uwase',
    email: 'alice@clinic.rw',
    phone: '0788111222',
    clinicId: 'org1',
    branchId: 'branch1',
    isActive: true,
  });
  db.seed('doctors/doc1', {
    specialty: 'Dentist',
    bio: 'Ten years of practice.',
    schedule: [{ day: 'monday', startTime: '08:00', endTime: '12:00', slotDurationMins: 30 }],
    breakMinutes: 15,
    blockedSlots: [{ date: '2026-01-01', startTime: '00:00', endTime: '23:59', reason: 'Holiday' }],
    averageRating: 4.5,
    reviewCount: 3,
  });
}

test('browse: listBranches() excludes inactive branches and never leaks clinic billing/subscription fields', async () => {
  seedClinicAndBranches();
  const { branches } = await browseService.listBranches({});

  assert.equal(branches.length, 2);
  assert.ok(!branches.some((b) => b.id === 'branch3'), 'inactive branch must not be listed');

  for (const branch of branches) {
    for (const leaked of ['subscriptionPlan', 'billingStatus', 'subscriptionAmountRwf', 'branchLimit', 'isActive']) {
      assert.ok(!(leaked in branch), `branch response must never include "${leaked}"`);
    }
  }
});

test('browse: listBranches() search matches branch name, address, or a doctor\'s name/specialty at that branch', async () => {
  seedClinicAndBranches();

  const byName = await browseService.listBranches({ search: 'Kigali' });
  assert.deepEqual(byName.branches.map((b) => b.id), ['branch1']);

  const byAddress = await browseService.listBranches({ search: 'Southern' });
  assert.deepEqual(byAddress.branches.map((b) => b.id), ['branch2']);

  const bySpecialty = await browseService.listBranches({ search: 'Dentist' });
  assert.deepEqual(bySpecialty.branches.map((b) => b.id), ['branch1']);

  const byDoctorName = await browseService.listBranches({ search: 'alice' });
  assert.deepEqual(byDoctorName.branches.map((b) => b.id), ['branch1']);

  const noMatch = await browseService.listBranches({ search: 'nonexistent' });
  assert.equal(noMatch.branches.length, 0);
});

test('browse: listBranches() department filter and availableDepartments stay stable across filters', async () => {
  seedClinicAndBranches();

  const cardiologyOnly = await browseService.listBranches({ department: 'Cardiology' });
  assert.deepEqual(cardiologyOnly.branches.map((b) => b.id), ['branch2']);
  // availableDepartments reflects the whole active set, not just the filtered result.
  assert.deepEqual(cardiologyOnly.availableDepartments, ['Cardiology', 'Dentistry', 'Pediatrics']);
});

test('browse: listBranches() sortBy rating/name/popular (default)', async () => {
  seedClinicAndBranches();

  const byRating = await browseService.listBranches({ sortBy: 'rating' });
  assert.deepEqual(byRating.branches.map((b) => b.id), ['branch1', 'branch2']);

  const byName = await browseService.listBranches({ sortBy: 'name' });
  assert.deepEqual(byName.branches.map((b) => b.id), ['branch2', 'branch1']); // Huye < Kigali

  const byPopular = await browseService.listBranches({});
  assert.deepEqual(byPopular.branches.map((b) => b.id), ['branch1', 'branch2']);
});

test('browse: getBranchDetail() returns the branch plus its doctors, doctor PII excluded', async () => {
  seedClinicAndBranches();
  const { branch, doctors } = await browseService.getBranchDetail('branch1');

  assert.equal(branch.id, 'branch1');
  assert.equal(doctors.length, 1);
  assert.equal(doctors[0].name, 'Dr. Alice Uwase');
  for (const leaked of ['email', 'phone', 'blockedSlots', 'breakMinutes']) {
    assert.ok(!(leaked in doctors[0]));
  }
});

test('browse: getBranchDetail() 404s for an inactive or missing branch', async () => {
  seedClinicAndBranches();

  await assert.rejects(() => browseService.getBranchDetail('branch3'), (err) => {
    assert.equal(err.status, 404);
    return true;
  });
  await assert.rejects(() => browseService.getBranchDetail('missing'), (err) => {
    assert.equal(err.status, 404);
    return true;
  });
});

test('browse: listBranchReviews() excludes hidden reviews and paginates with limit/offset', async () => {
  seedClinicAndBranches();
  db.seed('reviews/r1', {
    branchId: 'branch1',
    isHidden: false,
    branchRating: 5,
    branchComment: 'Great care',
    staffReply: null,
    createdAt: '2026-08-01T00:00:00.000Z',
  });
  db.seed('reviews/r2', {
    branchId: 'branch1',
    isHidden: true,
    branchRating: 1,
    branchComment: 'Spam review, hidden by staff',
    staffReply: null,
    createdAt: '2026-08-02T00:00:00.000Z',
  });
  db.seed('reviews/r3', {
    branchId: 'branch1',
    isHidden: false,
    branchRating: 4,
    branchComment: 'Good, a bit slow',
    staffReply: { text: 'Thanks for the feedback!', repliedBy: 'admin1', repliedAt: '2026-08-04T00:00:00.000Z' },
    createdAt: '2026-08-03T00:00:00.000Z',
  });

  const all = await browseService.listBranchReviews('branch1', {});
  assert.equal(all.total, 2, 'hidden review must not count');
  assert.deepEqual(all.reviews.map((r) => r.id), ['r3', 'r1']); // newest first
  assert.equal(all.reviews[0].staffReply.text, 'Thanks for the feedback!');
  assert.ok(!all.reviews.some((r) => r.id === 'r2'));

  const firstPage = await browseService.listBranchReviews('branch1', { limit: 1, offset: 0 });
  assert.equal(firstPage.reviews.length, 1);
  assert.equal(firstPage.hasMore, true);

  const secondPage = await browseService.listBranchReviews('branch1', { limit: 1, offset: 1 });
  assert.equal(secondPage.reviews.length, 1);
  assert.equal(secondPage.hasMore, false);
});
