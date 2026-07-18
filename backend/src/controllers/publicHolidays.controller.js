// Controller for /api/v1/publicHolidays — spec section 1 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching publicHolidays.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list publicHolidays' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get publicHolidays by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create publicHolidays' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update publicHolidays' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove publicHolidays' });
}

module.exports = { list, getById, create, update, remove };
