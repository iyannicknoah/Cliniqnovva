const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/labOrders.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

// Ordering and reviewing a result are Doctor-only; performing the test
// (collecting the specimen, recording the result) is Nurse or Laboratorian
// — same dual-capability decision as addMedicalRecord's vitals-only Nurse
// tier, just for a second role now too. Admin roles get full parity, same
// pattern as every other module.
const ORDER_ROLES = [ROLES.DOCTOR, ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];
const PERFORM_ROLES = [ROLES.NURSE, ROLES.LABORATORIAN, ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];
const READ_ROLES = [
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.LABORATORIAN,
  ROLES.BRANCH_ADMIN,
  ROLES.CLINIC_ADMIN,
  ROLES.SUPER_ADMIN,
];

router.get('/', requireRole(...READ_ROLES), controller.list);
router.post('/', requireRole(...ORDER_ROLES), controller.create);

router.get('/:id', requireRole(...READ_ROLES), controller.getById);
router.post('/:id/collect', requireRole(...PERFORM_ROLES), controller.markCollected);
router.post('/:id/result', requireRole(...PERFORM_ROLES), controller.recordResult);
router.post('/:id/review', requireRole(...ORDER_ROLES), controller.markReviewed);

module.exports = router;
