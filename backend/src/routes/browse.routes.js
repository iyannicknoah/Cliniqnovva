const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/browse.controller');

// Part 20 — Patient App's Browse Clinics/Doctors feature. Every route here
// is patient-only and cross-clinic (req.scope.level === 'patient', see
// branchScope.middleware.js) — staff already have their own clinic-scoped
// branches/reviews reads and don't need this surface.
router.use(verifyToken, attachScope, requireRole(ROLES.PATIENT));

router.get('/branches', controller.listBranches);
router.get('/branches/:branchId', controller.getBranchDetail);
router.get('/branches/:branchId/reviews', controller.listBranchReviews);

module.exports = router;
