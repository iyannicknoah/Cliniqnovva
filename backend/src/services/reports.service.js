// Service layer for reports/analytics (spec section 6.10, Part 14).
// Every report is computed from FINALIZED data only (DONE CONDITION):
//   - revenue: invoices with status !== 'voided' (a voided invoice was
//     invalidated — it never represents real, reportable revenue)
//   - patient volume: appointments with status === 'completed' (the only
//     status that means "a visit actually happened")
//   - no-shows: derived below, from appointments whose outcome is already
//     settled one way or the other (never a still-pending/future one)
// Nothing here mutates anything — pure read/aggregate.
const { db } = require('../config/firebase-admin');

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/** Africa/Kigali is UTC+2 year-round (no DST) — same helper as appointments.service.js. */
function kigaliDateString(date = new Date()) {
  return new Date(date.getTime() + 2 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

function assertValidRange(dateFrom, dateTo) {
  if (!dateFrom || !dateTo) throw httpError(400, 'dateFrom and dateTo are required (YYYY-MM-DD)');
  if (dateFrom > dateTo) throw httpError(400, 'dateFrom must be on or before dateTo');
}

/** Monday of the ISO week containing [dateStr]. */
function weekStart(dateStr) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  const day = d.getUTCDay(); // 0=Sunday
  const diff = day === 0 ? 6 : day - 1; // days since Monday
  d.setUTCDate(d.getUTCDate() - diff);
  return d.toISOString().slice(0, 10);
}

function bucketKey(dateStr, groupBy) {
  if (groupBy === 'month') return dateStr.slice(0, 7);
  if (groupBy === 'week') return weekStart(dateStr);
  return dateStr;
}

function addToBucket(map, key, amount = 1) {
  map[key] = (map[key] || 0) + amount;
}

/** Same as addToBucket, one level deeper — map[outerKey][innerKey] += amount. */
function addToNestedBucket(map, outerKey, innerKey, amount = 1) {
  const inner = (map[outerKey] ??= {});
  inner[innerKey] = (inner[innerKey] || 0) + amount;
}

/**
 * Revenue report (Task 2): daily/weekly/monthly trend (`groupBy`), plus
 * per-branch/per-doctor/per-service breakdowns. `totalCollectedRwf` (cash +
 * insurance actually recorded) is the headline number — `totalBilledRwf`
 * (the sum of totals, paid or not) is reported alongside it since a clinic
 * legitimately cares about both "billed" and "collected".
 */
async function revenue({ clinicId, branchId, dateFrom, dateTo, groupBy = 'day' }) {
  assertValidRange(dateFrom, dateTo);
  if (!clinicId) throw httpError(400, 'clinicId is required');
  if (!['day', 'week', 'month'].includes(groupBy)) {
    throw httpError(400, "groupBy must be 'day', 'week', or 'month'");
  }

  let query = db.collection('invoices').where('clinicId', '==', clinicId);
  if (branchId) query = query.where('branchId', '==', branchId);
  const snap = await query.get();

  const invoices = snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((inv) => inv.status !== 'voided')
    .filter((inv) => inv.createdAt >= dateFrom && inv.createdAt <= `${dateTo}T23:59:59.999Z`);

  // appointmentId -> {doctorId, serviceId, branchId} for the per-doctor/
  // per-service breakdown — only invoices auto-generated from a visit carry
  // one; a manually-created invoice (no appointment behind it) is reported
  // under 'manual' for both.
  const appointmentIds = [...new Set(invoices.map((inv) => inv.appointmentId).filter(Boolean))];
  const appointmentById = {};
  if (appointmentIds.length > 0) {
    const apptSnaps = await Promise.all(
      appointmentIds.map((id) => db.collection('appointments').doc(id).get())
    );
    apptSnaps.forEach((doc) => {
      if (doc.exists) appointmentById[doc.id] = doc.data();
    });
  }

  const trend = {};
  const byBranch = {};
  const byDoctor = {};
  const byService = {};
  // byBranchByDate/byDoctorByDate/byServiceByDate (Task: "different dates
  // for the same doctor are different rows") — same totals as
  // byBranch/byDoctor/byService, one level deeper by invoice createdAt date,
  // so the Reports screen can render one row per entity PER DATE instead of
  // collapsing a whole date range into a single aggregate row.
  const byBranchByDate = {};
  const byDoctorByDate = {};
  const byServiceByDate = {};
  let totalBilledRwf = 0;
  let totalCollectedRwf = 0;

  for (const inv of invoices) {
    const collected = (inv.cashPaidAmountRwf || 0) + (inv.insuranceCoveredAmountRwf || 0);
    totalBilledRwf += inv.totalAmountRwf || 0;
    totalCollectedRwf += collected;

    const invoiceDate = inv.createdAt.slice(0, 10);
    addToBucket(trend, bucketKey(invoiceDate, groupBy), collected);
    addToBucket(byBranch, inv.branchId || 'unknown', collected);
    addToNestedBucket(byBranchByDate, inv.branchId || 'unknown', invoiceDate, collected);

    const appt = inv.appointmentId ? appointmentById[inv.appointmentId] : null;
    addToBucket(byDoctor, appt?.doctorId || 'manual', collected);
    addToNestedBucket(byDoctorByDate, appt?.doctorId || 'manual', invoiceDate, collected);
    addToBucket(byService, appt?.serviceId || 'manual', collected);
    addToNestedBucket(byServiceByDate, appt?.serviceId || 'manual', invoiceDate, collected);
  }

  return {
    dateFrom,
    dateTo,
    groupBy,
    invoiceCount: invoices.length,
    totalBilledRwf,
    totalCollectedRwf,
    trend,
    byBranch,
    byDoctor,
    byService,
    byBranchByDate,
    byDoctorByDate,
    byServiceByDate,
  };
}

/** Patient volume/traffic (Task 2) — only 'completed' appointments count as an actual visit. */
async function patientVolume({ clinicId, branchId, dateFrom, dateTo, groupBy = 'day' }) {
  assertValidRange(dateFrom, dateTo);
  if (!clinicId) throw httpError(400, 'clinicId is required');
  if (!['day', 'week', 'month'].includes(groupBy)) {
    throw httpError(400, "groupBy must be 'day', 'week', or 'month'");
  }

  let query = db.collection('appointments').where('clinicId', '==', clinicId);
  if (branchId) query = query.where('branchId', '==', branchId);
  const snap = await query.get();

  const visits = snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((a) => a.status === 'completed')
    .filter((a) => a.date >= dateFrom && a.date <= dateTo);

  const trend = {};
  const byBranch = {};
  const byDoctor = {};
  const patientIds = new Set();

  for (const visit of visits) {
    addToBucket(trend, bucketKey(visit.date, groupBy));
    addToBucket(byBranch, visit.branchId || 'unknown');
    addToBucket(byDoctor, visit.doctorId || 'unknown');
    if (visit.patientId) patientIds.add(visit.patientId);
  }

  return {
    dateFrom,
    dateTo,
    groupBy,
    totalVisits: visits.length,
    uniquePatients: patientIds.size,
    trend,
    byBranch,
    byDoctor,
  };
}

/**
 * No-show rate (Task 2). This schema has no dedicated 'noShow' appointment
 * status (Part 11's state machine only has pending/confirmed/checkedIn/
 * completed/cancelled) — a deliberate cancellation is a different, tracked
 * outcome, not a no-show. So a no-show is DEFINED here as: an appointment
 * whose date has already passed, and which was never checked in and never
 * cancelled either (status still 'pending' or 'confirmed') — scheduled,
 * settled by the passage of time, nobody came. The rate is measured against
 * appointments that were actually due to happen (completed + no-show);
 * cancellations are excluded from the denominator since they're a distinct,
 * intentional outcome, not a failure to show up.
 */
async function noShowRate({ clinicId, branchId, dateFrom, dateTo }) {
  assertValidRange(dateFrom, dateTo);
  if (!clinicId) throw httpError(400, 'clinicId is required');

  const today = kigaliDateString();
  const effectiveDateTo = dateTo < today ? dateTo : today;

  let query = db.collection('appointments').where('clinicId', '==', clinicId);
  if (branchId) query = query.where('branchId', '==', branchId);
  const snap = await query.get();

  const settled = snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((a) => a.date >= dateFrom && a.date <= effectiveDateTo)
    .filter((a) => a.date < today);

  const completedCount = settled.filter((a) => a.status === 'completed').length;
  const noShowCount = settled.filter((a) => ['pending', 'confirmed'].includes(a.status)).length;
  const denominator = completedCount + noShowCount;

  const byBranch = {};
  for (const a of settled) {
    if (!['completed', 'pending', 'confirmed'].includes(a.status)) continue;
    const bucket = (byBranch[a.branchId || 'unknown'] ??= { completedCount: 0, noShowCount: 0 });
    if (a.status === 'completed') bucket.completedCount++;
    else bucket.noShowCount++;
  }
  for (const bucket of Object.values(byBranch)) {
    const d = bucket.completedCount + bucket.noShowCount;
    bucket.noShowRate = d > 0 ? bucket.noShowCount / d : 0;
  }

  return {
    dateFrom,
    dateTo,
    completedCount,
    noShowCount,
    noShowRate: denominator > 0 ? noShowCount / denominator : 0,
    byBranch,
  };
}

module.exports = { revenue, patientVolume, noShowRate };
