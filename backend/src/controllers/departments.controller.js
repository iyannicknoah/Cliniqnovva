// Controller for /api/v1/departments — spec section 6.4 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching departments.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list departments' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get departments by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create departments' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update departments' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove departments' });
}

module.exports = { list, getById, create, update, remove };
