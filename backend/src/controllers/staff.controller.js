// Controller for /api/v1/staff — spec section 6.3 / 5
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching staff.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list staff' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get staff by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create staff' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update staff' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove staff' });
}

module.exports = { list, getById, create, update, remove };
