// Controller for /api/v1/patients — spec section 6.5A / 6.6 / 6.6A / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching patients.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list patients' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get patients by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create patients' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update patients' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove patients' });
}

module.exports = { list, getById, create, update, remove };
