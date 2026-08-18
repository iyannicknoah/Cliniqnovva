const express = require('express');
const router = express.Router();
const multer = require('multer');
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/staff.controller');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 8 * 1024 * 1024 } });

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

// Read: admins + a Doctor viewing their own record/schedule (spec 6.5:
// "Doctor (view own)"). Accountant added 2026-07-26 — Reports/receipts
// need doctor names to resolve doctorId keys instead of showing raw ids.
const READ_ROLES = [ROLES.CLINIC_ADMIN, ROLES.BRANCH_ADMIN, ROLES.SUPER_ADMIN, ROLES.DOCTOR, ROLES.ACCOUNTANT];
router.get('/', requireRole(...READ_ROLES), controller.list);
router.get('/:id', requireRole(...READ_ROLES), controller.getById);
// Streams a doctor's uploaded photo bytes through our own API instead of a
// signed R2 URL (2026-08-17 — see `storage.service.js#getObjectBuffer`'s
// doc comment: the bucket has no CORS policy for browser origins, which
// silently broke `Image.network` in the wizard's Doctors step). Same
// READ_ROLES as the list/detail routes above — no new access granted.
router.get('/:id/photo-view', requireRole(...READ_ROLES), controller.viewPhoto);

// Create/edit/deactivate: admins only.
const MANAGE_ROLES = [ROLES.CLINIC_ADMIN, ROLES.BRANCH_ADMIN, ROLES.SUPER_ADMIN];
router.post('/', requireRole(...MANAGE_ROLES), controller.create);
router.patch('/:id', requireRole(...MANAGE_ROLES), controller.update);
router.put('/:id', requireRole(...MANAGE_ROLES), controller.update);
router.put('/:id/status', requireRole(...MANAGE_ROLES), controller.setStatus);
// Doctor profile photo ("Go Public" wizard's Doctors step, 2026-08-17) —
// same roles/shape as branches' own public image upload.
router.post('/:id/photo', requireRole(...MANAGE_ROLES), upload.single('file'), controller.uploadPhoto);

// Doctor schedule/availability (spec 6.5: "Branch Admin/Receptionist edit
// any doctor's schedule in their branch" — Doctor themself is view-only,
// covered by READ_ROLES above, not here).
const SCHEDULE_WRITE_ROLES = [
  ROLES.CLINIC_ADMIN,
  ROLES.BRANCH_ADMIN,
  ROLES.RECEPTIONIST,
  ROLES.SUPER_ADMIN,
];
router.put('/:doctorId/schedule', requireRole(...SCHEDULE_WRITE_ROLES), controller.setSchedule);
router.post('/:doctorId/blocked-slots', requireRole(...SCHEDULE_WRITE_ROLES), controller.addBlockedSlot);

router.delete('/:id', requireRole(...MANAGE_ROLES), controller.remove);

module.exports = router;
