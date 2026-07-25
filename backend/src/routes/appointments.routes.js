const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/appointments.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

// spec 6.7 roles: Receptionist (full management), Doctor (view own, mark
// complete — enforced in the controller, not here), Branch Admin/
// Clinic Admin (full oversight). No Patient role — there's no
// Patient App yet in this web-only build (master context: patients don't
// log in anywhere). Nurse added (Part 17 Task 3) for /nurse-today's
// "today's assigned patients" list — view only, never in MANAGE_ROLES/
// STATUS_ROLES, since a nurse doesn't book/manage/complete appointments.
const READ_ROLES = [
  ROLES.RECEPTIONIST,
  ROLES.BRANCH_ADMIN,
  ROLES.CLINIC_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.SUPER_ADMIN,
];
const MANAGE_ROLES = [ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];
// setStatus is broader than MANAGE_ROLES because a Doctor may mark their
// own appointment complete — the controller restricts exactly what a
// Doctor caller may do beyond just this role check.
const STATUS_ROLES = [...MANAGE_ROLES, ROLES.DOCTOR];

// Literal-segment routes ('available-slots', 'queue', 'book') MUST stay
// registered BEFORE the '/:id' catch-all below, or Express would capture
// them as an id value.
router.get('/available-slots', requireRole(...READ_ROLES), controller.getAvailableSlots);
router.get('/queue', requireRole(...READ_ROLES), controller.getQueueDisplay);
router.post('/book', requireRole(...MANAGE_ROLES), controller.book);

router.put('/:id/status', requireRole(...STATUS_ROLES), controller.setStatus);
router.put('/:id/reschedule', requireRole(...MANAGE_ROLES), controller.reschedule);

router.get('/:id', requireRole(...READ_ROLES), controller.getById);
router.get('/', requireRole(...READ_ROLES), controller.list);

module.exports = router;
