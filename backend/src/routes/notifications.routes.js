const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/notifications.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

const ANY_ROLE = [
  ROLES.SUPER_ADMIN,
  ROLES.CLINIC_ADMIN,
  ROLES.BRANCH_ADMIN,
  ROLES.RECEPTIONIST,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.PHARMACIST,
  ROLES.ACCOUNTANT,
  ROLES.PATIENT,
];

router.get('/', requireRole(...ANY_ROLE), controller.list);
// This collection's CONTENT is system-written only — the two routes below
// are the one deliberate exception: a caller may toggle the read flag on
// THEIR OWN notifications, never anyone else's and never the message
// itself (enforced in notifications.service.js's markRead()).
router.patch('/read-all', requireRole(...ANY_ROLE), controller.markAllRead);
router.patch('/:id/read', requireRole(...ANY_ROLE), controller.markRead);

module.exports = router;
