const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/organizations.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

router.get('/', requireRole(ROLES.SUPER_ADMIN, ROLES.ORGANIZATION_ADMIN), controller.list);
router.get('/:id', requireRole(ROLES.SUPER_ADMIN, ROLES.ORGANIZATION_ADMIN), controller.getById);
router.post('/', requireRole(ROLES.SUPER_ADMIN), controller.create);
router.put('/:id', requireRole(ROLES.SUPER_ADMIN), controller.update);
router.put('/:id/status', requireRole(ROLES.SUPER_ADMIN), controller.setStatus);
router.delete('/:id', requireRole(ROLES.SUPER_ADMIN), controller.remove);

module.exports = router;
