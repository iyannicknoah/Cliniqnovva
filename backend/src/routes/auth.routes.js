const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const { authRateLimiter } = require('../middleware/rateLimiter.middleware');
const controller = require('../controllers/auth.controller');

// Part 2 Task 6 — staff invite + custom-claims assignment. Rate-limited
// (Task 8) since these are auth-adjacent endpoints worth protecting from
// brute-force/abuse same as login.
router.post(
  '/invite-staff',
  authRateLimiter,
  verifyToken,
  attachScope,
  requireRole(ROLES.SUPER_ADMIN, ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN),
  controller.inviteStaff
);
router.post(
  '/set-claims',
  authRateLimiter,
  verifyToken,
  requireRole(ROLES.SUPER_ADMIN),
  controller.setClaims
);

router.post(
  '/deactivate/:userId',
  authRateLimiter,
  verifyToken,
  attachScope,
  requireRole(ROLES.SUPER_ADMIN, ROLES.ORGANIZATION_ADMIN),
  controller.deactivateAccount
);

// Public (no prior Firebase session) — used during onboarding / forgotten password.
router.post('/complete-invite', authRateLimiter, controller.completeInvite);
router.post('/request-password-reset', authRateLimiter, controller.requestPasswordReset);

// Any authenticated user reading their own profile.
router.get('/me', verifyToken, controller.me);

module.exports = router;
