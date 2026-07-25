// Service layer for inventory/pharmacy (spec section 6.9 / 9 — Part 13).
// Two invariants everything here protects:
//   1. quantity can NEVER go negative — every change (manual correction or
//      a dispense) is validated against the current quantity before it's
//      written, inside a transaction so concurrent writes can't race past it.
//   2. every quantity change is logged to `inventoryAdjustments` with a
//      reason + staffId (Task 3's DONE CONDITION) — adjust() and dispense()
//      write their log entry in the SAME transaction as the quantity write,
//      so a change and its log entry can never diverge.
const { db } = require('../config/firebase-admin');
const notificationsService = require('./notifications.service');

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

/** Africa/Kigali is UTC+2 year-round (no DST) — same helper as appointments.service.js. */
function kigaliDateString(date = new Date()) {
  return new Date(date.getTime() + 2 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

function isExpired(item, today = kigaliDateString()) {
  return !!item.expiryDate && item.expiryDate < today;
}

function computeNeedsReorder(item) {
  return item.quantity <= (item.reorderLevel || 0);
}

async function getRawById(id) {
  const doc = await db.collection('inventory').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

function assertAccess(item, scope) {
  if (scope.level === 'platform') return;
  if (item.clinicId !== scope.clinicId) {
    throw httpError(403, 'This item belongs to a different clinic');
  }
  if (scope.level === 'branch' && item.branchId !== scope.branchId) {
    throw httpError(403, 'This item belongs to a different branch');
  }
}

/** Item CRUD is scoped to one branch — spec 6.9: pharmacy stock isn't shared across branches. */
async function create({ clinicId, branchId, name, unit, category, quantity, reorderLevel, expiryDate }, actor) {
  if (!clinicId) throw httpError(400, 'clinicId is required');
  if (!branchId) throw httpError(400, 'branchId is required');
  if (!name || !name.trim()) throw httpError(400, 'Item name is required');
  if (!unit || !unit.trim()) throw httpError(400, 'Unit (e.g. tablet, bottle) is required');
  const startingQuantity = Number.isInteger(quantity) && quantity >= 0 ? quantity : 0;
  const level = Number.isInteger(reorderLevel) && reorderLevel >= 0 ? reorderLevel : 10;

  const data = {
    clinicId,
    branchId,
    name: name.trim(),
    nameLower: name.trim().toLowerCase(),
    unit: unit.trim(),
    category: category || null,
    quantity: startingQuantity,
    reorderLevel: level,
    expiryDate: expiryDate || null,
    isActive: true,
    createdAt: new Date().toISOString(),
    createdBy: actor.actorId || null,
    updatedAt: new Date().toISOString(),
  };
  data.needsReorder = computeNeedsReorder(data);

  const ref = await db.collection('inventory').add(data);
  if (startingQuantity > 0) {
    await db.collection('inventoryAdjustments').add({
      itemId: ref.id,
      clinicId,
      branchId,
      quantityChange: startingQuantity,
      quantityAfter: startingQuantity,
      type: 'initial',
      reason: 'Initial stock on item creation',
      staffId: actor.actorId || null,
      createdAt: new Date().toISOString(),
    });
  }
  return { id: ref.id, ...data };
}

/** List, scoped to branch (spec 6.9 DONE CONDITION: "Stock CRUD works, scoped to branch"). */
async function list({ clinicId, branchId, q }) {
  let query = db.collection('inventory').where('clinicId', '==', clinicId);
  if (branchId) query = query.where('branchId', '==', branchId);

  const snap = await query.get();
  let items = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  if (q && q.trim()) {
    const needle = q.trim().toLowerCase();
    items = items.filter((item) => item.nameLower && item.nameLower.includes(needle));
  }
  const today = kigaliDateString();
  return items
    .map((item) => ({ ...item, isExpired: isExpired(item, today) }))
    .sort((a, b) => (a.name < b.name ? -1 : 1));
}

async function getById(id, actor) {
  const item = await getRawById(id);
  if (!item) return null;
  assertAccess(item, actor.scope);
  return { ...item, isExpired: isExpired(item) };
}

const EDITABLE_FIELDS = ['name', 'unit', 'category', 'reorderLevel', 'expiryDate'];

/** Editable fields deliberately exclude `quantity` — every quantity change must go through adjust()/dispense() so it's always logged. */
async function update(id, fields, actor) {
  const item = await getRawById(id);
  if (!item) throw httpError(404, 'Item not found');
  assertAccess(item, actor.scope);

  const updates = {};
  for (const key of EDITABLE_FIELDS) {
    if (fields[key] !== undefined) updates[key] = fields[key];
  }
  if ('name' in updates) {
    if (!updates.name || !updates.name.trim()) throw httpError(400, 'Item name cannot be empty');
    updates.name = updates.name.trim();
    updates.nameLower = updates.name.toLowerCase();
  }
  if ('unit' in updates && (!updates.unit || !updates.unit.trim())) {
    throw httpError(400, 'Unit cannot be empty');
  }
  if ('reorderLevel' in updates) {
    if (!Number.isInteger(updates.reorderLevel) || updates.reorderLevel < 0) {
      throw httpError(400, 'reorderLevel must be a non-negative whole number');
    }
    updates.needsReorder = item.quantity <= updates.reorderLevel;
  }
  if (Object.keys(updates).length === 0) throw httpError(400, 'No editable fields provided');
  updates.updatedAt = new Date().toISOString();

  await db.collection('inventory').doc(id).update(updates);
  return getById(id, actor);
}

/** Deactivate only — never a real delete (master rule: no hard-deletes on records with dependent history, and every item has an adjustment history). */
async function setActive(id, isActive, actor) {
  const item = await getRawById(id);
  if (!item) throw httpError(404, 'Item not found');
  assertAccess(item, actor.scope);

  await db.collection('inventory').doc(id).update({ isActive: !!isActive, updatedAt: new Date().toISOString() });
  return getById(id, actor);
}

/**
 * Manual stock correction (Task 3) — quantityChange is SIGNED (positive for
 * a restock/count-up, negative for breakage/count-down/expiry write-off),
 * never an absolute new value, matching this build's "additive, never
 * overwrite" convention for running quantities elsewhere (invoices'
 * cashPaidAmountRwf). Runs in a transaction so the read-then-write can't
 * race with a concurrent adjust/dispense on the same item.
 */
async function adjust(id, { quantityChange, reason }, actor) {
  if (!Number.isInteger(quantityChange) || quantityChange === 0) {
    throw httpError(400, 'quantityChange must be a non-zero whole number');
  }
  if (!reason || !reason.trim()) throw httpError(400, 'A reason is required for every stock adjustment');

  const itemRef = db.collection('inventory').doc(id);
  const logRef = db.collection('inventoryAdjustments').doc();

  const result = await db.runTransaction(async (tx) => {
    const doc = await tx.get(itemRef);
    if (!doc.exists) throw httpError(404, 'Item not found');
    const item = { id: doc.id, ...doc.data() };
    assertAccess(item, actor.scope);

    const newQuantity = item.quantity + quantityChange;
    if (newQuantity < 0) {
      throw httpError(400, `This adjustment would take stock negative (currently ${item.quantity}).`);
    }

    tx.update(itemRef, {
      quantity: newQuantity,
      needsReorder: newQuantity <= (item.reorderLevel || 0),
      updatedAt: new Date().toISOString(),
    });
    tx.set(logRef, {
      itemId: id,
      clinicId: item.clinicId,
      branchId: item.branchId,
      quantityChange,
      quantityAfter: newQuantity,
      type: 'manual',
      reason: reason.trim(),
      staffId: actor.actorId || null,
      createdAt: new Date().toISOString(),
    });
    return {
      wasNeedsReorder: !!item.needsReorder,
      item: { ...item, quantity: newQuantity, needsReorder: newQuantity <= (item.reorderLevel || 0) },
    };
  });

  await notifyIfNewlyLowStock(result, actor);
  return getById(id, actor);
}

/** Part 14 Task 1 — "Low-stock alert to pharmacist", fired only on the false→true transition so restocking doesn't spam a fresh alert every time. */
async function notifyIfNewlyLowStock({ wasNeedsReorder, item }, actor) {
  if (wasNeedsReorder || !item.needsReorder) return;
  try {
    await notificationsService.notifyLowStock(item, actor);
  } catch (err) {
    console.warn(`[inventory] notifyLowStock failed for ${item.id}: ${err.message}`);
  }
}

/**
 * Dispense flow (Task 2): select prescription → matching stock item →
 * deduct. Blocks — WITHOUT deducting anything — if the item is expired or
 * inactive, or if the requested quantity exceeds what's in stock (and flags
 * the item `needsReorder: true` on that insufficient-stock block, per the
 * DONE CONDITION). On success, deducts stock AND marks the specific
 * prescription entry inside the patient's medical record as dispensed, all
 * inside one transaction — a partial outcome (stock deducted but the
 * prescription not marked, or vice versa) must never happen.
 */
async function dispense({ itemId, quantity, patientId, medicalRecordId, prescriptionIndex, reason }, actor) {
  if (!itemId) throw httpError(400, 'itemId is required');
  if (!Number.isInteger(quantity) || quantity <= 0) {
    throw httpError(400, 'quantity must be a positive whole number');
  }
  if (!patientId || !medicalRecordId) {
    throw httpError(400, 'patientId and medicalRecordId are required to record what a prescription was dispensed against');
  }
  if (!Number.isInteger(prescriptionIndex) || prescriptionIndex < 0) {
    throw httpError(400, 'prescriptionIndex is required');
  }

  const itemRef = db.collection('inventory').doc(itemId);
  const recordRef = db.collection('medicalRecords').doc(medicalRecordId);
  const logRef = db.collection('inventoryAdjustments').doc();

  // Flagged from inside the transaction when stock is insufficient — a
  // throw inside runTransaction rolls back EVERY write in that attempt
  // (including a tx.update for the flag), so the needsReorder write has to
  // happen afterward, outside the failed transaction, in the catch below.
  let insufficientStockItem = null;

  let result;
  try {
    result = await db.runTransaction(async (tx) => {
      const [itemDoc, recordDoc] = await Promise.all([tx.get(itemRef), tx.get(recordRef)]);
      if (!itemDoc.exists) throw httpError(404, 'Item not found');
      if (!recordDoc.exists) throw httpError(404, 'Medical record not found');

      const item = { id: itemDoc.id, ...itemDoc.data() };
      assertAccess(item, actor.scope);

      const record = recordDoc.data();
      if (record.patientId !== patientId) {
        throw httpError(400, 'This medical record does not belong to the given patient');
      }
      const prescriptions = Array.isArray(record.prescriptions) ? [...record.prescriptions] : [];
      const prescription = prescriptions[prescriptionIndex];
      if (!prescription) throw httpError(404, 'Prescription not found on this medical record');
      if (prescription.dispensed) throw httpError(400, 'This prescription has already been dispensed');

      if (!item.isActive) throw httpError(400, 'This item is deactivated and cannot be dispensed');
      if (isExpired(item)) throw httpError(400, `${item.name} is expired and cannot be dispensed`);

      if (quantity > item.quantity) {
        // Block WITHOUT deducting — flag for reorder (DONE CONDITION). No
        // adjustment log entry either, since no quantity actually changed.
        insufficientStockItem = item;
        throw httpError(
          409,
          `Insufficient stock: ${item.name} has ${item.quantity} ${item.unit} but ${quantity} were requested. Flagged for reorder.`
        );
      }

      const newQuantity = item.quantity - quantity;
      tx.update(itemRef, {
        quantity: newQuantity,
        needsReorder: newQuantity <= (item.reorderLevel || 0),
        updatedAt: new Date().toISOString(),
      });

      prescriptions[prescriptionIndex] = {
        ...prescription,
        dispensed: true,
        dispensedAt: new Date().toISOString(),
        dispensedBy: actor.actorId || null,
        dispensedItemId: itemId,
        dispensedQuantity: quantity,
      };
      tx.update(recordRef, { prescriptions });

      tx.set(logRef, {
        itemId,
        clinicId: item.clinicId,
        branchId: item.branchId,
        quantityChange: -quantity,
        quantityAfter: newQuantity,
        type: 'dispense',
        reason: reason && reason.trim() ? reason.trim() : `Dispensed for ${prescription.medicineName || 'prescription'}`,
        staffId: actor.actorId || null,
        patientId,
        medicalRecordId,
        createdAt: new Date().toISOString(),
      });

      return {
        wasNeedsReorder: !!item.needsReorder,
        item: {
          ...item,
          quantity: newQuantity,
          needsReorder: newQuantity <= (item.reorderLevel || 0),
        },
      };
    });
  } catch (err) {
    if (insufficientStockItem) {
      await itemRef.update({ needsReorder: true, updatedAt: new Date().toISOString() });
      // Definitely reorder-worthy — ran out mid-dispense — so this always
      // notifies, not just on a false→true transition.
      try {
        await notificationsService.notifyLowStock(insufficientStockItem, actor);
      } catch (notifyErr) {
        console.warn(`[inventory] notifyLowStock failed for ${insufficientStockItem.id}: ${notifyErr.message}`);
      }
    }
    throw err;
  }

  await notifyIfNewlyLowStock(result, actor);
  return getById(itemId, actor);
}

/** Stock adjustment log (Task 3's DONE CONDITION — viewable history), newest first, optionally filtered to one item. */
async function listAdjustments({ clinicId, branchId, itemId }) {
  let query = db.collection('inventoryAdjustments').where('clinicId', '==', clinicId);
  if (branchId) query = query.where('branchId', '==', branchId);
  if (itemId) query = query.where('itemId', '==', itemId);

  const snap = await query.get();
  const entries = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  return entries.sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
}

module.exports = {
  create,
  list,
  getById,
  update,
  setActive,
  adjust,
  dispense,
  listAdjustments,
};
