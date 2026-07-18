const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/chats.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

router.get('/', requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.DOCTOR), controller.list);
router.get('/:id', requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.DOCTOR), controller.getById);
router.post('/', requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN), controller.create);
router.patch('/:id', requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN), controller.update);
router.delete('/:id', requireRole(ROLES.PATIENT, ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN), controller.remove);

module.exports = router;
