// Controller for /api/v1/appointments — spec section 6.7 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching appointments.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list appointments' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get appointments by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create appointments' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update appointments' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove appointments' });
}

module.exports = { list, getById, create, update, remove };
