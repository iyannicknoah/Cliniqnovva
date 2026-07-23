const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/staff.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

// Read: admins + a Doctor viewing their own record/schedule (spec 6.5:
// "Doctor (view own)").
const READ_ROLES = [ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN, ROLES.SUPER_ADMIN, ROLES.DOCTOR];
router.get('/', requireRole(...READ_ROLES), controller.list);
router.get('/:id', requireRole(...READ_ROLES), controller.getById);

// Create/edit/deactivate: admins only.
const MANAGE_ROLES = [ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN, ROLES.SUPER_ADMIN];
router.post('/', requireRole(...MANAGE_ROLES), controller.create);
router.patch('/:id', requireRole(...MANAGE_ROLES), controller.update);
router.put('/:id', requireRole(...MANAGE_ROLES), controller.update);
router.put('/:id/status', requireRole(...MANAGE_ROLES), controller.setStatus);

// Doctor schedule/availability (spec 6.5: "Branch Admin/Receptionist edit
// any doctor's schedule in their branch" — Doctor themself is view-only,
// covered by READ_ROLES above, not here).
const SCHEDULE_WRITE_ROLES = [
  ROLES.ORGANIZATION_ADMIN,
  ROLES.BRANCH_ADMIN,
  ROLES.RECEPTIONIST,
  ROLES.SUPER_ADMIN,
];
router.put('/:doctorId/schedule', requireRole(...SCHEDULE_WRITE_ROLES), controller.setSchedule);
router.post('/:doctorId/blocked-slots', requireRole(...SCHEDULE_WRITE_ROLES), controller.addBlockedSlot);

router.delete('/:id', requireRole(...MANAGE_ROLES), controller.remove);

module.exports = router;
