const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/platform.controller');

// Every route here is super_admin only — this whole module is cross-org
// oversight, never something an Organization/Branch Admin can reach.
router.use(verifyToken, attachScope, requireRole(ROLES.SUPER_ADMIN));

router.get('/search', controller.search);
router.get('/metrics', controller.getMetrics);
router.get('/audit-log', controller.getAuditLog);
router.get('/record/:collection/:id', controller.viewRecord);
router.post('/support-view/:organizationId', controller.startSupportView);
router.post('/support-view/:organizationId/end', controller.endSupportView);

module.exports = router;
