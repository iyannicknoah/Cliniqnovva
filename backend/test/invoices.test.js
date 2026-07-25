const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, reset, actor } = require('./support/setup');
const invoicesService = require('../src/services/invoices.service');

beforeEach(() => reset());

async function seedInvoice() {
  const accountant = actor({ role: 'accountant', clinicId: 'org1', branchId: 'branch1' });
  return invoicesService.create(
    {
      clinicId: 'org1',
      branchId: 'branch1',
      patientId: 'patientA',
      lineItems: [{ description: 'Consultation', amountRwf: 10000 }],
    },
    accountant
  );
}

test('invoices: cash + insurance exceeding the total is rejected (insurance recorded first)', async () => {
  const invoice = await seedInvoice();
  const accountant = actor({ role: 'accountant', clinicId: 'org1', branchId: 'branch1' });

  const withInsurance = await invoicesService.recordInsurance(invoice.id, { amountRwf: 7000, scheme: 'mutuelle' }, accountant);
  assert.equal(withInsurance.status, 'partial');

  await assert.rejects(
    () => invoicesService.recordCashPayment(invoice.id, 4000, accountant), // 7000 + 4000 = 11000 > 10000 total
    (err) => {
      assert.equal(err.status, 400);
      assert.match(err.message, /exceeding/i);
      return true;
    }
  );

  // The rejected payment must not have partially applied.
  const unchanged = db.peek(`invoices/${invoice.id}`);
  assert.equal(unchanged.cashPaidAmountRwf, 0);
  assert.equal(unchanged.insuranceCoveredAmountRwf, 7000);
});

test('invoices: cash + insurance exceeding the total is rejected (cash recorded first)', async () => {
  const invoice = await seedInvoice();
  const accountant = actor({ role: 'accountant', clinicId: 'org1', branchId: 'branch1' });

  await invoicesService.recordCashPayment(invoice.id, 6000, accountant);

  await assert.rejects(
    () => invoicesService.recordInsurance(invoice.id, { amountRwf: 5000, scheme: 'rssb' }, accountant), // 6000 + 5000 = 11000 > 10000
    (err) => {
      assert.equal(err.status, 400);
      return true;
    }
  );
});

test('invoices: cash + insurance that exactly equals the total is accepted and marks the invoice paid', async () => {
  const invoice = await seedInvoice();
  const accountant = actor({ role: 'accountant', clinicId: 'org1', branchId: 'branch1' });

  await invoicesService.recordInsurance(invoice.id, { amountRwf: 6000, scheme: 'mutuelle' }, accountant);
  const paidInFull = await invoicesService.recordCashPayment(invoice.id, 4000, accountant);

  assert.equal(paidInFull.status, 'paid');
  assert.equal(paidInFull.cashPaidAmountRwf + paidInFull.insuranceCoveredAmountRwf, paidInFull.totalAmountRwf);
});
