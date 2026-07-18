const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth.middleware');
const { requireRole, ROLES } = require('../middleware/role.middleware');
const { attachScope } = require('../middleware/branchScope.middleware');
const { authRateLimiter } = require('../middleware/rateLimiter.middleware');
const controller = require('../controllers/auth.controller');

// Invite/deactivate are admin actions — require auth + role.
router.post(
  '/invite',
  authRateLimiter,
  requireAuth,
  attachScope,
  requireRole(ROLES.SUPER_ADMIN, ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN),
  controller.inviteStaff
);
router.post(
  '/deactivate/:userId',
  requireAuth,
  attachScope,
  requireRole(ROLES.SUPER_ADMIN, ROLES.ORGANIZATION_ADMIN),
  controller.deactivateAccount
);

// Public (no prior Firebase session) — used during onboarding / forgotten password.
router.post('/complete-invite', authRateLimiter, controller.completeInvite);
router.post('/request-password-reset', authRateLimiter, controller.requestPasswordReset);

// Any authenticated user reading their own profile.
router.get('/me', requireAuth, controller.me);

module.exports = router;
