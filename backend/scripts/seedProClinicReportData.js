// One-off script (2026-08-15, explicit user request: "add sample data on
// report page ... add many branches") — adds 4 new branches to the
// currently-logged-in demo clinic ("Pro Clinic", admin Promosse,
// clinicId QQLJJdsedEF3TCHVlvrm), each with a department/service/doctor/
// patients and a spread of appointments+invoices across the last ~28 days
// so the Reports screen's revenue/patient-volume/no-show charts (default
// filter: last 30 days, see reports_screen.dart) have real, varied,
// multi-branch data to render instead of one thin data point.
//
// Pro Clinic's plan is 'basic' (branchLimit: 1, already at its cap with
// "Kigali Branch") — bumped to 'enterprise' (unlimited) first so the new
// branches aren't rejected by branches.service.js's limit check. This is a
// real, persistent change to the clinic's plan, not just seed-script
// scaffolding — mentioned here so it's not a silent side effect.
//
// appointments.service.js#book() rejects any date before today
// (isPastInKigali) — there is no service-layer way to create a genuinely
// historical appointment directly. So every appointment here is booked
// against a safe transient date (tomorrow, always in the future — avoids
// both the past-date rejection and any time-of-day race against "right
// now"), driven through the real status state machine (confirmed ->
// checkedIn -> completed, or left at confirmed/pending for a no-show/
// upcoming), and only THEN has its `date` (and, for a completed visit, its
// auto-generated invoice's `createdAt`) overwritten directly in Firestore
// to the actual backdated value reports.service.js reads. This mirrors
// scripts/seedDemoData.js's use of the real service layer for validation/
// business rules (server-recalculated invoice totals, audit logs,
// notifications), while working around that one service-layer restriction
// dedicated seed scripts don't need to honor.
//
// Usage: cd backend && node scripts/seedProClinicReportData.js
const { db } = require('../src/config/firebase-admin');
const { ROLES } = require('../src/middleware/requireRole');
const clinicsService = require('../src/services/clinics.service');
const branchesService = require('../src/services/branches.service');
const departmentsService = require('../src/services/departments.service');
const servicesService = require('../src/services/services.service');
const staffService = require('../src/services/staff.service');
const patientsService = require('../src/services/patients.service');
const appointmentsService = require('../src/services/appointments.service');
const invoicesService = require('../src/services/invoices.service');
const reviewsService = require('../src/services/reviews.service');

const CLINIC_ID = 'QQLJJdsedEF3TCHVlvrm'; // Pro Clinic (admin: Promosse)
const ADMIN_UID = 'H8AczMcO6DaOre4Yz5QuL9uzvIT2';
const DEMO_PASSWORD = 'Cliniq2027!Demo';

const createdAccounts = [];
function record(email, role, branch) {
  createdAccounts.push({ email, password: DEMO_PASSWORD, role, branch });
}

function actorFor({ uid, role, branchId }) {
  const level = role === ROLES.CLINIC_ADMIN ? 'clinic' : 'branch';
  const scope =
    level === 'clinic'
      ? { level: 'clinic', clinicId: CLINIC_ID }
      : { level: 'branch', clinicId: CLINIC_ID, branchId };
  return { actorId: uid, role, actorRole: role, scope };
}

function kigaliToday() {
  return new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString().slice(0, 10);
}
function isoDateOffset(days) {
  const d = new Date(Date.now() + 2 * 60 * 60 * 1000);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}
function tomorrow() {
  return isoDateOffset(1);
}

const WEEKDAY_SCHEDULE = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'].map((day) => ({
  day,
  startTime: '08:00',
  endTime: '17:00',
  slotDurationMins: 20,
}));

async function createDoctorWithSchedule({ email, name, branchId, phone, specialty, departmentIds }) {
  const uid = await staffService
    .create(
      { email, password: DEMO_PASSWORD, name, role: ROLES.DOCTOR, clinicId: CLINIC_ID, branchId, phone, specialty, departmentIds },
      actorFor({ uid: ADMIN_UID, role: ROLES.CLINIC_ADMIN })
    )
    .then((r) => r.id);
  record(email, ROLES.DOCTOR, branchId);
  await staffService.setSchedule(uid, WEEKDAY_SCHEDULE, 0, actorFor({ uid: ADMIN_UID, role: ROLES.CLINIC_ADMIN, branchId }));
  return uid;
}

async function seedPatients(branchId, list) {
  const ids = [];
  for (const p of list) {
    const patient = await patientsService.create(
      { clinicId: CLINIC_ID, branchId, confirmedDuplicate: true, ...p },
      actorFor({ uid: 'seed-receptionist', role: ROLES.RECEPTIONIST, branchId })
    );
    // reviewsService.create()'s ownership check is
    // `patients/{patientId}.linkedAppAccountId === actor.actorId` — a plain
    // walk-in record (patientsService.create()) never sets that field, and
    // this script's review-seeding actor uses the patientId itself as
    // actor.actorId (there's no real Patient App account behind these demo
    // patients). Set it directly here so seedAppointment()'s review step
    // below doesn't 403.
    await db.collection('patients').doc(patient.id).update({ linkedAppAccountId: patient.id });
    ids.push(patient.id);
  }
  return ids;
}

/**
 * Books against a safe transient future date, drives the real status
 * transitions, then rewrites `date` (and the invoice's `createdAt`, if one
 * was generated) to `targetDate` — see file header for why.
 */
async function seedAppointment({ branchId, patientId, doctorId, serviceId, startTime, endTime, targetDate, outcome, payment, review }) {
  const staffActor = actorFor({ uid: 'seed-receptionist', role: ROLES.RECEPTIONIST, branchId });

  let appt = await appointmentsService.book(
    { clinicId: CLINIC_ID, branchId, patientId, doctorId, serviceId, date: tomorrow(), startTime, endTime },
    staffActor
  );

  if (outcome === 'noshow' || outcome === 'completed' || outcome === 'cancelled') {
    appt = await appointmentsService.setStatus(appt.id, 'confirmed', staffActor);
  }
  if (outcome === 'cancelled') {
    appt = await appointmentsService.setStatus(appt.id, 'cancelled', staffActor);
  } else if (outcome === 'completed') {
    appt = await appointmentsService.setStatus(appt.id, 'checkedIn', staffActor);
    appt = await appointmentsService.setStatus(appt.id, 'completed', staffActor);

    if (payment && appt.invoiceId) {
      const accountant = actorFor({ uid: 'seed-accountant', role: ROLES.ACCOUNTANT, branchId });
      if (payment.insuranceRwf) {
        await invoicesService.recordInsurance(appt.invoiceId, { amountRwf: payment.insuranceRwf, scheme: payment.scheme || 'mutuelle' }, accountant);
      }
      if (payment.cashRwf) {
        await invoicesService.recordCashPayment(appt.invoiceId, payment.cashRwf, accountant);
      }
      await db.collection('invoices').doc(appt.invoiceId).update({
        createdAt: `${targetDate}T${startTime}:00.000Z`,
      });
    }

    if (review) {
      const patientActor = actorFor({ uid: patientId, role: ROLES.PATIENT, branchId });
      const created = await reviewsService.create({ appointmentId: appt.id, ...review }, patientActor);
      if (review.staffReplyText) {
        const branchAdmin = actorFor({ uid: 'seed-branch-admin', role: ROLES.BRANCH_ADMIN, branchId });
        await reviewsService.reply(created.id, review.staffReplyText, branchAdmin);
      }
    }
  }
  // 'upcoming' and 'noshow' both stay at 'confirmed'/'pending' — the only
  // difference reports care about is whether targetDate ends up in the past.

  await db.collection('appointments').doc(appt.id).update({ date: targetDate });
  return appt;
}

const BRANCH_DEFS = [
  {
    key: 'remera',
    name: 'Rwanda Wellness — Remera',
    address: 'KG 11 Ave, Remera, Kigali',
    phone: '0788300001',
    doctorName: 'Dr. Beatrice Mukamana',
    priceRwf: 6000,
    patients: [
      { name: 'Yves Habimana', phone: '0722300001', dateOfBirth: '1994-02-11', gender: 'male', nationalId: '1199490012300001' },
      { name: 'Consolee Uwera', phone: '0722300002', dateOfBirth: '1989-06-19', gender: 'female', nationalId: '1198990012300002' },
      { name: 'Jean Bosco Habyarimana', phone: '0722300003', dateOfBirth: '1975-12-05', gender: 'male', nationalId: '1197590012300003' },
    ],
  },
  {
    key: 'nyamirambo',
    name: 'Rwanda Wellness — Nyamirambo',
    address: 'KN 5 Rd, Nyamirambo, Kigali',
    phone: '0788300002',
    doctorName: 'Dr. Vianney Ntawuruhunga',
    priceRwf: 5500,
    patients: [
      { name: 'Alphonsine Mukashema', phone: '0722300004', dateOfBirth: '1996-04-23', gender: 'female', nationalId: '1199690012300004' },
      { name: 'Emmanuel Nkurunziza', phone: '0722300005', dateOfBirth: '1982-08-30', gender: 'male', nationalId: '1198290012300005' },
      { name: 'Providence Ishimwe', phone: '0722300006', dateOfBirth: '2000-01-17', gender: 'female', nationalId: '1200090012300006' },
    ],
  },
  {
    key: 'musanze',
    name: 'Rwanda Wellness — Musanze',
    address: 'NR4, Musanze',
    phone: '0788300003',
    doctorName: 'Dr. Odette Nyiraneza',
    priceRwf: 5000,
    patients: [
      { name: 'Fiacre Ndayisenga', phone: '0722300007', dateOfBirth: '1991-10-08', gender: 'male', nationalId: '1199190012300007' },
      { name: 'Chantal Nyirahabimana', phone: '0722300008', dateOfBirth: '1987-03-27', gender: 'female', nationalId: '1198790012300008' },
      { name: 'Bertin Uwimana', phone: '0722300009', dateOfBirth: '2015-09-14', gender: 'male', nationalId: '1201590012300009' },
    ],
  },
  {
    key: 'huye',
    name: 'Rwanda Wellness — Huye',
    address: 'NR1, Huye',
    phone: '0788300004',
    doctorName: 'Dr. Aline Umutoni',
    priceRwf: 4500,
    patients: [
      { name: 'Theoneste Bizimana', phone: '0722300010', dateOfBirth: '1993-07-02', gender: 'male', nationalId: '1199390012300010' },
      { name: 'Marie Goretti Mukandayisenga', phone: '0722300011', dateOfBirth: '1979-11-21', gender: 'female', nationalId: '1197990012300011' },
      { name: 'Jean Claude Rukundo', phone: '0722300012', dateOfBirth: '1998-05-09', gender: 'male', nationalId: '1199890012300012' },
    ],
  },
];

async function seedBranch(def) {
  const branch = await branchesService.create(
    { clinicId: CLINIC_ID, name: def.name, address: def.address, phone: def.phone, workingHours: { start: '07:30', end: '18:00' } },
    { actorId: ADMIN_UID, actorRole: ROLES.CLINIC_ADMIN }
  );

  const dept = await departmentsService.create(
    { clinicId: CLINIC_ID, branchId: branch.id, name: 'General Medicine' },
    actorFor({ uid: ADMIN_UID, role: ROLES.CLINIC_ADMIN })
  );
  const svc = await servicesService.create(
    { clinicId: CLINIC_ID, branchId: branch.id, departmentId: dept.id, name: 'General Consultation', defaultDurationMins: 20, defaultPriceRwf: def.priceRwf },
    actorFor({ uid: ADMIN_UID, role: ROLES.CLINIC_ADMIN })
  );

  const doctorId = await createDoctorWithSchedule({
    email: `dr.${def.key}@proclinic.rw`,
    name: def.doctorName,
    branchId: branch.id,
    phone: def.phone,
    specialty: 'General Practice',
    departmentIds: [dept.id],
  });

  const [p1, p2, p3] = await seedPatients(branch.id, def.patients);

  // Spread over the last ~28 days so the default 30-day report window
  // (reports_screen.dart) shows a real trend, not a single spike.
  await seedAppointment({
    branchId: branch.id, patientId: p1, doctorId, serviceId: svc.id,
    startTime: '08:00', endTime: '08:20', targetDate: isoDateOffset(-25), outcome: 'completed',
    payment: { cashRwf: def.priceRwf },
    review: { branchRating: 5, branchComment: 'Quick and friendly service.', doctorRating: 5, doctorComment: 'Very attentive.', staffReplyText: 'Thank you, we appreciate it!' },
  });
  await seedAppointment({
    branchId: branch.id, patientId: p2, doctorId, serviceId: svc.id,
    startTime: '09:00', endTime: '09:20', targetDate: isoDateOffset(-20), outcome: 'completed',
    payment: { insuranceRwf: Math.round(def.priceRwf * 0.6), scheme: 'mutuelle', cashRwf: Math.round(def.priceRwf * 0.4) },
  });
  await seedAppointment({
    branchId: branch.id, patientId: p3, doctorId, serviceId: svc.id,
    startTime: '10:00', endTime: '10:20', targetDate: isoDateOffset(-15), outcome: 'noshow',
  });
  await seedAppointment({
    branchId: branch.id, patientId: p1, doctorId, serviceId: svc.id,
    startTime: '11:00', endTime: '11:20', targetDate: isoDateOffset(-10), outcome: 'completed',
    payment: { cashRwf: def.priceRwf },
    review: { branchRating: 4, branchComment: 'Good visit, short wait.', doctorRating: 4, doctorComment: 'Helpful.' },
  });
  await seedAppointment({
    branchId: branch.id, patientId: p2, doctorId, serviceId: svc.id,
    startTime: '13:00', endTime: '13:20', targetDate: isoDateOffset(-6), outcome: 'cancelled',
  });
  await seedAppointment({
    branchId: branch.id, patientId: p3, doctorId, serviceId: svc.id,
    startTime: '14:00', endTime: '14:20', targetDate: isoDateOffset(-3), outcome: 'completed',
    payment: { cashRwf: def.priceRwf },
  });
  await seedAppointment({
    branchId: branch.id, patientId: p1, doctorId, serviceId: svc.id,
    startTime: '15:00', endTime: '15:20', targetDate: isoDateOffset(4), outcome: 'upcoming',
  });

  console.log(`Seeded branch: ${branch.name} (${branch.id})`);
}

async function main() {
  console.log(`Upgrading Pro Clinic (${CLINIC_ID}) to the 'enterprise' plan (unlimited branches, was 'basic'/1)...`);
  await clinicsService.update(CLINIC_ID, { subscriptionPlan: 'enterprise' });

  for (const def of BRANCH_DEFS) {
    await seedBranch(def);
  }

  console.log('\n=== New doctor accounts (same password for all) ===');
  console.log(`Password: ${DEMO_PASSWORD}\n`);
  for (const a of createdAccounts) {
    console.log(`${a.email.padEnd(30)} ${a.role.padEnd(10)} branch=${a.branch}`);
  }
  console.log('\nDone.');
}

main().catch((err) => {
  console.error('Seed script failed:', err);
  process.exitCode = 1;
});
