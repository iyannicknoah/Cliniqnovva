const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/inventory.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

router.get('/', requireRole(ROLES.PHARMACIST, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN), controller.list);
router.get('/:id', requireRole(ROLES.PHARMACIST, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN), controller.getById);
router.post('/', requireRole(ROLES.PHARMACIST), controller.create);
router.patch('/:id', requireRole(ROLES.PHARMACIST), controller.update);
router.delete('/:id', requireRole(ROLES.PHARMACIST), controller.remove);

module.exports = router;
