const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, reset, actor } = require('./support/setup');
const appointmentsService = require('../src/services/appointments.service');

beforeEach(() => reset());

function seedBaseline() {
  db.seed('doctors/doc1', {
    schedule: [{ day: 'monday', startTime: '08:00', endTime: '12:00', slotDurationMins: 15 }],
    blockedSlots: [],
  });
  db.seed('branches/branch1', { clinicId: 'org1', umugandaSaturdayHours: null, holidayOverrides: [] });
  db.seed('services/svc1', { defaultDurationMins: 15, defaultPriceRwf: 5000, name: 'Consultation' });
}

test('appointments: booking the same slot twice rejects the second with a 409 (double-booking prevention)', async () => {
  seedBaseline();
  const staff = actor({ role: 'receptionist', clinicId: 'org1', branchId: 'branch1' });
  const bookingArgs = {
    clinicId: 'org1',
    branchId: 'branch1',
    patientId: 'patientA',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date: '2027-01-04', // a Monday
    startTime: '09:00',
    endTime: '09:15',
  };

  const first = await appointmentsService.book(bookingArgs, staff);
  assert.equal(first.status, 'pending');

  await assert.rejects(
    () => appointmentsService.book({ ...bookingArgs, patientId: 'patientB' }, staff),
    (err) => {
      assert.equal(err.status, 409);
      return true;
    }
  );

  const stillOnlyOne = (await db.collection('appointments').where('doctorId', '==', 'doc1').where('date', '==', bookingArgs.date).get()).size;
  assert.equal(stillOnlyOne, 1);
});

test('appointments: a non-overlapping slot for the same doctor/date books fine', async () => {
  seedBaseline();
  const staff = actor({ role: 'receptionist', clinicId: 'org1', branchId: 'branch1' });
  const base = {
    clinicId: 'org1',
    branchId: 'branch1',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date: '2027-01-04',
  };

  await appointmentsService.book({ ...base, patientId: 'patientA', startTime: '09:00', endTime: '09:15' }, staff);
  const second = await appointmentsService.book({ ...base, patientId: 'patientB', startTime: '09:15', endTime: '09:30' }, staff);
  assert.equal(second.status, 'pending');
});

test('appointments: a cancelled appointment frees its slot for rebooking', async () => {
  seedBaseline();
  const staff = actor({ role: 'receptionist', clinicId: 'org1', branchId: 'branch1' });
  const base = {
    clinicId: 'org1',
    branchId: 'branch1',
    doctorId: 'doc1',
    serviceId: 'svc1',
    date: '2027-01-04',
    startTime: '09:00',
    endTime: '09:15',
  };

  const first = await appointmentsService.book({ ...base, patientId: 'patientA' }, staff);
  await appointmentsService.setStatus(first.id, 'cancelled', staff);

  const second = await appointmentsService.book({ ...base, patientId: 'patientB' }, staff);
  assert.equal(second.status, 'pending');
});
