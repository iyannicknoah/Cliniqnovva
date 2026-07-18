const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/doctors.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

router.get('/', requireRole(ROLES.BRANCH_ADMIN, ROLES.RECEPTIONIST, ROLES.DOCTOR, ROLES.PATIENT), controller.list);
router.get('/:id', requireRole(ROLES.BRANCH_ADMIN, ROLES.RECEPTIONIST, ROLES.DOCTOR, ROLES.PATIENT), controller.getById);
router.post('/', requireRole(ROLES.BRANCH_ADMIN, ROLES.RECEPTIONIST), controller.create);
router.patch('/:id', requireRole(ROLES.BRANCH_ADMIN, ROLES.RECEPTIONIST), controller.update);
router.delete('/:id', requireRole(ROLES.BRANCH_ADMIN, ROLES.RECEPTIONIST), controller.remove);

module.exports = router;
