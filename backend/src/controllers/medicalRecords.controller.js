// Controller for /api/v1/medicalRecords — spec section 6.6 / 9
// Project-setup phase: handlers are stubs (501). Business logic — validation,
// Firestore transactions, branch/org scoping via req.scope — is implemented in
// Phase 1, not now. Keep controllers thin: parse/validate req, call the
// matching medicalRecords.service.js function, shape the response.

async function list(req, res) {
  res.status(501).json({ error: 'Not implemented yet: list medicalRecords' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Not implemented yet: get medicalRecords by id' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create medicalRecords' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update medicalRecords' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove medicalRecords' });
}

module.exports = { list, getById, create, update, remove };
