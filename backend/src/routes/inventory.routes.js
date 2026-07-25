const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/inventory.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

// spec 6.9 roles: Pharmacist (day-to-day stock/dispense), Branch Admin/
// Clinic Admin/Super Admin given full manage parity — same
// admin-oversight pattern used everywhere else in this build.
const MANAGE_ROLES = [ROLES.PHARMACIST, ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];

router.get('/', requireRole(...MANAGE_ROLES), controller.list);
router.post('/', requireRole(...MANAGE_ROLES), controller.create);

// Literal-segment routes MUST stay registered BEFORE '/:id' below, or
// Express would capture 'adjustments'/'dispense' as an :id value.
router.get('/adjustments', requireRole(...MANAGE_ROLES), controller.listAdjustments);
router.post('/dispense', requireRole(...MANAGE_ROLES), controller.dispense);

router.get('/:id', requireRole(...MANAGE_ROLES), controller.getById);
router.patch('/:id', requireRole(...MANAGE_ROLES), controller.update);
router.patch('/:id/status', requireRole(...MANAGE_ROLES), controller.setActive);
router.post('/:id/adjust', requireRole(...MANAGE_ROLES), controller.adjust);

router.delete('/:id', requireRole(...MANAGE_ROLES), controller.remove);

module.exports = router;
