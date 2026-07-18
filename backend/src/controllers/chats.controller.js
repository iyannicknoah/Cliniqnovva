// Controller for /api/v1/chats — spec section 6.13 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching chats.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list chats' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get chats by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create chats' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update chats' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove chats' });
}

module.exports = { list, getById, create, update, remove };
