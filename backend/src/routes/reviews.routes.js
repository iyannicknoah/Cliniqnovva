const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/reviews.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

// Part 16 Task 3 — the staff Reviews screen is Branch Admin/Clinic
// Admin (+ Super Admin oversight); hiding is narrower, Org Admin/Super
// Admin only, per the task's explicit parenthetical.
const STAFF_READ_ROLES = [ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];
const REPLY_ROLES = [ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];
const HIDE_ROLES = [ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];
// Part 17 Task 2 — /doctor-reviews: a doctor may read reviews, but only
// ever their own (controller.list() forces doctorId to the caller's own
// uid whenever role === 'doctor', ignoring any client-supplied value).
const READ_ROLES = [...STAFF_READ_ROLES, ROLES.DOCTOR];

router.get('/', requireRole(...READ_ROLES, ROLES.PATIENT), controller.list);

// Literal-segment routes registered BEFORE '/:id' (Express matches in order).
router.get('/popularity-rank', requireRole(...STAFF_READ_ROLES), controller.popularityRank);
router.post('/recalculate-popularity', requireRole(ROLES.SUPER_ADMIN), controller.recalculatePopularity);

router.get('/:id', requireRole(...READ_ROLES, ROLES.PATIENT), controller.getById);

// Create/edit/soft-delete: PATIENT only (the review's own author) — there's
// no Patient App yet (Part 16 brief), so these are fully built and correct
// with no caller today, same situation as Part 15's chat creation.
router.post('/', requireRole(ROLES.PATIENT), controller.create);
router.patch('/:id', requireRole(ROLES.PATIENT), controller.update);
router.delete('/:id', requireRole(ROLES.PATIENT), controller.remove);

router.post('/:id/reply', requireRole(...REPLY_ROLES), controller.reply);
router.patch('/:id/hide', requireRole(...HIDE_ROLES), controller.hide);

module.exports = router;
