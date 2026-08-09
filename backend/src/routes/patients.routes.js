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
// Laboratorian added 2026-07-29 — needs to look up the right patient for a
// pending lab order; getById() shapes the response down to lab-orders-only
// for this role (see patients.service.js). Deliberately NOT added to
// CLINICAL_ROLES below — that gates full diagnosis/prescription/document
// visibility, which a Laboratorian must never see.
const READ_ROLES = [
  ROLES.RECEPTIONIST,
  ROLES.BRANCH_ADMIN,
  ROLES.CLINIC_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.PHARMACIST,
  ROLES.ACCOUNTANT,
  ROLES.LABORATORIAN,
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
// Part 25 — Patient App's chat feature (before writing a /chats doc
// directly to Firestore, it needs its own walk-in patientId for that
// clinic). PATIENT-only, same as the other Part 21-24 patient-facing
// additions below.
router.post('/resolve-for-clinic', requireRole(ROLES.PATIENT), controller.resolveForClinic);

// NOTE: literal-segment routes ('detail' above) MUST stay registered
// BEFORE the '/:clinicId' catch-all below, or Express would capture
// 'detail' as a clinicId value.
router.get('/detail/:patientId', requireRole(...READ_ROLES), controller.getById);
router.put('/:patientId', requireRole(...WRITE_ROLES), controller.update);

router.post('/:patientId/medical-records', requireRole(ROLES.DOCTOR, ROLES.NURSE), controller.addMedicalRecord);
// Part 23 — Patient App's Medical Records screen. Deliberately PATIENT-only
// (not READ_ROLES too) — staff already read this same data, role-shaped,
// through GET /detail/:patientId; this is a dedicated full-detail path for
// the record's own patient, ownership-enforced in the controller/service,
// not a staff-facing route.
router.get('/:patientId/medical-records', requireRole(ROLES.PATIENT), controller.getMedicalRecords);

router.post('/:patientId/documents', requireRole(...CLINICAL_ROLES), upload.single('file'), controller.addDocument);
// PATIENT added Part 23 — a patient may view their OWN document's signed
// URL (their own lab results/X-rays); patients.service.js's
// getDocumentSignedUrl() branches to an ownership check for this role
// instead of the CLINICAL_ROLES/clinic-scope check every staff caller
// still goes through.
router.get(
  '/:patientId/documents/:key/signed-url',
  requireRole(...CLINICAL_ROLES, ROLES.PATIENT),
  controller.getDocumentSignedUrl
);

// Part 22 — Patient App's My Bookings screen. PATIENT added alongside the
// existing staff READ_ROLES; the controller enforces ownership for a
// patient caller (their own linked record only) instead of clinic scope.
router.get('/:patientId/appointments', requireRole(...READ_ROLES, ROLES.PATIENT), controller.getAppointments);

// Part 23 — Patient App's Receipts screen. Same PATIENT-only, ownership-
// enforced-in-controller shape as medical-records above.
router.get('/:patientId/invoices', requireRole(ROLES.PATIENT), controller.getInvoices);

// Part 24 — Patient App's My Reviews screen. Same PATIENT-only, ownership-
// enforced-in-controller shape as medical-records/invoices above.
router.get('/:patientId/reviews', requireRole(ROLES.PATIENT), controller.getReviews);

router.delete('/:id', requireRole(...WRITE_ROLES), controller.remove);

// Search — the least specific route (single dynamic segment), registered
// LAST so every literal path above takes priority.
router.get('/:clinicId', requireRole(...READ_ROLES), controller.search);

module.exports = router;
