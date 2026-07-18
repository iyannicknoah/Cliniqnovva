// Controller for /api/v1/doctors — spec section 6.5 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching doctors.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list doctors' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get doctors by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create doctors' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update doctors' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove doctors' });
}

module.exports = { list, getById, create, update, remove };
