const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth.middleware');
const { requireRole, ROLES } = require('../middleware/role.middleware');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/appointments.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(requireAuth, attachScope);

router.get('/', requireRole(ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN, ROLES.DOCTOR, ROLES.PATIENT), controller.list);
router.get('/:id', requireRole(ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN, ROLES.DOCTOR, ROLES.PATIENT), controller.getById);
router.post('/', requireRole(ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN), controller.create);
router.patch('/:id', requireRole(ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN), controller.update);
router.delete('/:id', requireRole(ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN), controller.remove);

module.exports = router;
