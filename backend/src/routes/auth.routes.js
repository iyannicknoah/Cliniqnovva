const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const { authRateLimiter } = require('../middleware/rateLimiter.middleware');
const controller = require('../controllers/auth.controller');

// PATCH (2026-07-23): the invite-link flow (POST /invite-staff,
// /complete-invite) is removed entirely. create-user is now the ONLY
// account-creation path — direct, active immediately, no email/SMS ever
// sent. Rate-limited (Task 8) since this is an auth-adjacent endpoint worth
// protecting from brute-force/abuse same as login.
router.post(
  '/create-user',
  authRateLimiter,
  verifyToken,
  attachScope,
  requireRole(ROLES.SUPER_ADMIN, ROLES.CLINIC_ADMIN, ROLES.BRANCH_ADMIN),
  controller.createUser
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
  requireRole(ROLES.SUPER_ADMIN, ROLES.CLINIC_ADMIN),
  controller.deactivateAccount
);

// Public (no prior Firebase session) — forgot-password flow, separate from
// account creation.
router.post('/request-password-reset', authRateLimiter, controller.requestPasswordReset);

// Any authenticated user reading their own profile.
router.get('/me', verifyToken, controller.me);

module.exports = router;
