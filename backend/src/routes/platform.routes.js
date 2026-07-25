const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/platform.controller');

// Every route here is super_admin only — this whole module is cross-org
// oversight, never something a Clinic/Branch Admin can reach.
router.use(verifyToken, attachScope, requireRole(ROLES.SUPER_ADMIN));

router.get('/metrics', controller.getMetrics);
router.get('/revenue-trend', controller.getRevenueTrend);
router.post('/support-view/:clinicId', controller.startSupportView);
router.post('/support-view/:clinicId/end', controller.endSupportView);

module.exports = router;
