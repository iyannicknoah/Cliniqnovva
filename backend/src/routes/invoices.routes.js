const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/invoices.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

// spec 6.8 roles: Receptionist/Accountant (create & manage), Branch Admin/
// Clinic Admin (oversight) — given full manage rights here too, same
// as every other admin-vs-front-line split in this build (an admin
// correcting a billing mistake is exactly the kind of thing "oversight"
// covers). No Patient role — no Patient App in this web-only build.
const ROLES_ALL = [ROLES.RECEPTIONIST, ROLES.ACCOUNTANT, ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];

router.get('/', requireRole(...ROLES_ALL), controller.list);
router.post('/', requireRole(...ROLES_ALL), controller.create);

router.get('/:id', requireRole(...ROLES_ALL), controller.getById);
router.put('/:id/line-items', requireRole(...ROLES_ALL), controller.updateLineItems);
router.post('/:id/record-cash-payment', requireRole(...ROLES_ALL), controller.recordCashPayment);
router.post('/:id/record-insurance', requireRole(...ROLES_ALL), controller.recordInsurance);
router.put('/:id/void', requireRole(...ROLES_ALL), controller.voidInvoice);

router.delete('/:id', requireRole(...ROLES_ALL), controller.remove);

module.exports = router;
