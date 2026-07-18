// Controller for /api/v1/services — spec section 6.4 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching services.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list services' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get services by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create services' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update services' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove services' });
}

module.exports = { list, getById, create, update, remove };
