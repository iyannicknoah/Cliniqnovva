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

// Part 13 Task 2 — Pharmacist added so the dispense flow can search/look up
// a patient to select their prescriptions; getById() shapes the response
// down to prescriptions-only for this role (see patients.service.js).
// Accountant added 2026-07-26 — printing an invoice receipt needs the
// patient's name/phone, same as Receptionist; getById() gives Accountant
// the exact same clinical-data-free shape Receptionist already gets.
const READ_ROLES = [
  ROLES.RECEPTIONIST,
  ROLES.BRANCH_ADMIN,
  ROLES.CLINIC_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.PHARMACIST,
  ROLES.ACCOUNTANT,
  ROLES.SUPER_ADMIN,
];
const WRITE_ROLES = [ROLES.RECEPTIONIST, ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];
const CLINICAL_ROLES = [ROLES.DOCTOR, ROLES.NURSE, ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];
// Part 10 Task 2 — merge is deliberately narrower than WRITE_ROLES: no
// Receptionist, no Super Admin support exception. Spec says branch_admin/
// clinic_admin only.
const MERGE_ROLES = [ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN];

router.post('/', requireRole(...WRITE_ROLES), controller.create);
// Part 10 Task 3 — POST (was GET in Part 9; body now matches what
// POST /'s own built-in duplicate check uses).
router.post('/check-duplicate', requireRole(...WRITE_ROLES), controller.checkDuplicate);
router.post('/merge', requireRole(...MERGE_ROLES), controller.merge);

// NOTE: literal-segment routes ('detail' above) MUST stay registered
// BEFORE the '/:clinicId' catch-all below, or Express would capture
// 'detail' as a clinicId value.
router.get('/detail/:patientId', requireRole(...READ_ROLES), controller.getById);
router.put('/:patientId', requireRole(...WRITE_ROLES), controller.update);

router.post('/:patientId/medical-records', requireRole(ROLES.DOCTOR, ROLES.NURSE), controller.addMedicalRecord);

router.post('/:patientId/documents', requireRole(...CLINICAL_ROLES), upload.single('file'), controller.addDocument);
router.get('/:patientId/documents/:key/signed-url', requireRole(...CLINICAL_ROLES), controller.getDocumentSignedUrl);

router.delete('/:id', requireRole(...WRITE_ROLES), controller.remove);

// Search — the least specific route (single dynamic segment), registered
// LAST so every literal path above takes priority.
router.get('/:clinicId', requireRole(...READ_ROLES), controller.search);

module.exports = router;
