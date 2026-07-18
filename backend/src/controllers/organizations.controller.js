// Controller for /api/v1/organizations — spec section 4 / 6.2 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching organizations.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list organizations' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get organizations by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create organizations' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update organizations' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove organizations' });
}

module.exports = { list, getById, create, update, remove };
