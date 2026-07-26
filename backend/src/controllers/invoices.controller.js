// Controller for /api/v1/invoices — spec section 6.8 / 9 (Part 12).
const invoicesService = require('../services/invoices.service');

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

    const invoices = await invoicesService.list({
      clinicId,
      branchId,
      status: req.query.status,
      dateFrom: req.query.dateFrom,
      dateTo: req.query.dateTo,
    });
    res.json({ invoices });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const invoice = await invoicesService.getById(req.params.id, actorFrom(req));
    if (!invoice) return res.status(404).json({ error: 'Invoice not found' });
    // clinicName (2026-07-26) — the receipt should show the clinic's own
    // name, not "Cliniqnovva" (the platform, not the business issuing the
    // invoice). Comes from req.scope (attachScope already fetched the
    // clinic doc for the suspension check), not a new query.
    res.json({ invoice: { ...invoice, clinicName: req.scope.clinicName || null } });
  } catch (err) {
    next(err);
  }
}

async function create(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.body.clinicId);
    const branchId = resolveBranchId(req, req.body.branchId);
    if (!clinicId) return res.status(400).json({ error: 'clinicId is required' });
    if (!branchId) return res.status(400).json({ error: 'branchId is required' });

    const invoice = await invoicesService.create(
      {
        clinicId,
        branchId,
        patientId: req.body.patientId,
        appointmentId: req.body.appointmentId,
        lineItems: req.body.lineItems,
      },
      actorFrom(req)
    );
    res.status(201).json({ invoice });
  } catch (err) {
    next(err);
  }
}

async function updateLineItems(req, res, next) {
  try {
    const invoice = await invoicesService.updateLineItems(req.params.id, req.body.lineItems, actorFrom(req));
    res.json({ invoice });
  } catch (err) {
    next(err);
  }
}

async function recordCashPayment(req, res, next) {
  try {
    const invoice = await invoicesService.recordCashPayment(req.params.id, req.body.amountRwf, actorFrom(req));
    res.json({ invoice });
  } catch (err) {
    next(err);
  }
}

async function recordInsurance(req, res, next) {
  try {
    const invoice = await invoicesService.recordInsurance(
      req.params.id,
      { amountRwf: req.body.amountRwf, scheme: req.body.scheme },
      actorFrom(req)
    );
    res.json({ invoice });
  } catch (err) {
    next(err);
  }
}

async function voidInvoice(req, res, next) {
  try {
    const invoice = await invoicesService.voidInvoice(req.params.id, req.body.reason, actorFrom(req));
    res.json({ invoice });
  } catch (err) {
    next(err);
  }
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented: invoices are voided, never deleted' });
}

module.exports = {
  list,
  getById,
  create,
  updateLineItems,
  recordCashPayment,
  recordInsurance,
  voidInvoice,
  remove,
};
