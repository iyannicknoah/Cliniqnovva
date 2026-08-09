// Controller for /api/v1/chats. See chats.service.js's docstring: chat
// reads/writes go directly from the Flutter client to Firestore (real-time
// listeners + firebase/firestore.rules), not through this Express layer —
// list/getById/create/update/remove below stay 501 on purpose, nothing in
// the client ever calls them. notifyMessage (Part 25 Task 4) is the one
// real handler in this file.
const chatsService = require('../services/chats.service');

async function notifyMessage(req, res, next) {
  try {
    const result = await chatsService.notifyNewMessage(req.params.id, req.body.messageId);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

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

module.exports = { list, getById, create, update, remove, notifyMessage };
