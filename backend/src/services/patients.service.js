// Service layer for patients (spec section 6.5A / 6.6 / 6.6A / 9 — Part 9).
// create() below is still the WALK-IN path only (registeredVia: 'walkIn',
// always clinic-scoped) — front-desk staff calling POST /api/patients.
// The Patient App's self-registration (Part 19) is a separate path that
// doesn't create a /patients doc at all unless it must: it writes the
// account's own identity to /users/{uid} (see auth.service.js#
// registerPatientAccount) and, if the patient matches an existing walk-in
// record, links to it via linkPatientAccount() below instead of ever
// touching create(). See docs/technical-spec.md's /patients schema note:
// "extends /users via same ID" was the ORIGINAL intent, but the Part 9
// build gave every walk-in patient its own auto-ID doc rather than reusing
// a uid (there is no uid at walk-in time) — linkedAppAccountId is the join
// between the two instead of a shared document ID.
//
// SECURITY-CRITICAL: getById()'s response is shaped per requester role.
// A receptionist must never receive diagnosis/prescription/document fields
// in the raw JSON — those keys are OMITTED entirely, not just left empty,
// so there is nothing sensitive in the payload even if the client ignored it.
const { randomUUID } = require('crypto');
const { db } = require('../config/firebase-admin');
const { ROLES } = require('../middleware/requireRole');
const storageService = require('./storage.service');
const auditLogService = require('./auditLog.service');

const CLINICAL_ROLES = [ROLES.DOCTOR, ROLES.NURSE, ROLES.BRANCH_ADMIN, ROLES.CLINIC_ADMIN, ROLES.SUPER_ADMIN];

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

/**
 * Create a patient directly (spec 6.5A: phone is the only required
 * identifier — no smartphone/app account needed).
 *
 * Part 10 Task 1: before creating, this checks for an existing patient
 * matching phone OR nationalId. A match throws a distinguishable
 * "possible duplicate" error (status 409, `possibleDuplicate: true`,
 * `matches`) INSTEAD of creating — the caller (controller) shapes that
 * into the UI's "Is this the same person?" prompt. Passing
 * `confirmedDuplicate: true` skips the check entirely (the user already
 * saw the prompt and chose "No, create new patient").
 */
async function create(
  {
    clinicId,
    branchId,
    name,
    phone,
    dateOfBirth,
    gender,
    nationalId,
    emergencyContact,
    location,
    confirmedDuplicate,
  },
  actor
) {
  if (!name || !name.trim()) throw httpError(400, 'Full name is required');
  if (!phone || !phone.trim()) throw httpError(400, 'Phone is required');
  assertValidNationalId(nationalId);

  if (!confirmedDuplicate) {
    const matches = await checkDuplicate({ clinicId, phone, nationalId });
    if (matches.length > 0) {
      const err = httpError(409, 'A patient with this phone or National ID may already exist');
      err.possibleDuplicate = true;
      err.matches = matches;
      throw err;
    }
  }

  const data = {
    clinicId,
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
  return { id: ref.id, ...data };
}

/**
 * Exact-match duplicate check on phone OR nationalId (spec 6.6A). Excludes
 * patients already merged away (isActive: false) — a record deactivated by
 * a prior merge shouldn't keep surfacing as a "possible duplicate" forever.
 * Returns lightweight matches only.
 *
 * `clinicId` is optional (Part 19) — staff calls (POST /api/patients/
 * check-duplicate) always pass their own scoped clinicId and this behaves
 * exactly as before. The Patient App's self-registration flow (POST
 * /api/auth/patient/check-duplicate) omits it: a self-registering patient
 * doesn't belong to a clinic yet, and the walk-in record they might be
 * matching against could be at ANY clinic, so the query drops the clinicId
 * filter entirely and searches the whole collection. Matches then also
 * carry `clinicId`/`clinicName` so the app can show "we found a record at
 * [Clinic Name]".
 */
async function checkDuplicate({ clinicId, phone, nationalId }) {
  const phoneDigits = digitsOnly(phone);
  const queries = [];
  const scoped = (q) => (clinicId ? q.where('clinicId', '==', clinicId) : q);
  if (phoneDigits) {
    queries.push(scoped(db.collection('patients')).where('phoneDigits', '==', phoneDigits).get());
  }
  if (nationalId) {
    queries.push(scoped(db.collection('patients')).where('nationalId', '==', nationalId).get());
  }
  if (queries.length === 0) return [];

  const snapshots = await Promise.all(queries);
  const byId = {};
  snapshots.forEach((snap) =>
    snap.docs.forEach((doc) => {
      const d = doc.data();
      if (d.isActive === false) return;
      byId[doc.id] = {
        id: doc.id,
        name: d.name,
        phone: d.phone,
        nationalId: d.nationalId || null,
        clinicId: d.clinicId || null,
      };
    })
  );
  const matches = Object.values(byId);
  if (clinicId || matches.length === 0) return matches; // caller already knows its own clinic name

  const clinicIds = [...new Set(matches.map((m) => m.clinicId).filter(Boolean))];
  const clinicDocs = await Promise.all(clinicIds.map((id) => db.collection('clinics').doc(id).get()));
  const clinicNames = {};
  clinicDocs.forEach((doc) => {
    if (doc.exists) clinicNames[doc.id] = doc.data().name || null;
  });
  return matches.map((m) => ({ ...m, clinicName: m.clinicId ? clinicNames[m.clinicId] || null : null }));
}

/**
 * Links a self-registered app account to an existing walk-in patient
 * record (Part 19, spec 6.5A: "if the patient later installs the Patient
 * App, they can be linked to their existing record ... rather than
 * creating a duplicate"). Re-verifies server-side that the phone/
 * nationalId the app account is registering with actually matches the
 * target record — a client only ever learns a patientId from its own
 * checkDuplicate() call, but this stops a tampered request from linking
 * (and thereby reading, via getById's ROLES.PATIENT branch — a later
 * part's concern) an arbitrary patient record it was never shown.
 * `registeredVia` is deliberately left as `'walkIn'` — linking doesn't
 * change how the record originated, only that it now also has app access.
 */
async function linkPatientAccount({ patientId, uid, phone, nationalId }) {
  const ref = db.collection('patients').doc(patientId);
  const doc = await ref.get();
  if (!doc.exists) throw httpError(404, 'Patient record not found');
  const d = doc.data();
  if (d.isActive === false) throw httpError(409, 'This patient record is no longer active');

  const phoneDigits = digitsOnly(phone);
  const matchesPhone = Boolean(phoneDigits) && d.phoneDigits === phoneDigits;
  const matchesNationalId = Boolean(nationalId) && d.nationalId === nationalId;
  if (!matchesPhone && !matchesNationalId) {
    throw httpError(403, "This record's phone/National ID doesn't match what you entered");
  }

  await ref.update({ linkedAppAccountId: uid });
  return { id: patientId, ...d, linkedAppAccountId: uid };
}

/**
 * Resolves the /patients/{id} record a self-registered Patient App account
 * should book against for one clinic (Part 21) — reuses an existing linked
 * walk-in record for that clinic if the account already has one (from
 * checkDuplicate+linkPatientAccount at registration, or a prior call to
 * this function), otherwise silently provisions a fresh app-originated one
 * from the account's own /users profile. This is deliberately NOT the
 * registration-time "is this you?" duplicate-check flow again — a patient
 * who registered and found no match has already been searched cross-clinic
 * once; a true duplicate this can't catch (a walk-in record created at this
 * clinic independently, after registration) is left for staff to notice and
 * fix with the existing Merge Patients tool, same as any other duplicate.
 */
async function getOrCreatePatientRecordForClinic({ uid, clinicId, branchId }) {
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) throw httpError(404, 'Patient account not found');
  const user = userDoc.data();

  const linkedIds = user.linkedPatientIds || [];
  if (linkedIds.length > 0) {
    const linkedDocs = await Promise.all(linkedIds.map((id) => db.collection('patients').doc(id).get()));
    const existing = linkedDocs.find(
      (d) => d.exists && d.data().clinicId === clinicId && d.data().isActive !== false
    );
    if (existing) return { id: existing.id, ...existing.data() };
  }

  const data = {
    clinicId,
    branchId: branchId || null,
    name: user.name,
    nameLower: (user.name || '').toLowerCase(),
    phone: user.phone || null,
    phoneDigits: user.phoneDigits || null,
    dateOfBirth: null,
    gender: null,
    nationalId: user.nationalId || null,
    emergencyContact: null,
    location: null,
    allergies: [],
    chronicConditions: [],
    registeredVia: 'app',
    linkedAppAccountId: uid,
    isActive: true,
    createdAt: new Date().toISOString(),
    createdBy: uid,
  };
  const ref = await db.collection('patients').add(data);

  await db
    .collection('users')
    .doc(uid)
    .set({ linkedPatientIds: [...linkedIds, ref.id] }, { merge: true });

  return { id: ref.id, ...data };
}

/**
 * True if [patientId]'s /patients record is linked to [uid] — the
 * ownership check a Patient App caller must pass before touching an
 * appointment/review/etc. that references a walk-in patientId rather than
 * their own uid directly (Part 21).
 */
async function isPatientRecordOwnedBy(patientId, uid) {
  if (!patientId || !uid) return false;
  const doc = await db.collection('patients').doc(patientId).get();
  return doc.exists && doc.data().linkedAppAccountId === uid;
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
async function search({ clinicId, branchId, q }) {
  const trimmed = (q || '').trim();
  const results = {};

  const addAll = (snap) => snap.docs.forEach((doc) => (results[doc.id] = { id: doc.id, ...doc.data() }));

  let base = db.collection('patients').where('clinicId', '==', clinicId);
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

  // Records merged away by Part 10's merge tool (isActive: false) shouldn't
  // appear as a separate result — the surviving record is the one to find.
  const patients = Object.values(results).filter((p) => p.isActive !== false);
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
  if (patient.clinicId !== scope.clinicId) {
    throw httpError(403, 'This patient belongs to a different clinic');
  }
  if (scope.level === 'branch' && patient.branchId !== scope.branchId) {
    throw httpError(403, 'This patient belongs to a different branch');
  }
}

/**
 * Role-gated patient detail (Part 9 Task 3/DONE CONDITIONS; extended Part 13
 * Task 2 for Pharmacist):
 *   - Doctor/Branch Admin/Clinic Admin/Super Admin: full medical
 *     records (diagnosis, prescriptions, notes) + documents.
 *   - Nurse: medical record entries present but stripped to vitals + basic
 *     metadata only — diagnosis/prescriptions/notes are OMITTED. Documents
 *     included (clinical staff).
 *   - Pharmacist: medical record entries stripped to PRESCRIPTIONS only —
 *     diagnosis/notes/vitals are OMITTED (a pharmacist dispensing a
 *     medication has no clinical need to see the diagnosis behind it). No
 *     `documents` key either — lab results/scans aren't relevant to
 *     dispensing, same "omit entirely" shaping as the Receptionist case.
 *   - Receptionist: demographics/contact ONLY — the `medicalRecords` and
 *     `documents` keys are omitted from the response entirely, not just
 *     emptied, so a receptionist-role request cannot see clinical fields
 *     even by inspecting the raw JSON.
 *   - Laboratorian (2026-07-29): demographics (to identify the right
 *     patient) + a `labOrders` key projected to test name/status/result
 *     fields only. No `medicalRecords` key at all (not even a narrowed
 *     one — diagnosis/prescriptions/notes/vitals are never relevant to
 *     performing a lab test) and no `documents` key, same "omit entirely"
 *     shaping as every other restricted tier here.
 */
async function getById(id, actor) {
  const patient = await getRawById(id);
  if (!patient) return null;
  assertAccess(patient, actor.scope);

  const { role } = actor;
  // Accountant (2026-07-26) — needs a patient's name/phone to print an
  // invoice receipt, same clinical-data-free shape as Receptionist.
  if (role === ROLES.RECEPTIONIST || role === ROLES.PATIENT || role === ROLES.ACCOUNTANT) {
    const { nameLower, phoneDigits, ...safe } = patient;
    return safe;
  }

  if (role === ROLES.LABORATORIAN) {
    // orderedAt, not createdAt — lab order docs never had a createdAt field
    // (see labOrders.service.js#create's actual write shape); ordering by a
    // field that doesn't exist on any document silently excluded every
    // order AND, without the resulting composite index deployed, could
    // throw outright — breaking this whole getById call for a Laboratorian
    // caller specifically (2026-08-19, found while fixing "patient name
    // blank on the Lab Orders screen").
    const labOrdersSnap = await db.collection('labOrders').where('patientId', '==', id).orderBy('orderedAt', 'desc').get();
    const labOrders = labOrdersSnap.docs.map((doc) => {
      const o = doc.data();
      return {
        id: doc.id,
        patientId: o.patientId,
        testName: o.testName,
        status: o.status,
        resultValue: o.resultValue || null,
        resultUnit: o.resultUnit || null,
        collectedAt: o.collectedAt || null,
        resultedAt: o.resultedAt || null,
      };
    });
    const { nameLower, phoneDigits, ...safe } = patient;
    return { ...safe, labOrders };
  }

  const recordsSnap = await db
    .collection('medicalRecords')
    .where('patientId', '==', id)
    .orderBy('createdAt', 'desc')
    .get();
  const records = recordsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

  if (role === ROLES.PHARMACIST) {
    const medicalRecords = records.map((r) => ({
      id: r.id,
      patientId: r.patientId,
      prescriptions: r.prescriptions || [],
      createdAt: r.createdAt,
      authorId: r.authorId,
    }));
    const { nameLower, phoneDigits, ...safe } = patient;
    return { ...safe, medicalRecords };
  }

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

  // Appointment/invoice counts — mainly for Part 10's merge preview
  // ("appointment/record/invoice counts" side by side). Both collections
  // are still empty system-wide until the booking/billing parts are built,
  // so these are 0 for everyone today; wired now so merge counts are
  // already correct once real data exists, nothing to revisit later.
  const [apptCountSnap, invoiceCountSnap] = await Promise.all([
    db.collection('appointments').where('patientId', '==', id).count().get(),
    db.collection('invoices').where('patientId', '==', id).count().get(),
  ]);

  const { nameLower, phoneDigits, ...safe } = patient;
  return {
    ...safe,
    medicalRecords,
    documents,
    appointmentCount: apptCountSnap.data().count,
    invoiceCount: invoiceCountSnap.data().count,
  };
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
  return { id: docId, ...data };
}

/**
 * A short-lived signed URL for one document (Part 9 Task 4: "role-gated" —
 * a receptionist must be refused here even if they somehow have the key,
 * not just have the Documents tab hidden client-side). Part 23 — the
 * PATIENT the document belongs to may also view it (their own lab
 * results/X-rays), via ownership rather than the CLINICAL_ROLES/clinic-
 * scope check every staff caller goes through: `assertAccess` compares
 * against `actor.scope.clinicId`, which is always undefined for a
 * patient's `{level:'patient'}` scope (same class of bug fixed repeatedly
 * in Parts 21/22 — see appointments/invoices/reviews controllers), so a
 * patient actor takes a completely separate branch here instead of being
 * routed through it.
 */
async function getDocumentSignedUrl(patientId, key, actor) {
  const patient = await getRawById(patientId);
  if (!patient) throw httpError(404, 'Patient not found');

  if (actor.role === ROLES.PATIENT) {
    const owns = await isPatientRecordOwnedBy(patientId, actor.actorId);
    if (!owns) throw httpError(403, 'You can only view your own documents');
  } else {
    assertAccess(patient, actor.scope);
    if (!CLINICAL_ROLES.includes(actor.role)) {
      throw httpError(403, 'You are not allowed to view clinical documents');
    }
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
  const doc = docsSnap.docs[0].data();

  const url = await storageService.getSignedDownloadUrl(key);
  return { url, contentType: doc.contentType || null, originalName: doc.originalName || null };
}

/**
 * Part 23 — the Patient App's Medical Records screen. Full clinical detail
 * (diagnosis/prescriptions/notes/vitals), unlike the receptionist-tier
 * shape `getById()` gives `ROLES.PATIENT` today (Part 19 added the role
 * there defensively, before this screen existed — that path stays
 * unchanged, this is a dedicated one instead). No "doctor's notes marked
 * patient-visible" flag exists on `/medicalRecords` docs (see
 * `addMedicalRecord()` above) — per Part 23's own instruction, every
 * note is shown as-is; flagged here as worth revisiting if a real
 * internal-only/patient-visible split is ever added to that schema.
 * Bundles `documents` into the same response — the documents subcollection
 * has no visit/appointment linkage in this schema (`addDocument()` never
 * captured one), so there is no real per-visit grouping to expose; this
 * returns the patient's full flat document list once, alongside the
 * records, rather than pretending a document belongs to one visit.
 */
async function getMedicalRecordsAndDocumentsForPatient(patientId, uid) {
  const patient = await getRawById(patientId);
  if (!patient) throw httpError(404, 'Patient not found');
  const owns = await isPatientRecordOwnedBy(patientId, uid);
  if (!owns) throw httpError(403, 'You can only view your own medical records');

  const [recordsSnap, docsSnap] = await Promise.all([
    db.collection('medicalRecords').where('patientId', '==', patientId).get(),
    db.collection('patients').doc(patientId).collection('documents').get(),
  ]);

  const records = recordsSnap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
  const documents = docsSnap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .sort((a, b) => (a.uploadedAt < b.uploadedAt ? 1 : -1));

  return { records, documents };
}

const REASSIGNED_COLLECTIONS = ['appointments', 'medicalRecords', 'invoices'];

/**
 * Part 10 Task 2 — merges [mergedPatientId] into [survivingPatientId]:
 * every appointment/medicalRecord/invoice pointing at the merged patient is
 * reassigned (patientId field updated) to the survivor — nothing lost, per
 * the DONE CONDITION. The merged record itself is DEACTIVATED (isActive:
 * false), never deleted (master rule 10: never hard-delete a record with
 * dependent history). Logged to /patientMergeLogs with both ids.
 *
 * NOTE: clinical documents (patients/{id}/documents subcollection, Part 9)
 * are intentionally NOT moved — Task 2's reassignment list is appointments/
 * medicalRecords/invoices only, and subcollection documents would need a
 * copy+delete rather than a field update. The merged record staying
 * deactivated (not deleted) means its uploaded documents remain reachable
 * by anyone who still has that patient id, just not through the survivor.
 */
async function mergePatients({ survivingPatientId, mergedPatientId }, actor) {
  if (!survivingPatientId || !mergedPatientId) {
    throw httpError(400, 'survivingPatientId and mergedPatientId are required');
  }
  if (survivingPatientId === mergedPatientId) {
    throw httpError(400, 'Cannot merge a patient into itself');
  }

  const [surviving, merged] = await Promise.all([getRawById(survivingPatientId), getRawById(mergedPatientId)]);
  if (!surviving) throw httpError(404, 'Surviving patient not found');
  if (!merged) throw httpError(404, 'Patient to merge not found');
  assertAccess(surviving, actor.scope);
  assertAccess(merged, actor.scope);
  if (surviving.clinicId !== merged.clinicId) {
    throw httpError(400, 'Both patients must belong to the same clinic');
  }

  const reassignedCounts = {};
  for (const collectionName of REASSIGNED_COLLECTIONS) {
    const snap = await db.collection(collectionName).where('patientId', '==', mergedPatientId).get();
    await Promise.all(snap.docs.map((doc) => doc.ref.update({ patientId: survivingPatientId })));
    reassignedCounts[collectionName] = snap.size;
  }

  await db.collection('patients').doc(mergedPatientId).update({
    isActive: false,
    mergedInto: survivingPatientId,
  });

  const mergeLogRef = await db.collection('patientMergeLogs').add({
    survivingPatientId,
    mergedPatientId,
    mergedBy: actor.actorId || null,
    timestamp: new Date().toISOString(),
  });
  await auditLogService.write({
    actorId: actor.actorId,
    actorRole: actor.actorRole,
    clinicId: surviving.clinicId,
    action: 'patient.merged',
    targetCollection: 'patients',
    targetId: survivingPatientId,
  });

  return {
    survivingPatient: await getById(survivingPatientId, actor),
    reassignedCounts,
    mergeLogId: mergeLogRef.id,
  };
}

module.exports = {
  create,
  checkDuplicate,
  linkPatientAccount,
  getOrCreatePatientRecordForClinic,
  isPatientRecordOwnedBy,
  getMedicalRecordsAndDocumentsForPatient,
  search,
  getById,
  getRawById,
  update,
  addMedicalRecord,
  addDocument,
  getDocumentSignedUrl,
  mergePatients,
  digitsOnly,
};
