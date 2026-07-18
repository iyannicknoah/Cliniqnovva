// Controller for /api/v1/branches — spec section 4 / 6.2 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching branches.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list branches' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get branches by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create branches' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update branches' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove branches' });
}

module.exports = { list, getById, create, update, remove };
