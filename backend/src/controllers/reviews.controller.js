// Controller for /api/v1/reviews — spec section 6.13(sibling) / 7 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching reviews.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list reviews' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get reviews by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create reviews' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update reviews' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove reviews' });
}

module.exports = { list, getById, create, update, remove };
