const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth.middleware');
const { requireRole, ROLES } = require('../middleware/role.middleware');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/services.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(requireAuth, attachScope);

router.get('/', requireRole(ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN, ROLES.DOCTOR, ROLES.RECEPTIONIST, ROLES.PATIENT), controller.list);
router.get('/:id', requireRole(ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN, ROLES.DOCTOR, ROLES.RECEPTIONIST, ROLES.PATIENT), controller.getById);
router.post('/', requireRole(ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN), controller.create);
router.patch('/:id', requireRole(ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN), controller.update);
router.delete('/:id', requireRole(ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN), controller.remove);

module.exports = router;
