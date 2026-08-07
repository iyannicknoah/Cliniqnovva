// Service layer for lab orders/results (2026-07-29 — new Laboratorian role
// + clinical flow: Doctor orders a test -> Nurse/Laboratorian collects the
// specimen and records the result -> Doctor reviews it before writing
// diagnosis/prescription. One collection, not a separate results
// collection — a lab order has a single linear lifecycle and one result,
// unlike inventory's many-delta adjustment log, so embedding the result
// fields directly on the order doc keeps a read to one doc, no join.
const { db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');
const invoicesService = require('./invoices.service');

const PERFORM_ROLES = [ROLES.NURSE, ROLES.LABORATORIAN];

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

async function getRawById(id) {
  const doc = await db.collection('labOrders').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

function assertAccess(order, scope) {
  if (scope.level === 'platform') return;
  if (order.clinicId !== scope.clinicId) {
    throw httpError(403, 'This lab order belongs to a different clinic');
  }
  if (scope.level === 'branch' && order.branchId !== scope.branchId) {
    throw httpError(403, 'This lab order belongs to a different branch');
  }
}

/**
 * Doctor-only (also enforced at the route, this is the same defense-in-depth
 * recheck addMedicalRecord uses). priceRwf (2026-07-29) — there's no lab
 * test catalog in this build (out of scope for a first version, same
 * "match complexity to the vision" reasoning as everywhere else), so the
 * ordering doctor enters the price directly, same client-supplied-amountRwf
 * convention invoices.service.js's manual line items already use. Defaults
 * to 0 for facilities that don't bill lab tests as a separate line item —
 * recordResult()'s invoice hook still fires either way, just adds a 0 RWF
 * line rather than skipping billing integration entirely.
 */
async function create(
  { clinicId, branchId, patientId, appointmentId, medicalRecordId, testName, testCategory, priceRwf },
  actor
) {
  if (actor.role !== ROLES.DOCTOR) {
    throw httpError(403, 'Only a doctor can order a lab test');
  }
  if (!clinicId) throw httpError(400, 'clinicId is required');
  if (!branchId) throw httpError(400, 'branchId is required');
  if (!patientId) throw httpError(400, 'patientId is required');
  if (!testName || !testName.trim()) throw httpError(400, 'testName is required');
  const price = Number.isInteger(priceRwf) && priceRwf >= 0 ? priceRwf : 0;

  const data = {
    clinicId,
    branchId,
    patientId,
    appointmentId: appointmentId || null,
    medicalRecordId: medicalRecordId || null,
    testName: testName.trim(),
    testCategory: testCategory || null,
    priceRwf: price,
    status: 'ordered',
    orderedBy: actor.actorId || null,
    orderedAt: new Date().toISOString(),
    collectedBy: null,
    collectedAt: null,
    resultValue: null,
    resultUnit: null,
    resultNotes: null,
    resultedBy: null,
    resultedAt: null,
    reviewedBy: null,
    reviewedAt: null,
    invoiceLineItemAdded: false,
    createdAt: new Date().toISOString(),
  };
  const ref = await db.collection('labOrders').add(data);
  return { id: ref.id, ...data };
}

/** Worklist — filterable by status (e.g. Nurse/Laboratorian's "pending collection" queue) and/or one patient. */
async function list({ clinicId, branchId, status, patientId }) {
  let query = db.collection('labOrders').where('clinicId', '==', clinicId);
  if (branchId) query = query.where('branchId', '==', branchId);
  if (status) query = query.where('status', '==', status);
  if (patientId) query = query.where('patientId', '==', patientId);

  const snap = await query.get();
  const orders = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  return orders.sort((a, b) => (a.orderedAt < b.orderedAt ? 1 : -1));
}

async function getById(id, actor) {
  const order = await getRawById(id);
  if (!order) return null;
  assertAccess(order, actor.scope);
  return order;
}

/** ordered -> collected. Nurse or Laboratorian only. */
async function markCollected(id, actor) {
  if (!PERFORM_ROLES.includes(actor.role)) {
    throw httpError(403, 'Only a nurse or laboratorian can mark a specimen collected');
  }
  const order = await getRawById(id);
  if (!order) throw httpError(404, 'Lab order not found');
  assertAccess(order, actor.scope);
  if (order.status !== 'ordered') {
    throw httpError(400, `Cannot mark collected — this order is already "${order.status}"`);
  }

  await db.collection('labOrders').doc(id).update({
    status: 'collected',
    collectedBy: actor.actorId || null,
    collectedAt: new Date().toISOString(),
  });
  return getRawById(id);
}

/**
 * collected -> resulted. Nurse or Laboratorian only — never Doctor (review()
 * below is the doctor-facing step). Best-effort auto-bills the visit's
 * invoice (see invoicesService.addLineItem) once the result actually lands
 * — billing at order time would charge before any work is done; billing
 * here mirrors invoices.service.js#createFromAppointment's "bill on
 * completion, not on booking" philosophy. A billing failure must never
 * block the clinical result from saving, same non-blocking-hook pattern
 * used everywhere else in this build.
 */
async function recordResult(id, { resultValue, resultUnit, resultNotes }, actor) {
  if (!PERFORM_ROLES.includes(actor.role)) {
    throw httpError(403, 'Only a nurse or laboratorian can record a lab result');
  }
  if (resultValue === undefined || resultValue === null || `${resultValue}`.trim() === '') {
    throw httpError(400, 'resultValue is required');
  }
  const order = await getRawById(id);
  if (!order) throw httpError(404, 'Lab order not found');
  assertAccess(order, actor.scope);
  if (order.status !== 'collected') {
    throw httpError(400, `Cannot record a result — this order must be "collected" first (currently "${order.status}")`);
  }

  await db.collection('labOrders').doc(id).update({
    status: 'resulted',
    resultValue,
    resultUnit: resultUnit || null,
    resultNotes: resultNotes || null,
    resultedBy: actor.actorId || null,
    resultedAt: new Date().toISOString(),
  });

  try {
    await invoicesService.addLineItem(
      { clinicId: order.clinicId, branchId: order.branchId, patientId: order.patientId, appointmentId: order.appointmentId },
      { description: order.testName, amountRwf: order.priceRwf || 0 },
      actor
    );
    await db.collection('labOrders').doc(id).update({ invoiceLineItemAdded: true });
  } catch (err) {
    console.warn(`[labOrders] addLineItem failed for order ${id}: ${err.message}`);
  }

  return getRawById(id);
}

/** resulted -> reviewed. Doctor-only. */
async function markReviewed(id, actor) {
  if (actor.role !== ROLES.DOCTOR) {
    throw httpError(403, 'Only a doctor can mark a lab result reviewed');
  }
  const order = await getRawById(id);
  if (!order) throw httpError(404, 'Lab order not found');
  assertAccess(order, actor.scope);
  if (order.status !== 'resulted') {
    throw httpError(400, `Cannot review — this order must be "resulted" first (currently "${order.status}")`);
  }

  await db.collection('labOrders').doc(id).update({
    status: 'reviewed',
    reviewedBy: actor.actorId || null,
    reviewedAt: new Date().toISOString(),
  });
  return getRawById(id);
}

module.exports = {
  create,
  list,
  getById,
  markCollected,
  recordResult,
  markReviewed,
};
