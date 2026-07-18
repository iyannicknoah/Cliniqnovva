// Controller for /api/v1/notifications — spec section 6.11 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching notifications.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list notifications' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get notifications by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create notifications' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update notifications' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove notifications' });
}

module.exports = { list, getById, create, update, remove };
