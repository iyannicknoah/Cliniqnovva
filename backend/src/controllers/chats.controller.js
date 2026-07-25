// Controller for /api/v1/chats — INTENTIONALLY EMPTY, permanently (spec
// section 6.13, Part 15). See chats.service.js's docstring: chat reads/
// writes go directly from the Flutter client to Firestore (real-time
// listeners + firebase/firestore.rules), not through this Express layer.
// These handlers stay 501 on purpose — nothing in the client ever calls
// them — kept only so this collection has a route file for consistency
// with routes/index.js's one-file-per-collection convention.

async function list(req, res) {
  res.status(501).json({ error: 'Chats are read directly from Firestore by the client — see firebase/firestore.rules' });
}

async function getById(req, res) {
  res.status(501).json({ error: 'Chats are read directly from Firestore by the client — see firebase/firestore.rules' });
}

async function create(req, res) {
  res.status(501).json({ error: 'Chats are created directly in Firestore by the client — see firebase/firestore.rules' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Chats are updated directly in Firestore by the client — see firebase/firestore.rules' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented: chats are never deleted, only soft-deleted at the message level' });
}

module.exports = { list, getById, create, update, remove };
