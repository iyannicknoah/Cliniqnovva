const express = require('express');
const router = express.Router();
const multer = require('multer');
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/branches.controller');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 8 * 1024 * 1024 } });

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

// Accountant added 2026-07-26 — Reports needs branch names to resolve
// branchId keys instead of showing raw ids.
const READ_ROLES = [ROLES.CLINIC_ADMIN, ROLES.BRANCH_ADMIN, ROLES.RECEPTIONIST, ROLES.SUPER_ADMIN, ROLES.ACCOUNTANT];

router.get('/', requireRole(...READ_ROLES), controller.list);
// NOTE: '/detail/:branchId' must stay registered BEFORE '/:clinicId',
// or 'detail' would be captured as a clinic id.
router.get('/detail/:branchId', requireRole(...READ_ROLES), controller.getById);
router.get('/:clinicId', requireRole(...READ_ROLES), controller.listByClinic);

router.post('/', requireRole(ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN), controller.create);

// Public-profile banner/logo image (Patient App browse visibility, onboarding
// Step 4). Same roles as create/update — Branch Admin doesn't manage this.
router.post(
  '/:branchId/image',
  requireRole(ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN),
  upload.single('file'),
  controller.uploadPublicImage
);
// Resolves publicImageKey to a signed R2 url for staff callers — the
// staff-side equivalent of browse.service.js's identical resolution for
// the Patient App, which is patient-only and unreachable from here.
router.get('/:branchId/image-url', requireRole(...READ_ROLES), controller.getPublicImageUrl);
// Streams the branch's public photo bytes through our own server (2026-08-19
// — same CORS fix as staff.routes.js's '/:id/photo-view'; see
// branches.service.js#getPublicImageBytes's doc comment). Powers the "Go
// Public" wizard's downloadable share card, which the signed url above
// can't render via Image.network in Flutter web.
router.get('/:branchId/image-view', requireRole(...READ_ROLES), controller.viewPublicImage);

// Branch Admin is allowed on plain update but the service restricts them to
// working-hours fields on their own branch only (Part 6 Task 3).
router.put('/:branchId/status', requireRole(ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN), controller.setStatus);
router.put(
  '/:branchId',
  requireRole(ROLES.CLINIC_ADMIN, ROLES.BRANCH_ADMIN, ROLES.SUPER_ADMIN),
  controller.update
);
// Back-compat with the pre-Part 6 shape.
router.patch('/:id', requireRole(ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN), controller.update);

router.delete('/:id', requireRole(ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN), controller.remove);

module.exports = router;
