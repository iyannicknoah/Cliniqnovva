const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/auditLog.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

// View-only, Super Admin/Clinic Admin — same pair the removed screen used
// to gate on. There is no write endpoint: entries are only ever created by
// auditLogService.write() called internally from other services.
router.get('/', requireRole(ROLES.SUPER_ADMIN, ROLES.CLINIC_ADMIN), controller.list);

module.exports = router;
