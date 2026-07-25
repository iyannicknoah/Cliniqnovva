// Controller for /api/v1/notifications — spec section 6.11 (Part 14).
// list() is always scoped to the CALLER (req.user.uid) — there is no
// "list someone else's notifications" capability for any role, this isn't
// an admin-oversight collection.
const notificationsService = require('../services/notifications.service');

async function list(req, res, next) {
  try {
    const notifications = await notificationsService.list(req.user.uid);
    res.json({ notifications });
  } catch (err) {
    next(err);
  }
}

/** The one narrow write exposed to clients — see notifications.service.js's markRead(). */
async function markRead(req, res, next) {
  try {
    const notification = await notificationsService.markRead(req.params.id, req.user.uid);
    res.json({ notification });
  } catch (err) {
    next(err);
  }
}

async function markAllRead(req, res, next) {
  try {
    const result = await notificationsService.markAllRead(req.user.uid);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

module.exports = { list, markRead, markAllRead };
