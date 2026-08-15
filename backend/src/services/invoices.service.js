// Service layer for invoices (spec section 6.8 / 9 — Part 12).
// Cash only — there is NO payment gateway anywhere; this module only
// records that a payment happened. Every rule here exists to protect one
// invariant: insuranceCoveredAmountRwf + cashPaidAmountRwf must NEVER
// exceed totalAmountRwf, and totalAmountRwf is ALWAYS derived server-side
// from lineItems — never trusted from client input.
const { db } = require('../config/firebase-admin');
const notificationsService = require('./notifications.service');
const auditLogService = require('./auditLog.service');

const INSURANCE_SCHEMES = [
  'mutuelle',
  'rssb',
  'radiant',
  'oldMutual',
  'britam',
  'sonarwa',
  'sanlam',
  'prime',
  'mua',
  'bkGeneral',
  'mayfair',
  'private',
  'none',
];

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

function recalculateTotal(lineItems) {
  return (lineItems || []).reduce((sum, item) => sum + (Number(item.amountRwf) || 0), 0);
}

/** unpaid | partial | paid — voided is sticky and only ever set by voidInvoice(). */
function computeStatus({ totalAmountRwf, cashPaidAmountRwf, insuranceCoveredAmountRwf, status }) {
  if (status === 'voided') return 'voided';
  const paid = (cashPaidAmountRwf || 0) + (insuranceCoveredAmountRwf || 0);
  if (totalAmountRwf > 0 && paid >= totalAmountRwf) return 'paid';
  if (paid > 0) return 'partial';
  return 'unpaid';
}

function assertValidLineItems(lineItems) {
  if (!Array.isArray(lineItems) || lineItems.length === 0) {
    throw httpError(400, 'At least one line item is required');
  }
  for (const item of lineItems) {
    if (!item.description || !item.description.trim()) {
      throw httpError(400, 'Every line item needs a description');
    }
    if (!Number.isInteger(item.amountRwf) || item.amountRwf < 0) {
      throw httpError(400, 'Every line item amount must be a non-negative whole number of RWF');
    }
  }
}

async function getRawById(id) {
  const doc = await db.collection('invoices').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

function assertAccess(invoice, scope) {
  if (scope.level === 'platform') return;
  if (invoice.clinicId !== scope.clinicId) {
    throw httpError(403, 'This invoice belongs to a different clinic');
  }
  if (scope.level === 'branch' && invoice.branchId !== scope.branchId) {
    throw httpError(403, 'This invoice belongs to a different branch');
  }
}

function baseInvoiceDoc({ clinicId, branchId, patientId, appointmentId, lineItems, actorId }) {
  return {
    clinicId,
    branchId,
    patientId,
    appointmentId: appointmentId || null,
    lineItems,
    totalAmountRwf: recalculateTotal(lineItems),
    cashPaidAmountRwf: 0,
    insuranceCoveredAmountRwf: 0,
    insuranceScheme: 'none',
    status: 'unpaid',
    paymentMethod: 'cash',
    recordedBy: actorId || null,
    createdAt: new Date().toISOString(),
  };
}

/** Manual creation (Part 12 Task 4: POST /api/invoices). */
async function create({ clinicId, branchId, patientId, appointmentId, lineItems }, actor) {
  if (!patientId) throw httpError(400, 'patientId is required');
  assertValidLineItems(lineItems);

  const data = baseInvoiceDoc({ clinicId, branchId, patientId, appointmentId, lineItems, actorId: actor.actorId });
  const ref = await db.collection('invoices').add(data);
  return { id: ref.id, ...data };
}

/**
 * Auto-generate on appointment completion (Part 12 Task 1), pre-filled
 * from the service's defaultPriceRwf — "still editable" via
 * updateLineItems() afterwards. Idempotent: calling this twice for the
 * same appointment (e.g. a retried request) returns the existing invoice
 * instead of creating a duplicate.
 */
async function createFromAppointment(appointment, actor) {
  const existingSnap = await db.collection('invoices').where('appointmentId', '==', appointment.id).limit(1).get();
  if (!existingSnap.empty) {
    return { id: existingSnap.docs[0].id, ...existingSnap.docs[0].data() };
  }

  const serviceDoc = await db.collection('services').doc(appointment.serviceId).get();
  const service = serviceDoc.exists ? serviceDoc.data() : null;
  const lineItems = [
    {
      description: service?.name || 'Consultation',
      amountRwf: Number.isInteger(service?.defaultPriceRwf) ? service.defaultPriceRwf : 0,
    },
  ];

  const data = baseInvoiceDoc({
    clinicId: appointment.clinicId,
    branchId: appointment.branchId,
    patientId: appointment.patientId,
    appointmentId: appointment.id,
    lineItems,
    actorId: actor.actorId,
  });
  const ref = await db.collection('invoices').add(data);
  return { id: ref.id, ...data };
}

/** List, filterable by status/date (Part 12 Task 2). */
async function list({ clinicId, branchId, status, dateFrom, dateTo }) {
  let query = db.collection('invoices').where('clinicId', '==', clinicId);
  if (branchId) query = query.where('branchId', '==', branchId);
  if (status) query = query.where('status', '==', status);

  const snap = await query.get();
  let invoices = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  if (dateFrom) invoices = invoices.filter((inv) => inv.createdAt >= dateFrom);
  if (dateTo) invoices = invoices.filter((inv) => inv.createdAt <= `${dateTo}T23:59:59.999Z`);
  return invoices.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
}

async function getById(id, actor) {
  const invoice = await getRawById(id);
  if (!invoice) return null;
  assertAccess(invoice, actor.scope);
  return invoice;
}

/**
 * "Manually add/edit line items" (spec 6.8) — total is always recalculated
 * from the new array, never accepted from the client (DONE CONDITION:
 * "Total always server-recalculated"). Rejected if the new total would
 * fall below what's already been paid — that would silently let paid
 * amounts exceed the total through the back door, breaking the same
 * invariant recordCashPayment/recordInsurance guard directly.
 */
async function updateLineItems(id, lineItems, actor) {
  const invoice = await getRawById(id);
  if (!invoice) throw httpError(404, 'Invoice not found');
  assertAccess(invoice, actor.scope);
  if (invoice.status === 'voided') throw httpError(400, 'Cannot edit a voided invoice');
  assertValidLineItems(lineItems);

  const newTotal = recalculateTotal(lineItems);
  const alreadyPaid = (invoice.cashPaidAmountRwf || 0) + (invoice.insuranceCoveredAmountRwf || 0);
  if (newTotal < alreadyPaid) {
    throw httpError(
      400,
      `New total (${newTotal} RWF) can't be less than the ${alreadyPaid} RWF already paid on this invoice.`
    );
  }

  const updates = {
    lineItems,
    totalAmountRwf: newTotal,
    status: computeStatus({ ...invoice, totalAmountRwf: newTotal }),
  };
  await db.collection('invoices').doc(id).update(updates);
  return getRawById(id);
}

/**
 * Records a cash payment — ADDS to the running total, never overwrites it
 * (spec 6.8: "partial payments update the running balance, not overwrite
 * it"). Rejects if cash+insurance would then exceed the total (DONE
 * CONDITION, tested explicitly).
 */
async function recordCashPayment(id, amountRwf, actor) {
  if (!Number.isInteger(amountRwf) || amountRwf <= 0) {
    throw httpError(400, 'amountRwf must be a positive whole number');
  }
  const invoice = await getRawById(id);
  if (!invoice) throw httpError(404, 'Invoice not found');
  assertAccess(invoice, actor.scope);
  if (invoice.status === 'voided') throw httpError(400, 'Cannot record a payment on a voided invoice');

  const newCash = (invoice.cashPaidAmountRwf || 0) + amountRwf;
  const newTotalPaid = newCash + (invoice.insuranceCoveredAmountRwf || 0);
  if (newTotalPaid > invoice.totalAmountRwf) {
    throw httpError(
      400,
      `This payment would bring the total paid to ${newTotalPaid} RWF, exceeding the invoice total of ${invoice.totalAmountRwf} RWF.`
    );
  }

  const updates = {
    cashPaidAmountRwf: newCash,
    status: computeStatus({ ...invoice, cashPaidAmountRwf: newCash }),
  };
  await db.collection('invoices').doc(id).update(updates);
  const updated = await getRawById(id);

  // Part 14 Task 1 — "Payment-recorded confirmation". Best-effort, same
  // non-blocking hook pattern used everywhere else in this build.
  try {
    await notificationsService.notifyPaymentRecorded(updated, amountRwf, 'cash', actor);
  } catch (err) {
    console.warn(`[invoices] notifyPaymentRecorded failed for ${id}: ${err.message}`);
  }
  await auditLogService.write({
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    clinicId: invoice.clinicId,
    action: 'invoice.cash_payment_recorded',
    targetCollection: 'invoices',
    targetId: id,
  });

  return updated;
}

/** Same additive/overflow-guarded shape as recordCashPayment, for the insurance-covered portion. */
async function recordInsurance(id, { amountRwf, scheme }, actor) {
  if (!Number.isInteger(amountRwf) || amountRwf <= 0) {
    throw httpError(400, 'amountRwf must be a positive whole number');
  }
  if (!INSURANCE_SCHEMES.includes(scheme)) {
    throw httpError(400, `scheme must be one of: ${INSURANCE_SCHEMES.join(', ')}`);
  }
  const invoice = await getRawById(id);
  if (!invoice) throw httpError(404, 'Invoice not found');
  assertAccess(invoice, actor.scope);
  if (invoice.status === 'voided') throw httpError(400, 'Cannot record a payment on a voided invoice');

  const newInsurance = (invoice.insuranceCoveredAmountRwf || 0) + amountRwf;
  const newTotalPaid = (invoice.cashPaidAmountRwf || 0) + newInsurance;
  if (newTotalPaid > invoice.totalAmountRwf) {
    throw httpError(
      400,
      `This would bring the total paid to ${newTotalPaid} RWF, exceeding the invoice total of ${invoice.totalAmountRwf} RWF.`
    );
  }

  const updates = {
    insuranceCoveredAmountRwf: newInsurance,
    insuranceScheme: scheme,
    status: computeStatus({ ...invoice, insuranceCoveredAmountRwf: newInsurance }),
  };
  await db.collection('invoices').doc(id).update(updates);
  const updated = await getRawById(id);

  try {
    await notificationsService.notifyPaymentRecorded(updated, amountRwf, 'insurance', actor);
  } catch (err) {
    console.warn(`[invoices] notifyPaymentRecorded failed for ${id}: ${err.message}`);
  }
  await auditLogService.write({
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    clinicId: invoice.clinicId,
    action: 'invoice.insurance_recorded',
    targetCollection: 'invoices',
    targetId: id,
  });

  return updated;
}

/**
 * Appends one line item to a patient's own open invoice at a branch,
 * creating a new unpaid invoice if none exists yet (2026-07-29, built for
 * labOrders.service.js#recordResult — the first caller that needs to
 * APPEND to an existing invoice from another module rather than creating a
 * whole new one the way createFromAppointment() does). Preference order for
 * which invoice to append to: (1) the invoice already linked to this
 * appointmentId, if any — same invoice a completed-appointment consultation
 * charge would already be sitting on; (2) failing that, this patient's
 * most recently created still-open (unpaid/partial) invoice at the same
 * branch; (3) failing that, a brand-new invoice. A voided invoice is never
 * appended to (same "immutable once voided" rule updateLineItems()
 * enforces) — case (3) applies instead.
 */
async function addLineItem({ clinicId, branchId, patientId, appointmentId }, item, actor) {
  assertValidLineItems([item]);

  let invoice = null;
  if (appointmentId) {
    const linkedSnap = await db.collection('invoices').where('appointmentId', '==', appointmentId).limit(1).get();
    if (!linkedSnap.empty) invoice = { id: linkedSnap.docs[0].id, ...linkedSnap.docs[0].data() };
  }
  if (!invoice) {
    const openSnap = await db
      .collection('invoices')
      .where('patientId', '==', patientId)
      .where('branchId', '==', branchId)
      .where('status', 'in', ['unpaid', 'partial'])
      .get();
    if (!openSnap.empty) {
      const open = openSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
      invoice = open.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1))[0];
    }
  }

  if (!invoice || invoice.status === 'voided') {
    const data = baseInvoiceDoc({ clinicId, branchId, patientId, appointmentId, lineItems: [item], actorId: actor.actorId });
    const ref = await db.collection('invoices').add(data);
    return { id: ref.id, ...data };
  }

  const newLineItems = [...invoice.lineItems, item];
  const newTotal = recalculateTotal(newLineItems);
  const updates = {
    lineItems: newLineItems,
    totalAmountRwf: newTotal,
    status: computeStatus({ ...invoice, totalAmountRwf: newTotal }),
  };
  await db.collection('invoices').doc(invoice.id).update(updates);
  return getRawById(invoice.id);
}

/**
 * Void — the ONLY removal path (spec 6.8/master rule 10: never deleted,
 * only voided with a logged reason). There is no delete endpoint at all
 * for invoices (see invoices.controller.js's remove() stub), so "never
 * deletable" holds regardless of payment state.
 */
async function voidInvoice(id, reason, actor) {
  if (!reason || !reason.trim()) throw httpError(400, 'A reason is required to void an invoice');
  const invoice = await getRawById(id);
  if (!invoice) throw httpError(404, 'Invoice not found');
  assertAccess(invoice, actor.scope);
  if (invoice.status === 'voided') throw httpError(400, 'This invoice is already voided');

  await db.collection('invoices').doc(id).update({
    status: 'voided',
    voidReason: reason.trim(),
    voidedBy: actor.actorId || null,
    voidedAt: new Date().toISOString(),
  });
  await auditLogService.write({
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    clinicId: invoice.clinicId,
    action: 'invoice.voided',
    targetCollection: 'invoices',
    targetId: id,
  });
  return getRawById(id);
}

/**
 * Part 23 — the Patient App's Receipts screen. Ownership is enforced by
 * the CALLER (patients.controller.js, same `isPatientRecordOwnedBy`
 * pattern already used for appointments/medical-records in Parts 21-23) —
 * this is a plain patientId-filtered query, not routed through
 * `assertAccess` (which assumes `actor.scope.clinicId` exists, always
 * undefined for a patient's `{level:'patient'}` scope — the same bug
 * class fixed repeatedly elsewhere). Resolves `clinicName` per invoice —
 * normally only ever stitched on ad hoc from a staff caller's
 * `req.scope.clinicName` (set by `attachScope`'s suspension-check side
 * effect), which a patient's scope never has — needed for the receipt
 * PDF header (Task 2: same header the web dashboard's printing uses).
 */
async function listForPatient(patientId) {
  const snap = await db.collection('invoices').where('patientId', '==', patientId).get();
  const invoices = snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));

  const clinicIds = [...new Set(invoices.map((inv) => inv.clinicId).filter(Boolean))];
  const clinicDocs = await Promise.all(clinicIds.map((id) => db.collection('clinics').doc(id).get()));
  const clinicNames = {};
  clinicDocs.forEach((doc) => {
    if (doc.exists) clinicNames[doc.id] = doc.data().name || null;
  });

  return invoices.map((inv) => ({ ...inv, clinicName: clinicNames[inv.clinicId] || null }));
}

module.exports = {
  create,
  createFromAppointment,
  list,
  listForPatient,
  getById,
  updateLineItems,
  addLineItem,
  recordCashPayment,
  recordInsurance,
  voidInvoice,
};
