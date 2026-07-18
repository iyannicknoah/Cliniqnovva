const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth.middleware');
const { requireRole, ROLES } = require('../middleware/role.middleware');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/medicalRecords.controller');

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(requireAuth, attachScope);

router.get('/', requireRole(ROLES.DOCTOR, ROLES.NURSE, ROLES.PATIENT), controller.list);
router.get('/:id', requireRole(ROLES.DOCTOR, ROLES.NURSE, ROLES.PATIENT), controller.getById);
router.post('/', requireRole(ROLES.DOCTOR, ROLES.NURSE), controller.create);
router.patch('/:id', requireRole(ROLES.DOCTOR, ROLES.NURSE), controller.update);
router.delete('/:id', requireRole(ROLES.DOCTOR, ROLES.NURSE), controller.remove);

module.exports = router;
