const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/auditLogs.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

router.get('/', requireRole(ROLES.SUPER_ADMIN, ROLES.ORGANIZATION_ADMIN), controller.list);
router.get('/:id', requireRole(ROLES.SUPER_ADMIN, ROLES.ORGANIZATION_ADMIN), controller.getById);
// This collection is system-written only — no client-facing create/update/delete routes.

module.exports = router;
