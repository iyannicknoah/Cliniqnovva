// Controller for /api/v1/invoices — spec section 6.8 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching invoices.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list invoices' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get invoices by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create invoices' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update invoices' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove invoices' });
}

module.exports = { list, getById, create, update, remove };
