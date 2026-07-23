// Service layer for patients (spec section 6.5A / 6.6 / 6.6A / 9 — Part 9).
// Every patient in this web-only build is registered by front-desk staff
// (registeredVia: 'walkIn') — there is no Patient App yet.
//
// SECURITY-CRITICAL: getById()'s response is shaped per requester role.
// A receptionist must never receive diagnosis/prescription/document fields
// in the raw JSON — those keys are OMITTED entirely, not just left empty,
// so there is nothing sensitive in the payload even if the client ignored it.
const { randomUUID } = require('crypto');
const { db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');
const storageService = require('./storage.service');

const CLINICAL_ROLES = [ROLES.DOCTOR, ROLES.NURSE, ROLES.BRANCH_ADMIN, ROLES.ORGANIZATION_ADMIN, ROLES.SUPER_ADMIN];

function httpError(status, message) {
  const err = new Error(message);
  err.status = status;
  return err;
}

function digitsOnly(value) {
  return (value || '').replace(/\D/g, '');
}

function assertValidNationalId(nationalId) {
  if (nationalId === null || nationalId === undefined || nationalId === '') return;
  if (!/^\d{16}$/.test(nationalId)) {
    throw httpError(400, 'National ID must be exactly 16 digits');
  }
}

async function auditLog({ actorId, actorRole }, action, targetId, organizationId) {
  await db.collection('auditLogs').add({
    actorId: actorId || null,
    actorRole: actorRole || null,
    action,
    targetCollection: 'patients',
    targetId,
    organizationId,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Create a patient directly (spec 6.5A: phone is the only required
 * identifier — no smartphone/app account needed). Duplicate checking is a
 * separate, non-blocking step the client runs first via checkDuplicate();
 * this function does not itself reject a phone/nationalId that already
 * exists (full merge handling is Part 10's scope).
 */
async function create(
  { organizationId, branchId, name, phone, dateOfBirth, gender, nationalId, emergencyContact, location },
  actor
) {
  if (!name || !name.trim()) throw httpError(400, 'Full name is required');
  if (!phone || !phone.trim()) throw httpError(400, 'Phone is required');
  assertValidNationalId(nationalId);

  const data = {
    organizationId,
    branchId,
    name: name.trim(),
    nameLower: name.trim().toLowerCase(),
    phone: phone.trim(),
    phoneDigits: digitsOnly(phone),
    dateOfBirth: dateOfBirth || null,
    gender: gender || null,
    nationalId: nationalId || null,
    emergencyContact: emergencyContact || null,
    location: location || null,
    allergies: [],
    chronicConditions: [],
    registeredVia: 'walkIn',
    isActive: true,
    createdAt: new Date().toISOString(),
    createdBy: actor.actorId || null,
  };
  const ref = await db.collection('patients').add(data);
  await auditLog(actor, 'patient.registered', ref.id, organizationId);
  return { id: ref.id, ...data };
}

/**
 * Exact-match duplicate check on phone OR nationalId (spec 6.6A — full
 * merge UI lands in Part 10; this is the "show a warning" precursor Part 9
 * Task 2 explicitly calls for). Returns lightweight matches only.
 */
async function checkDuplicate({ organizationId, phone, nationalId }) {
  const phoneDigits = digitsOnly(phone);
  const queries = [];
  if (phoneDigits) {
    queries.push(
      db.collection('patients').where('organizationId', '==', organizationId).where('phoneDigits', '==', phoneDigits).get()
    );
  }
  if (nationalId) {
    queries.push(
      db.collection('patients').where('organizationId', '==', organizationId).where('nationalId', '==', nationalId).get()
    );
  }
  if (queries.length === 0) return [];

  const snapshots = await Promise.all(queries);
  const byId = {};
  snapshots.forEach((snap) =>
    snap.docs.forEach((doc) => {
      const d = doc.data();
      byId[doc.id] = { id: doc.id, name: d.name, phone: d.phone, nationalId: d.nationalId || null };
    })
  );
  return Object.values(byId);
}

/** Most recent medicalRecords.createdAt per patient, for the list's "last visit date" column. */
async function lastVisitDatesFor(patientIds) {
  if (patientIds.length === 0) return {};
  const snapshot = await db.collection('medicalRecords').where('patientId', 'in', patientIds.slice(0, 30)).get();
  const latest = {};
  snapshot.docs.forEach((doc) => {
    const { patientId, createdAt } = doc.data();
    if (!latest[patientId] || createdAt > latest[patientId]) latest[patientId] = createdAt;
  });
  return latest;
}

/**
 * Search by name (prefix, case-insensitive), phone, or National ID (spec
 * Part 9 Task 1) — one query box covers all three, merged and de-duplicated.
 */
async function search({ organizationId, branchId, q }) {
  const trimmed = (q || '').trim();
  const results = {};

  const addAll = (snap) => snap.docs.forEach((doc) => (results[doc.id] = { id: doc.id, ...doc.data() }));

  let base = db.collection('patients').where('organizationId', '==', organizationId);
  if (branchId) base = base.where('branchId', '==', branchId);

  if (!trimmed) {
    addAll(await base.orderBy('createdAt', 'desc').limit(50).get());
  } else {
    const digits = digitsOnly(trimmed);
    const lookups = [
      base
        .orderBy('nameLower')
        .where('nameLower', '>=', trimmed.toLowerCase())
        .where('nameLower', '<=', `${trimmed.toLowerCase()}`)
        .limit(25)
        .get(),
    ];
    if (digits.length >= 4) {
      lookups.push(base.where('phoneDigits', '==', digits).limit(25).get());
      lookups.push(base.where('nationalId', '==', digits).limit(25).get());
    }
    const snapshots = await Promise.all(lookups);
    snapshots.forEach(addAll);
  }

  const patients = Object.values(results);
  const lastVisit = await lastVisitDatesFor(patients.map((p) => p.id));
  return patients.map((p) => ({ ...p, lastVisitDate: lastVisit[p.id] || null }));
}

async function getRawById(id) {
  const doc = await db.collection('patients').doc(id).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() };
}

function assertAccess(patient, scope) {
  if (scope.level === 'platform') return;
  if (patient.organizationId !== scope.organizationId) {
    throw httpError(403, 'This patient belongs to a different organization');
  }
  if (scope.level === 'branch' && patient.branchId !== scope.branchId) {
    throw httpError(403, 'This patient belongs to a different branch');
  }
}

/**
 * Role-gated patient detail (Part 9 Task 3/DONE CONDITIONS):
 *   - Doctor/Branch Admin/Organization Admin/Super Admin: full medical
 *     records (diagnosis, prescriptions, notes) + documents.
 *   - Nurse: medical record entries present but stripped to vitals + basic
 *     metadata only — diagnosis/prescriptions/notes are OMITTED. Documents
 *     included (clinical staff).
 *   - Receptionist: demographics/contact ONLY — the `medicalRecords` and
 *     `documents` keys are omitted from the response entirely, not just
 *     emptied, so a receptionist-role request cannot see clinical fields
 *     even by inspecting the raw JSON.
 */
async function getById(id, actor) {
  const patient = await getRawById(id);
  if (!patient) return null;
  assertAccess(patient, actor.scope);

  const { role } = actor;
  if (role === ROLES.RECEPTIONIST || role === ROLES.PATIENT) {
    const { nameLower, phoneDigits, ...safe } = patient;
    return safe;
  }

  const recordsSnap = await db
    .collection('medicalRecords')
    .where('patientId', '==', id)
    .orderBy('createdAt', 'desc')
    .get();
  const records = recordsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  const medicalRecords =
    role === ROLES.NURSE
      ? records.map((r) => ({
          id: r.id,
          patientId: r.patientId,
          vitals: r.vitals || null,
          createdAt: r.createdAt,
          authorId: r.authorId,
        }))
      : records;

  const docsSnap = await db
    .collection('patients')
    .doc(id)
    .collection('documents')
    .orderBy('uploadedAt', 'desc')
    .get();
  const documents = docsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  const { nameLower, phoneDigits, ...safe } = patient;
  return { ...safe, medicalRecords, documents };
}

const EDITABLE_FIELDS = ['name', 'phone', 'dateOfBirth', 'gender', 'nationalId', 'emergencyContact', 'location'];

async function update(id, fields, actor) {
  const patient = await getRawById(id);
  if (!patient) throw httpError(404, 'Patient not found');
  assertAccess(patient, actor.scope);

  const updates = {};
  for (const key of EDITABLE_FIELDS) {
    if (fields[key] !== undefined) updates[key] = fields[key];
  }
  if ('name' in updates) {
    if (!updates.name || !updates.name.trim()) throw httpError(400, 'Full name cannot be empty');
    updates.name = updates.name.trim();
    updates.nameLower = updates.name.toLowerCase();
  }
  if ('phone' in updates) {
    if (!updates.phone || !updates.phone.trim()) throw httpError(400, 'Phone cannot be empty');
    updates.phone = updates.phone.trim();
    updates.phoneDigits = digitsOnly(updates.phone);
  }
  if ('nationalId' in updates) assertValidNationalId(updates.nationalId);
  if (Object.keys(updates).length === 0) throw httpError(400, 'No editable fields provided');

  await db.collection('patients').doc(id).update(updates);
  await auditLog(actor, 'patient.updated', id, patient.organizationId);
  return getById(id, actor);
}

/**
 * Medical record write (spec 6.5A/6.6, Part 9 Task 3/4 — doctor/nurse only,
 * enforced again here in addition to the route's requireRole as defense in
 * depth). Every write is tagged with authorId + createdAt (DONE CONDITION).
 * A Nurse's diagnosis/prescriptions are silently dropped even if sent —
 * only a Doctor's clinical assessment is ever stored under those fields.
 */
async function addMedicalRecord(patientId, { appointmentId, diagnosis, prescriptions, notes, vitals }, actor) {
  const patient = await getRawById(patientId);
  if (!patient) throw httpError(404, 'Patient not found');
  assertAccess(patient, actor.scope);

  if (![ROLES.DOCTOR, ROLES.NURSE].includes(actor.role)) {
    throw httpError(403, 'Only doctors and nurses can add medical records');
  }

  const isDoctor = actor.role === ROLES.DOCTOR;
  const data = {
    patientId,
    doctorId: isDoctor ? actor.actorId : null,
    appointmentId: appointmentId || null,
    diagnosis: isDoctor ? diagnosis || null : null,
    prescriptions: isDoctor && Array.isArray(prescriptions) ? prescriptions : [],
    notes: isDoctor ? notes || null : null,
    vitals: vitals || null,
    attachments: [],
    createdAt: new Date().toISOString(),
    authorId: actor.actorId || null,
  };
  const ref = await db.collection('medicalRecords').add(data);

  await db.collection('auditLogs').add({
    actorId: actor.actorId || null,
    actorRole: actor.role || null,
    action: 'medicalRecord.created',
    targetCollection: 'medicalRecords',
    targetId: ref.id,
    organizationId: patient.organizationId,
    timestamp: new Date().toISOString(),
  });

  return { id: ref.id, ...data };
}

const MAX_UPLOAD_BYTES = 15 * 1024 * 1024;

/**
 * Uploads a clinical document to R2 (private bucket, signed URLs only —
 * reuses storage.service.js, which already compresses images via sharp
 * before the PutObjectCommand). Only the object KEY is ever stored in
 * Firestore, never a URL (spec: "no permanent public links, ever").
 */
async function addDocument(patientId, { buffer, originalName, contentType }, actor) {
  const patient = await getRawById(patientId);
  if (!patient) throw httpError(404, 'Patient not found');
  assertAccess(patient, actor.scope);
  if (!CLINICAL_ROLES.includes(actor.role)) {
    throw httpError(403, 'Only clinical/admin staff can upload documents');
  }
  if (!buffer || buffer.length === 0) throw httpError(400, 'No file provided');
  if (buffer.length > MAX_UPLOAD_BYTES) throw httpError(400, 'File is too large (max 15MB)');

  const docId = randomUUID();
  const safeName = (originalName || 'document').replace(/[^a-zA-Z0-9._-]/g, '_');
  const key = `patients/${patientId}/documents/${docId}-${safeName}`;
  await storageService.uploadFile(buffer, key, contentType || 'application/octet-stream');

  const data = {
    key,
    originalName: originalName || safeName,
    contentType: contentType || 'application/octet-stream',
    uploadedAt: new Date().toISOString(),
    uploadedBy: actor.actorId || null,
  };
  await db.collection('patients').doc(patientId).collection('documents').doc(docId).set(data);

  await auditLog(actor, 'patient.documentUploaded', patientId, patient.organizationId);
  return { id: docId, ...data };
}

/**
 * A short-lived signed URL for one document (Part 9 Task 4: "role-gated" —
 * a receptionist must be refused here even if they somehow have the key,
 * not just have the Documents tab hidden client-side).
 */
async function getDocumentSignedUrl(patientId, key, actor) {
  const patient = await getRawById(patientId);
  if (!patient) throw httpError(404, 'Patient not found');
  assertAccess(patient, actor.scope);
  if (!CLINICAL_ROLES.includes(actor.role)) {
    throw httpError(403, 'You are not allowed to view clinical documents');
  }

  // Confirm the key actually belongs to a document on THIS patient — never
  // trust a client-supplied key to sign an arbitrary R2 object.
  const docsSnap = await db
    .collection('patients')
    .doc(patientId)
    .collection('documents')
    .where('key', '==', key)
    .limit(1)
    .get();
  if (docsSnap.empty) throw httpError(404, 'Document not found');

  return storageService.getSignedDownloadUrl(key);
}

module.exports = {
  create,
  checkDuplicate,
  search,
  getById,
  update,
  addMedicalRecord,
  addDocument,
  getDocumentSignedUrl,
};
