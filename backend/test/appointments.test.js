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

test('appointments: breakMinutes pushes the next available slot back by the buffer (2026-07-26)', async () => {
  seedBaseline();
  // Override doc1 with a break: 60-min appointments, 10-min recovery buffer.
  // slotDurationMins: 10 so candidate slot starts land exactly on the
  // buffer's boundary, matching the request's own example precisely.
  db.seed('doctors/doc1', {
    schedule: [{ day: 'monday', startTime: '08:00', endTime: '12:00', slotDurationMins: 10 }],
    blockedSlots: [],
    breakMinutes: 10,
  });
  db.seed('services/svcLong', { defaultDurationMins: 60, defaultPriceRwf: 10000, name: 'Long consult' });
  const staff = actor({ role: 'receptionist', clinicId: 'org1', branchId: 'branch1' });

  // An 8:00-9:00 appointment ends at 9:00 — with a 10-min buffer, 9:00 must
  // be unavailable and 9:10 must be the first slot offered again (the
  // request's own example: 2:00 + 60min + 10min break -> 3:10).
  await appointmentsService.book(
    { clinicId: 'org1', branchId: 'branch1', patientId: 'patientA', doctorId: 'doc1', serviceId: 'svcLong', date: '2027-01-04', startTime: '08:00', endTime: '09:00' },
    staff
  );

  const slots = await appointmentsService.getAvailableSlots({
    doctorId: 'doc1',
    branchId: 'branch1',
    serviceId: 'svcLong',
    date: '2027-01-04',
  });

  assert.ok(!slots.some((s) => s.startTime === '09:00'), '09:00 should be blocked by the break buffer');
  assert.ok(slots.some((s) => s.startTime === '09:10'), '09:10 should be the first slot offered again');

  // Booking directly at 09:00 (bypassing the slot list) must also be
  // rejected — book() re-applies the same buffer, not just getAvailableSlots.
  await assert.rejects(
    () =>
      appointmentsService.book(
        { clinicId: 'org1', branchId: 'branch1', patientId: 'patientB', doctorId: 'doc1', serviceId: 'svcLong', date: '2027-01-04', startTime: '09:00', endTime: '10:00' },
        staff
      ),
    (err) => {
      assert.equal(err.status, 409);
      return true;
    }
  );
});

test('appointments: breakMinutes also applies around a manually blocked slot', async () => {
  seedBaseline();
  db.seed('doctors/doc1', {
    schedule: [{ day: 'monday', startTime: '08:00', endTime: '12:00', slotDurationMins: 10 }],
    blockedSlots: [{ date: '2027-01-04', startTime: '10:00', endTime: '10:30', reason: 'Leave' }],
    breakMinutes: 10,
  });

  const slots = await appointmentsService.getAvailableSlots({
    doctorId: 'doc1',
    branchId: 'branch1',
    serviceId: 'svc1', // 15-min service, from seedBaseline
    date: '2027-01-04',
  });

  assert.ok(!slots.some((s) => s.startTime === '10:30'), '10:30 should still be inside the buffer after the blocked slot');
  assert.ok(slots.some((s) => s.startTime === '10:40'), '10:40 should be available again');
});
