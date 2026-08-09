const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/chats.controller');

// Kept only for routes/index.js's one-file-per-collection convention — see
// chats.controller.js's docstring: nothing in the client calls these, chat
// reads/writes go directly to Firestore instead (spec section 6.13, Part 15).
router.use(verifyToken, attachScope);

router.get('/', requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.DOCTOR), controller.list);
router.get('/:id', requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.DOCTOR), controller.getById);
router.post('/', requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN), controller.create);
router.patch('/:id', requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN), controller.update);
router.delete('/:id', requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN), controller.remove);

// Part 25 Task 4 — called by whichever client just wrote a message
// directly to Firestore (see chats.service.js's docstring); the handler
// itself decides whether a notification is actually warranted, so it's
// safe for either a staff or patient caller to hit this.
router.post(
  '/:id/notify-message',
  requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.DOCTOR, ROLES.NURSE),
  controller.notifyMessage
);

module.exports = router;
