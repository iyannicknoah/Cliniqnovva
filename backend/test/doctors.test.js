const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { db, reset } = require('./support/setup');
const doctorsService = require('../src/services/doctors.service');

beforeEach(() => reset());

function seedDoctor(id, { branchId = 'branch1', isActive = true, specialty = 'Dentist' } = {}) {
  db.seed(`users/${id}`, {
    role: 'doctor',
    name: 'Dr. Alice Uwase',
    email: 'alice@clinic.rw',
    phone: '0788111222',
    clinicId: 'org1',
    branchId,
    isActive,
  });
  db.seed(`doctors/${id}`, {
    specialty,
    bio: 'Ten years of practice.',
    departmentIds: ['dept1'],
    schedule: [{ day: 'monday', startTime: '08:00', endTime: '12:00', slotDurationMins: 30 }],
    breakMinutes: 15,
    blockedSlots: [{ date: '2026-01-01', startTime: '00:00', endTime: '23:59', reason: 'Public holiday' }],
    averageRating: 4.5,
    reviewCount: 3,
  });
}

test('doctors: list() never exposes email, phone, blockedSlots, or breakMinutes', async () => {
  seedDoctor('doc1');
  const [doctor] = await doctorsService.list({ branchId: 'branch1' });

  assert.equal(doctor.name, 'Dr. Alice Uwase');
  assert.equal(doctor.specialty, 'Dentist');
  assert.deepEqual(doctor.schedule, [{ day: 'monday', startTime: '08:00', endTime: '12:00', slotDurationMins: 30 }]);
  for (const leaked of ['email', 'phone', 'blockedSlots', 'breakMinutes']) {
    assert.ok(!(leaked in doctor), `doctor response must never include "${leaked}"`);
  }
});

test('doctors: list() excludes deactivated doctors and doctors from other branches', async () => {
  seedDoctor('doc1', { branchId: 'branch1' });
  seedDoctor('doc2', { branchId: 'branch1', isActive: false });
  seedDoctor('doc3', { branchId: 'branch2' });

  const doctors = await doctorsService.list({ branchId: 'branch1' });
  assert.equal(doctors.length, 1);
  assert.equal(doctors[0].id, 'doc1');
});

test('doctors: list() requires a branchId', async () => {
  await assert.rejects(() => doctorsService.list({}), (err) => {
    assert.equal(err.status, 400);
    return true;
  });
});

test('doctors: getById() returns null for a non-doctor or deactivated doctor', async () => {
  seedDoctor('doc1', { isActive: false });
  db.seed('users/nurse1', { role: 'nurse', name: 'Nurse Bob', clinicId: 'org1', branchId: 'branch1', isActive: true });

  assert.equal(await doctorsService.getById('doc1'), null);
  assert.equal(await doctorsService.getById('nurse1'), null);
  assert.equal(await doctorsService.getById('missing'), null);
});

test('doctors: searchBranchIdsByNameOrSpecialty() matches on name or specialty, case-insensitively', async () => {
  seedDoctor('doc1', { branchId: 'branch1', specialty: 'Cardiologist' });
  seedDoctor('doc2', { branchId: 'branch2', specialty: 'Dermatologist' });

  const bySpecialty = await doctorsService.searchBranchIdsByNameOrSpecialty('cardio');
  assert.deepEqual([...bySpecialty], ['branch1']);

  const byName = await doctorsService.searchBranchIdsByNameOrSpecialty('alice');
  assert.deepEqual([...byName].sort(), ['branch1', 'branch2']);

  const noMatch = await doctorsService.searchBranchIdsByNameOrSpecialty('orthopedic');
  assert.equal(noMatch.size, 0);
});
