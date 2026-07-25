// Controller for /api/v1/clinics — spec section 4 / 6.2 / 9, Part 3.
// Keep thin: parse/validate req, call clinics.service.js, shape the response.
const clinicsService = require('../services/clinics.service');
const authService = require('../services/auth.service');
const { ROLES } = require('../middleware/requireRole');

async function list(req, res, next) {
  try {
    const clinics = await clinicsService.list();
    res.json({ clinics });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const clinic = await clinicsService.getById(req.params.id);
    if (!clinic) return res.status(404).json({ error: 'Clinic not found' });
    res.json({ clinic });
  } catch (err) {
    next(err);
  }
}

// Part 3 Task 2 (updated): creates the clinic, then creates its
// Clinic Admin account directly with the password the Super Admin
// set — no invite email, no password-reset link.
async function create(req, res, next) {
  try {
    const {
      name,
      subscriptionPlan,
      ownerContactName,
      ownerContactPhone,
      adminEmail,
      adminPassword,
      billingCycle,
      subscriptionAmountRwf,
    } = req.body;
    if (!name || !subscriptionPlan || !adminEmail || !adminPassword) {
      return res.status(400).json({ error: 'name, subscriptionPlan, adminEmail, and adminPassword are required' });
    }

    const clinic = await clinicsService.create({
      name,
      subscriptionPlan,
      ownerContactName,
      ownerContactPhone,
      billingCycle,
      subscriptionAmountRwf,
    });

    const account = await authService.createStaffAccountWithPassword({
      email: adminEmail,
      password: adminPassword,
      name: ownerContactName || name,
      role: ROLES.CLINIC_ADMIN,
      clinicId: clinic.id,
      branchId: null,
      createdBy: req.user?.uid,
    });

    res.status(201).json({ clinic, account });
  } catch (err) {
    next(err);
  }
}

async function update(req, res, next) {
  try {
    const clinic = await clinicsService.update(req.params.id, req.body);
    res.json({ clinic });
  } catch (err) {
    next(err);
  }
}

async function setStatus(req, res, next) {
  try {
    const { isActive } = req.body;
    if (typeof isActive !== 'boolean') {
      return res.status(400).json({ error: 'isActive (boolean) is required' });
    }
    const clinic = await clinicsService.setStatus(req.params.id, isActive, req.user?.uid);
    res.json({ clinic });
  } catch (err) {
    next(err);
  }
}

async function remove(req, res, next) {
  try {
    const result = await clinicsService.remove(req.params.id);
    if (!result) return res.status(404).json({ error: 'Clinic not found' });
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

async function setBillingStatus(req, res, next) {
  try {
    const { billingStatus } = req.body;
    if (!billingStatus) {
      return res.status(400).json({ error: 'billingStatus is required' });
    }
    const clinic = await clinicsService.setBillingStatus(req.params.id, billingStatus, req.user?.uid);
    res.json({ clinic });
  } catch (err) {
    next(err);
  }
}

// Part 4 Task 3 — cash-only record-keeping, no payment gateway involved.
async function recordPayment(req, res, next) {
  try {
    const { amountRwf, date, note } = req.body;
    if (typeof amountRwf !== 'number' || amountRwf <= 0) {
      return res.status(400).json({ error: 'amountRwf (positive number) is required' });
    }
    const clinic = await clinicsService.recordPayment(req.params.id, { amountRwf, date, note }, req.user?.uid);
    if (!clinic) return res.status(404).json({ error: 'Clinic not found' });
    res.status(201).json({ clinic });
  } catch (err) {
    next(err);
  }
}

async function getPaymentHistory(req, res, next) {
  try {
    const paymentHistory = await clinicsService.getPaymentHistory(req.params.id);
    if (paymentHistory === null) return res.status(404).json({ error: 'Clinic not found' });
    res.json({ paymentHistory });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  list,
  getById,
  create,
  update,
  setStatus,
  setBillingStatus,
  remove,
  recordPayment,
  getPaymentHistory,
};
