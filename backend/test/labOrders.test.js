// Lab orders (2026-07-29) — Doctor orders -> Nurse/Laboratorian
// collects+results -> Doctor reviews. Mirrors the "no skipping states, role
// gated per transition" discipline invoices.service.js's computeStatus and
// inventory.service.js's transaction-guarded quantity already use.
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { reset, actor } = require('./support/setup');
const labOrdersService = require('../src/services/labOrders.service');
const invoicesService = require('../src/services/invoices.service');

beforeEach(() => reset());

const doctor = actor({ actorId: 'doctorUid', role: 'doctor', clinicId: 'org1', branchId: 'branch1' });
const nurse = actor({ actorId: 'nurseUid', role: 'nurse', clinicId: 'org1', branchId: 'branch1' });
const laboratorian = actor({ actorId: 'labUid', role: 'laboratorian', clinicId: 'org1', branchId: 'branch1' });
const receptionist = actor({ actorId: 'receptionistUid', role: 'receptionist', clinicId: 'org1', branchId: 'branch1' });

async function order(overrides = {}) {
  return labOrdersService.create(
    {
      clinicId: 'org1',
      branchId: 'branch1',
      patientId: 'patientA',
      testName: 'Malaria RDT',
      priceRwf: 2000,
      ...overrides,
    },
    doctor
  );
}

test('labOrders: only a doctor can order a test', async () => {
  await assert.rejects(
    () => labOrdersService.create({ clinicId: 'org1', branchId: 'branch1', patientId: 'patientA', testName: 'Malaria RDT' }, nurse),
    (err) => {
      assert.equal(err.status, 403);
      return true;
    }
  );
});

test('labOrders: a fresh order starts "ordered"', async () => {
  const o = await order();
  assert.equal(o.status, 'ordered');
  assert.equal(o.orderedBy, 'doctorUid');
});

test('labOrders: only Nurse or Laboratorian can mark collected — not Doctor, not Receptionist', async () => {
  const o = await order();
  await assert.rejects(() => labOrdersService.markCollected(o.id, doctor), (err) => {
    assert.equal(err.status, 403);
    return true;
  });
  await assert.rejects(() => labOrdersService.markCollected(o.id, receptionist), (err) => {
    assert.equal(err.status, 403);
    return true;
  });
});

test('labOrders: both Nurse and Laboratorian can mark collected (intentional dual capability)', async () => {
  const byNurse = await order();
  const collectedByNurse = await labOrdersService.markCollected(byNurse.id, nurse);
  assert.equal(collectedByNurse.status, 'collected');
  assert.equal(collectedByNurse.collectedBy, 'nurseUid');

  const byLab = await order();
  const collectedByLab = await labOrdersService.markCollected(byLab.id, laboratorian);
  assert.equal(collectedByLab.status, 'collected');
  assert.equal(collectedByLab.collectedBy, 'labUid');
});

test('labOrders: cannot skip "ordered" -> "resulted" directly (must be collected first)', async () => {
  const o = await order();
  await assert.rejects(
    () => labOrdersService.recordResult(o.id, { resultValue: 'Negative' }, nurse),
    (err) => {
      assert.equal(err.status, 400);
      assert.match(err.message, /collected/i);
      return true;
    }
  );
});

test('labOrders: cannot mark collected twice', async () => {
  const o = await order();
  await labOrdersService.markCollected(o.id, nurse);
  await assert.rejects(() => labOrdersService.markCollected(o.id, nurse), (err) => {
    assert.equal(err.status, 400);
    return true;
  });
});

test('labOrders: only Nurse or Laboratorian can record a result — not Doctor', async () => {
  const o = await order();
  await labOrdersService.markCollected(o.id, nurse);
  await assert.rejects(() => labOrdersService.recordResult(o.id, { resultValue: 'Negative' }, doctor), (err) => {
    assert.equal(err.status, 403);
    return true;
  });
});

test('labOrders: only a doctor can mark reviewed — not Nurse, not Laboratorian', async () => {
  const o = await order();
  await labOrdersService.markCollected(o.id, nurse);
  await labOrdersService.recordResult(o.id, { resultValue: 'Negative' }, nurse);
  await assert.rejects(() => labOrdersService.markReviewed(o.id, nurse), (err) => {
    assert.equal(err.status, 403);
    return true;
  });
  await assert.rejects(() => labOrdersService.markReviewed(o.id, laboratorian), (err) => {
    assert.equal(err.status, 403);
    return true;
  });
});

test('labOrders: cannot review before a result exists', async () => {
  const o = await order();
  await labOrdersService.markCollected(o.id, nurse);
  await assert.rejects(() => labOrdersService.markReviewed(o.id, doctor), (err) => {
    assert.equal(err.status, 400);
    return true;
  });
});

test('labOrders: full lifecycle ordered -> collected -> resulted -> reviewed', async () => {
  const o = await order();
  await labOrdersService.markCollected(o.id, laboratorian);
  const resulted = await labOrdersService.recordResult(o.id, { resultValue: 'Negative', resultUnit: null }, laboratorian);
  assert.equal(resulted.status, 'resulted');
  assert.equal(resulted.resultValue, 'Negative');
  assert.equal(resulted.resultedBy, 'labUid');

  const reviewed = await labOrdersService.markReviewed(o.id, doctor);
  assert.equal(reviewed.status, 'reviewed');
  assert.equal(reviewed.reviewedBy, 'doctorUid');
});

test('labOrders: branch isolation — a user from a different branch cannot act on this order', async () => {
  const o = await order();
  const otherBranchNurse = actor({ actorId: 'other', role: 'nurse', clinicId: 'org1', branchId: 'branch2' });
  await assert.rejects(() => labOrdersService.markCollected(o.id, otherBranchNurse), (err) => {
    assert.equal(err.status, 403);
    return true;
  });
});

test('labOrders: clinic isolation — a user from a different clinic entirely is rejected too', async () => {
  const o = await order();
  const otherClinicNurse = actor({ actorId: 'other', role: 'nurse', clinicId: 'org2', branchId: 'branchX' });
  await assert.rejects(() => labOrdersService.markCollected(o.id, otherClinicNurse), (err) => {
    assert.equal(err.status, 403);
    return true;
  });
});

test('labOrders: recordResult auto-adds an invoice line item priced at the order\'s priceRwf, and flags invoiceLineItemAdded', async () => {
  const o = await order({ priceRwf: 3000 });
  await labOrdersService.markCollected(o.id, nurse);
  const resulted = await labOrdersService.recordResult(o.id, { resultValue: 'Negative' }, nurse);

  assert.equal(resulted.invoiceLineItemAdded, true);
  const invoices = await invoicesService.list({ clinicId: 'org1', branchId: 'branch1' });
  assert.equal(invoices.length, 1);
  assert.equal(invoices[0].lineItems.length, 1);
  assert.equal(invoices[0].lineItems[0].description, 'Malaria RDT');
  assert.equal(invoices[0].lineItems[0].amountRwf, 3000);
  assert.equal(invoices[0].totalAmountRwf, 3000);
});

test('labOrders: two lab orders resulted for the same patient/branch append to the SAME open invoice, not two separate ones', async () => {
  const first = await order({ testName: 'Malaria RDT', priceRwf: 2000 });
  await labOrdersService.markCollected(first.id, nurse);
  await labOrdersService.recordResult(first.id, { resultValue: 'Negative' }, nurse);

  const second = await order({ testName: 'Blood Glucose', priceRwf: 1500 });
  await labOrdersService.markCollected(second.id, nurse);
  await labOrdersService.recordResult(second.id, { resultValue: '5.4 mmol/L' }, nurse);

  const invoices = await invoicesService.list({ clinicId: 'org1', branchId: 'branch1' });
  assert.equal(invoices.length, 1, 'both tests should land on one shared open invoice for this patient/branch');
  assert.equal(invoices[0].lineItems.length, 2);
  assert.equal(invoices[0].totalAmountRwf, 3500);
});

test('labOrders: a billing failure never blocks the clinical result from saving', async () => {
  const o = await order();
  await labOrdersService.markCollected(o.id, nurse);

  // Force the invoice hook to throw, proving recordResult()'s try/catch
  // around it actually protects the clinical write — not just that nothing
  // happened to go wrong in the happy-path tests above.
  const originalAddLineItem = invoicesService.addLineItem;
  invoicesService.addLineItem = async () => {
    throw new Error('simulated billing failure');
  };
  try {
    const resulted = await labOrdersService.recordResult(o.id, { resultValue: 'Negative' }, nurse);
    assert.equal(resulted.status, 'resulted');
    assert.equal(resulted.resultValue, 'Negative');
    assert.equal(resulted.invoiceLineItemAdded, false, 'the flag must stay false when billing failed');
  } finally {
    invoicesService.addLineItem = originalAddLineItem;
  }
});
