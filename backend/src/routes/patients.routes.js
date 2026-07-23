const express = require('express');
const router = express.Router();
const multer = require('multer');
const { verifyToken } = require('../middleware/verifyToken');
const { requireRole, ROLES } = require('../middleware/requireRole');
const { attachScope } = require('../middleware/branchScope.middleware');
const controller = require('../controllers/patients.controller');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 15 * 1024 * 1024 } });

// Every route below is scoped by req.scope (branch/org isolation, spec section 10/11).
router.use(verifyToken, attachScope);

const READ_ROLES = [ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN, ROLES.DOCTOR, ROLES.NURSE, ROLES.SUPER_ADMIN];
const WRITE_ROLES = [ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN, ROLES.SUPER_ADMIN];
const CLINICAL_ROLES = [ROLES.DOCTOR, ROLES.NURSE, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN, ROLES.SUPER_ADMIN];

router.post('/', requireRole(...WRITE_ROLES), controller.create);
router.get('/check-duplicate', requireRole(...WRITE_ROLES), controller.checkDuplicate);

// NOTE: literal-segment routes ('detail', 'check-duplicate' above) MUST stay
// registered BEFORE the '/:organizationId' catch-all below, or Express would
// capture 'detail'/'check-duplicate' as an organizationId value.
router.get('/detail/:patientId', requireRole(...READ_ROLES), controller.getById);
router.put('/:patientId', requireRole(...WRITE_ROLES), controller.update);

router.post('/:patientId/medical-records', requireRole(ROLES.DOCTOR, ROLES.NURSE), controller.addMedicalRecord);

router.post('/:patientId/documents', requireRole(...CLINICAL_ROLES), upload.single('file'), controller.addDocument);
router.get('/:patientId/documents/:key/signed-url', requireRole(...CLINICAL_ROLES), controller.getDocumentSignedUrl);

router.delete('/:id', requireRole(...WRITE_ROLES), controller.remove);

// Search — the least specific route (single dynamic segment), registered
// LAST so every literal path above takes priority.
router.get('/:organizationId', requireRole(...READ_ROLES), controller.search);

module.exports = router;
