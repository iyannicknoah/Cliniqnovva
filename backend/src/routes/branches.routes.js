const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/branches.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

const READ_ROLES = [ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN, ROLES.RECEPTIONIST, ROLES.SUPER_ADMIN];

router.get('/', requireRole(...READ_ROLES), controller.list);
// NOTE: '/detail/:branchId' must stay registered BEFORE '/:organizationId',
// or 'detail' would be captured as an organization id.
router.get('/detail/:branchId', requireRole(...READ_ROLES), controller.getById);
router.get('/:organizationId', requireRole(...READ_ROLES), controller.listByOrganization);

router.post('/', requireRole(ROLES.ORGANIZATION_ADMIN, ROLES.SUPER_ADMIN), controller.create);

// Branch Admin is allowed on plain update but the service restricts them to
// working-hours fields on their own branch only (Part 6 Task 3).
router.put('/:branchId/status', requireRole(ROLES.ORGANIZATION_ADMIN, ROLES.SUPER_ADMIN), controller.setStatus);
router.put(
  '/:branchId',
  requireRole(ROLES.ORGANIZATION_ADMIN, ROLES.BRANCH_ADMIN, ROLES.SUPER_ADMIN),
  controller.update
);
// Back-compat with the pre-Part 6 shape.
router.patch('/:id', requireRole(ROLES.ORGANIZATION_ADMIN, ROLES.SUPER_ADMIN), controller.update);

router.delete('/:id', requireRole(ROLES.ORGANIZATION_ADMIN, ROLES.SUPER_ADMIN), controller.remove);

module.exports = router;
