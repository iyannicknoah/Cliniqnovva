const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/reports.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

// spec 6.10 roles: Branch Admin (own branch), Clinic Admin (own org,
// all branches), Super Admin (all clinics), Accountant (financial
// reports only — narrower than the other three, no patient-volume/no-show).
const REPORT_ROLES = [ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];
const FINANCIAL_REPORT_ROLES = [...REPORT_ROLES, ROLES.ACCOUNTANT];

router.get('/revenue', requireRole(...FINANCIAL_REPORT_ROLES), controller.revenue);
router.get('/patient-volume', requireRole(...REPORT_ROLES), controller.patientVolume);
router.get('/no-show-rate', requireRole(...REPORT_ROLES), controller.noShowRate);

module.exports = router;
