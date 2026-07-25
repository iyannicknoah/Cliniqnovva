// Part 18 Task 5 — Demo data seed script.
//
// Creates one single-branch clinic and one multi-branch clinic
// (Kimihurura + Remera), fully staffed and populated with patients,
// appointments (past/completed with invoices+reviews, and upcoming),
// invoices, and reviews. Every account is created through the SAME
// authService.createStaffAccountWithPassword() path a real Super Admin
// uses (backend/src/services/auth.service.js) — active immediately, no
// invite link, no email/SMS ever sent (there is no email/SMS-sending
// dependency anywhere in package.json). This script goes through the real
// service-layer functions (not raw Firestore writes) wherever a service
// function exists, so seeded data obeys the exact same validation/business
// rules real usage would (server-recalculated invoice totals, the booking
// conflict check, the review edit window, etc.) — it's the same code path
// Part 18's integration tests already verify in isolation.
//
// DEMO PASSWORD (all accounts, deliberately uniform for a demo — never
// reuse this pattern for a real paying clinic): see docs/demo-accounts.md
//
// Usage:
//   cd backend && node scripts/seedDemoData.js
// Reads whatever backend/.env.<NODE_ENV> already points at (see
// src/config/env.js) — defaults to NODE_ENV=development, i.e. the
// `cliniqnovva-dev` Firebase project (firebase/.firebaserc). This script
// is NOT idempotent — running it twice creates duplicate accounts/data
// (Firebase Auth will reject a re-used email with auth/email-already-
// exists, so a second run fails loudly rather than silently duplicating
// accounts, but Firestore documents with no such uniqueness check, like
// patients/appointments, WOULD duplicate). Meant for a fresh dev/demo
// project, not to be run repeatedly against the same one.
const { db } = require('../src/config/firebase-admin');
const { ROLES } = require('../src/middleware/requireRole');
const authService = require('../src/services/auth.service');
const clinicsService = require('../src/services/clinics.service');
const branchesService = require('../src/services/branches.service');
const departmentsService = require('../src/services/departments.service');
const servicesService = require('../src/services/services.service');
const staffService = require('../src/services/staff.service');
const patientsService = require('../src/services/patients.service');
const appointmentsService = require('../src/services/appointments.service');
const invoicesService = require('../src/services/invoices.service');
const reviewsService = require('../src/services/reviews.service');

const DEMO_PASSWORD = 'Cliniq2027!Demo';
const SEEDER = { actorId: 'seed-script', actorRole: 'super_admin', role: 'super_admin', scope: { level: 'platform' } };

const createdAccounts = []; // {email, password, role, org, branch}

function record(email, role, org, branch) {
  createdAccounts.push({ email, password: DEMO_PASSWORD, role, org, branch: branch || '—' });
}

function actorFor({ uid, role, clinicId, branchId }) {
  const level = role === ROLES.SUPER_ADMIN ? 'platform' : role === ROLES.CLINIC_ADMIN ? 'clinic' : 'branch';
  const scope =
    level === 'platform'
      ? { level: 'platform' }
      : level === 'clinic'
        ? { level: 'clinic', clinicId }
        : { level: 'branch', clinicId, branchId };
  return { actorId: uid, role, actorRole: role, scope };
}

function isoDaysFromNow(days) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

async function createStaff({ email, name, role, clinicId, branchId, phone, specialty }) {
  const { uid } = await authService.createStaffAccountWithPassword({
    email,
    password: DEMO_PASSWORD,
    name,
    role,
    clinicId,
    branchId,
    phone,
    createdBy: SEEDER.actorId,
  });
  record(email, role, clinicId, branchId);
  return uid;
}

async function createDoctorWithSchedule({ email, name, clinicId, branchId, phone, specialty, departmentIds, schedule }) {
  const uid = await staffService.create(
    { email, password: DEMO_PASSWORD, name, role: ROLES.DOCTOR, clinicId, branchId, phone, specialty, departmentIds },
    actorFor({ uid: SEEDER.actorId, role: ROLES.SUPER_ADMIN })
  ).then((r) => r.id);
  record(email, ROLES.DOCTOR, clinicId, branchId);
  await staffService.setSchedule(uid, schedule, actorFor({ uid: SEEDER.actorId, role: ROLES.SUPER_ADMIN, clinicId, branchId }));
  return uid;
}

const WEEKDAY_SCHEDULE = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'].map((day) => ({
  day,
  startTime: '08:00',
  endTime: '16:00',
  slotDurationMins: 20,
}));

async function seedPatients(clinicId, branchId, list) {
  const ids = [];
  for (const p of list) {
    const patient = await patientsService.create(
      { clinicId, branchId, confirmedDuplicate: true, ...p },
      actorFor({ uid: 'seed-receptionist', role: ROLES.RECEPTIONIST, clinicId, branchId })
    );
    ids.push(patient.id);
  }
  return ids;
}

/**
 * Books an appointment and, depending on `outcome`, drives it through the
 * real status state machine — 'completed' triggers the SAME auto-invoice
 * generation real usage does, then records a payment and leaves a review;
 * 'upcoming' stays pending/confirmed; 'cancelled' exercises the
 * slot-freeing path integration tests also cover.
 */
async function seedAppointment({ clinicId, branchId, patientId, doctorId, serviceId, date, startTime, endTime, outcome, payment, review }) {
  const staffActor = actorFor({ uid: 'seed-receptionist', role: ROLES.RECEPTIONIST, clinicId, branchId });
  let appt = await appointmentsService.book(
    { clinicId, branchId, patientId, doctorId, serviceId, date, startTime, endTime },
    staffActor
  );

  if (outcome === 'confirmed' || outcome === 'completed' || outcome === 'cancelled') {
    appt = await appointmentsService.setStatus(appt.id, 'confirmed', staffActor);
  }
  if (outcome === 'cancelled') {
    return appointmentsService.setStatus(appt.id, 'cancelled', staffActor);
  }
  if (outcome === 'completed') {
    appt = await appointmentsService.setStatus(appt.id, 'checkedIn', staffActor);
    appt = await appointmentsService.setStatus(appt.id, 'completed', staffActor);

    if (payment && appt.invoiceId) {
      const accountant = actorFor({ uid: 'seed-accountant', role: ROLES.ACCOUNTANT, clinicId, branchId });
      if (payment.insuranceRwf) {
        await invoicesService.recordInsurance(appt.invoiceId, { amountRwf: payment.insuranceRwf, scheme: payment.scheme || 'mutuelle' }, accountant);
      }
      if (payment.cashRwf) {
        await invoicesService.recordCashPayment(appt.invoiceId, payment.cashRwf, accountant);
      }
    }

    if (review) {
      const patientActor = actorFor({ uid: patientId, role: ROLES.PATIENT, clinicId, branchId });
      const created = await reviewsService.create({ appointmentId: appt.id, ...review }, patientActor);
      if (review.staffReplyText) {
        const branchAdmin = actorFor({ uid: 'seed-branch-admin', role: ROLES.BRANCH_ADMIN, clinicId, branchId });
        await reviewsService.reply(created.id, review.staffReplyText, branchAdmin);
      }
    }
  }
  return appt;
}

// ---------------------------------------------------------------------------
// Org A — single-branch: Kigali Family Clinic
// ---------------------------------------------------------------------------
async function seedSingleBranchOrg() {
  const org = await clinicsService.create({
    name: 'Kigali Family Clinic',
    subscriptionPlan: 'basic',
    ownerContactName: 'Jean-Paul Nshimiyimana',
    ownerContactPhone: '0788100001',
    billingCycle: 'monthly',
    subscriptionAmountRwf: 50000,
  });
  await clinicsService.setBillingStatus(org.id, 'paid', SEEDER.actorId);

  const adminUid = await createStaff({
    email: 'admin.kigalifamily@cliniqnovva.rw',
    name: 'Jean-Paul Nshimiyimana',
    role: ROLES.CLINIC_ADMIN,
    clinicId: org.id,
    branchId: null,
    phone: '0788100001',
  });

  const branch = await branchesService.create(
    {
      clinicId: org.id,
      name: 'Kigali Family Clinic — Nyamirambo',
      address: 'KN 5 Rd, Nyamirambo, Kigali',
      phone: '0788100002',
      workingHours: { start: '07:00', end: '19:00' },
    },
    { actorId: adminUid, actorRole: ROLES.CLINIC_ADMIN }
  );

  const deptGeneral = await departmentsService.create(
    { clinicId: org.id, branchId: branch.id, name: 'General Medicine' },
    actorFor({ uid: adminUid, role: ROLES.CLINIC_ADMIN, clinicId: org.id })
  );
  const deptPeds = await departmentsService.create(
    { clinicId: org.id, branchId: branch.id, name: 'Pediatrics' },
    actorFor({ uid: adminUid, role: ROLES.CLINIC_ADMIN, clinicId: org.id })
  );

  const svcConsult = await servicesService.create(
    { clinicId: org.id, branchId: branch.id, departmentId: deptGeneral.id, name: 'General Consultation', defaultDurationMins: 20, defaultPriceRwf: 5000 },
    actorFor({ uid: adminUid, role: ROLES.CLINIC_ADMIN, clinicId: org.id })
  );
  const svcChild = await servicesService.create(
    { clinicId: org.id, branchId: branch.id, departmentId: deptPeds.id, name: 'Child Wellness Check', defaultDurationMins: 20, defaultPriceRwf: 4000 },
    actorFor({ uid: adminUid, role: ROLES.CLINIC_ADMIN, clinicId: org.id })
  );

  await createStaff({ email: 'reception.kigalifamily@cliniqnovva.rw', name: 'Aline Mukamana', role: ROLES.RECEPTIONIST, clinicId: org.id, branchId: branch.id, phone: '0788100003' });
  await createStaff({ email: 'accountant.kigalifamily@cliniqnovva.rw', name: 'Eric Bizimana', role: ROLES.ACCOUNTANT, clinicId: org.id, branchId: branch.id, phone: '0788100004' });
  await createStaff({ email: 'nurse.kigalifamily@cliniqnovva.rw', name: 'Solange Ingabire', role: ROLES.NURSE, clinicId: org.id, branchId: branch.id, phone: '0788100005' });
  await createStaff({ email: 'pharmacist.kigalifamily@cliniqnovva.rw', name: 'Patrick Habimana', role: ROLES.PHARMACIST, clinicId: org.id, branchId: branch.id, phone: '0788100006' });

  const drUwase = await createDoctorWithSchedule({
    email: 'dr.uwase.kigalifamily@cliniqnovva.rw',
    name: 'Dr. Alice Uwase',
    clinicId: org.id,
    branchId: branch.id,
    phone: '0788100007',
    specialty: 'General Practice',
    departmentIds: [deptGeneral.id],
    schedule: WEEKDAY_SCHEDULE,
  });
  const drKarenzi = await createDoctorWithSchedule({
    email: 'dr.karenzi.kigalifamily@cliniqnovva.rw',
    name: 'Dr. Emmanuel Karenzi',
    clinicId: org.id,
    branchId: branch.id,
    phone: '0788100008',
    specialty: 'Pediatrics',
    departmentIds: [deptPeds.id],
    schedule: WEEKDAY_SCHEDULE,
  });

  const [p1, p2, p3, p4] = await seedPatients(org.id, branch.id, [
    { name: 'Claudine Uwimana', phone: '0722100001', dateOfBirth: '1990-03-14', gender: 'female', nationalId: '1199080012345671' },
    { name: 'Fabrice Niyonsenga', phone: '0722100002', dateOfBirth: '1985-07-22', gender: 'male', nationalId: '1198570012345672' },
    { name: 'Divine Iradukunda', phone: '0722100003', dateOfBirth: '2019-11-02', gender: 'female', nationalId: '1201990012345673' },
    { name: 'Olivier Mugisha', phone: '0722100004', dateOfBirth: '1978-01-30', gender: 'male', nationalId: '1197880012345674' },
  ]);

  await seedAppointment({
    clinicId: org.id, branchId: branch.id, patientId: p1, doctorId: drUwase, serviceId: svcConsult.id,
    date: isoDaysFromNow(-7), startTime: '09:00', endTime: '09:20', outcome: 'completed',
    payment: { cashRwf: 5000 },
    review: { branchRating: 5, branchComment: 'Very clean and fast service.', doctorRating: 5, doctorComment: 'Dr. Uwase was excellent.', staffReplyText: 'Thank you for the kind words, Claudine!' },
  });
  await seedAppointment({
    clinicId: org.id, branchId: branch.id, patientId: p2, doctorId: drUwase, serviceId: svcConsult.id,
    date: isoDaysFromNow(-3), startTime: '10:00', endTime: '10:20', outcome: 'completed',
    payment: { insuranceRwf: 3000, scheme: 'mutuelle', cashRwf: 2000 },
    review: { branchRating: 4, branchComment: 'Good, a bit of a wait.', doctorRating: 5, doctorComment: 'Very thorough.' },
  });
  await seedAppointment({
    clinicId: org.id, branchId: branch.id, patientId: p3, doctorId: drKarenzi, serviceId: svcChild.id,
    date: isoDaysFromNow(-1), startTime: '11:00', endTime: '11:20', outcome: 'completed',
    payment: { cashRwf: 4000 },
  });
  await seedAppointment({
    clinicId: org.id, branchId: branch.id, patientId: p4, doctorId: drUwase, serviceId: svcConsult.id,
    date: isoDaysFromNow(2), startTime: '09:00', endTime: '09:20', outcome: 'confirmed',
  });
  await seedAppointment({
    clinicId: org.id, branchId: branch.id, patientId: p1, doctorId: drKarenzi, serviceId: svcChild.id,
    date: isoDaysFromNow(4), startTime: '14:00', endTime: '14:20', outcome: 'upcoming',
  });
  await seedAppointment({
    clinicId: org.id, branchId: branch.id, patientId: p2, doctorId: drUwase, serviceId: svcConsult.id,
    date: isoDaysFromNow(1), startTime: '15:00', endTime: '15:20', outcome: 'cancelled',
  });

  console.log(`Seeded single-branch org: ${org.name} (${org.id})`);
}

// ---------------------------------------------------------------------------
// Org B — multi-branch: Rwanda Wellness Group (Kimihurura + Remera)
// ---------------------------------------------------------------------------
async function seedMultiBranchOrg() {
  const org = await clinicsService.create({
    name: 'Rwanda Wellness Group',
    subscriptionPlan: 'pro',
    ownerContactName: 'Grace Mutesi',
    ownerContactPhone: '0788200001',
    billingCycle: 'quarterly',
    subscriptionAmountRwf: 180000,
  });
  await clinicsService.setBillingStatus(org.id, 'paid', SEEDER.actorId);

  const orgAdminUid = await createStaff({
    email: 'admin.rwandawellness@cliniqnovva.rw',
    name: 'Grace Mutesi',
    role: ROLES.CLINIC_ADMIN,
    clinicId: org.id,
    branchId: null,
    phone: '0788200001',
  });

  const branchDefs = [
    { key: 'kimihurura', name: 'Rwanda Wellness — Kimihurura', address: 'KG 7 Ave, Kimihurura, Kigali', phone: '0788200010' },
    { key: 'remera', name: 'Rwanda Wellness — Remera', address: 'KG 11 Ave, Remera, Kigali', phone: '0788200020' },
  ];

  for (const [i, def] of branchDefs.entries()) {
    const branch = await branchesService.create(
      { clinicId: org.id, name: def.name, address: def.address, phone: def.phone, workingHours: { start: '07:30', end: '18:30' } },
      { actorId: orgAdminUid, actorRole: ROLES.CLINIC_ADMIN }
    );

    const branchAdminUid = await createStaff({
      email: `admin.${def.key}@cliniqnovva.rw`,
      name: i === 0 ? 'Vincent Rugamba' : 'Josiane Umutoni',
      role: ROLES.BRANCH_ADMIN,
      clinicId: org.id,
      branchId: branch.id,
      phone: `07882000${i + 2}1`,
    });

    const dept = await departmentsService.create(
      { clinicId: org.id, branchId: branch.id, name: 'General Medicine' },
      actorFor({ uid: branchAdminUid, role: ROLES.BRANCH_ADMIN, clinicId: org.id, branchId: branch.id })
    );
    const deptDental = await departmentsService.create(
      { clinicId: org.id, branchId: branch.id, name: 'Dental' },
      actorFor({ uid: branchAdminUid, role: ROLES.BRANCH_ADMIN, clinicId: org.id, branchId: branch.id })
    );

    const svcConsult = await servicesService.create(
      { clinicId: org.id, branchId: branch.id, departmentId: dept.id, name: 'General Consultation', defaultDurationMins: 20, defaultPriceRwf: 6000 },
      actorFor({ uid: branchAdminUid, role: ROLES.BRANCH_ADMIN, clinicId: org.id, branchId: branch.id })
    );
    const svcDental = await servicesService.create(
      { clinicId: org.id, branchId: branch.id, departmentId: deptDental.id, name: 'Dental Cleaning', defaultDurationMins: 30, defaultPriceRwf: 10000 },
      actorFor({ uid: branchAdminUid, role: ROLES.BRANCH_ADMIN, clinicId: org.id, branchId: branch.id })
    );

    await createStaff({ email: `reception.${def.key}@cliniqnovva.rw`, name: i === 0 ? 'Diane Ishimwe' : 'Yves Ndayisenga', role: ROLES.RECEPTIONIST, clinicId: org.id, branchId: branch.id, phone: `07882000${i + 3}2` });
    await createStaff({ email: `nurse.${def.key}@cliniqnovva.rw`, name: i === 0 ? 'Beata Nyirahabimana' : 'Christian Mugabo', role: ROLES.NURSE, clinicId: org.id, branchId: branch.id, phone: `07882000${i + 3}3` });

    const doctorA = await createDoctorWithSchedule({
      email: `dr.a.${def.key}@cliniqnovva.rw`,
      name: i === 0 ? 'Dr. Immaculee Uwera' : 'Dr. Theogene Habyarimana',
      clinicId: org.id,
      branchId: branch.id,
      phone: `07882000${i + 4}4`,
      specialty: 'General Practice',
      departmentIds: [dept.id],
      schedule: WEEKDAY_SCHEDULE,
    });
    const doctorB = await createDoctorWithSchedule({
      email: `dr.b.${def.key}@cliniqnovva.rw`,
      name: i === 0 ? 'Dr. Samuel Byiringiro' : 'Dr. Vestine Mukashyaka',
      clinicId: org.id,
      branchId: branch.id,
      phone: `07882000${i + 5}5`,
      specialty: 'Dentistry',
      departmentIds: [deptDental.id],
      schedule: WEEKDAY_SCHEDULE,
    });

    const [q1, q2, q3] = await seedPatients(org.id, branch.id, [
      { name: `${i === 0 ? 'Chantal Mukandayisenga' : 'Innocent Habumuremyi'}`, phone: `07331000${i}1`, dateOfBirth: '1992-05-18', gender: i === 0 ? 'female' : 'male', nationalId: `119920001234567${i}` },
      { name: `${i === 0 ? 'Damien Twagirayezu' : 'Sandrine Uwizeye'}`, phone: `07331000${i}2`, dateOfBirth: '1988-09-09', gender: i === 0 ? 'male' : 'female', nationalId: `119880001234568${i}` },
      { name: `${i === 0 ? 'Aimee Uwamahoro' : 'Placide Nsengiyumva'}`, phone: `07331000${i}3`, dateOfBirth: '2001-12-25', gender: i === 0 ? 'female' : 'male', nationalId: `120010001234569${i}` },
    ]);

    await seedAppointment({
      clinicId: org.id, branchId: branch.id, patientId: q1, doctorId: doctorA, serviceId: svcConsult.id,
      date: isoDaysFromNow(-5), startTime: '09:00', endTime: '09:20', outcome: 'completed',
      payment: { cashRwf: 6000 },
      review: { branchRating: 5, branchComment: `Great branch, ${def.name.split('—')[1].trim()} is convenient.`, doctorRating: 4, doctorComment: 'Good, would return.' },
    });
    await seedAppointment({
      clinicId: org.id, branchId: branch.id, patientId: q2, doctorId: doctorB, serviceId: svcDental.id,
      date: isoDaysFromNow(-2), startTime: '10:00', endTime: '10:30', outcome: 'completed',
      payment: { insuranceRwf: 10000, scheme: 'rssb' },
      review: { branchRating: 5, branchComment: 'Painless cleaning!', doctorRating: 5, doctorComment: 'Very gentle.', staffReplyText: 'So glad to hear it — see you at your next check-up!' },
    });
    await seedAppointment({
      clinicId: org.id, branchId: branch.id, patientId: q3, doctorId: doctorA, serviceId: svcConsult.id,
      date: isoDaysFromNow(3), startTime: '11:00', endTime: '11:20', outcome: 'confirmed',
    });
    await seedAppointment({
      clinicId: org.id, branchId: branch.id, patientId: q1, doctorId: doctorB, serviceId: svcDental.id,
      date: isoDaysFromNow(5), startTime: '13:00', endTime: '13:30', outcome: 'upcoming',
    });
  }

  console.log(`Seeded multi-branch org: ${org.name} (${org.id})`);
}

async function seedSuperAdmin() {
  await createStaff({ email: 'superadmin@cliniqnovva.rw', name: 'Cliniqnovva Platform Admin', role: ROLES.SUPER_ADMIN, clinicId: null, branchId: null, phone: '0788000000' });
}

function printAccountsTable() {
  console.log('\n=== Demo accounts created (all use the same password) ===');
  console.log(`Password for every account: ${DEMO_PASSWORD}\n`);
  const width = Math.max(...createdAccounts.map((a) => a.email.length)) + 2;
  for (const a of createdAccounts) {
    console.log(`${a.email.padEnd(width)} ${a.role.padEnd(20)} org=${a.org || '—'}`);
  }
}

async function main() {
  console.log(`Seeding demo data into Firebase project: ${process.env.FIREBASE_PROJECT_ID || '(from service account file)'} (NODE_ENV=${process.env.NODE_ENV || 'development'})`);
  await seedSuperAdmin();
  await seedSingleBranchOrg();
  await seedMultiBranchOrg();
  printAccountsTable();
  console.log('\nDone. See docs/demo-accounts.md for the same table plus login instructions.');
}

main().catch((err) => {
  console.error('Seed script failed:', err);
  process.exitCode = 1;
});
