// Controller for /api/v1/publicHolidays — spec section 1 / 9.
// list/getById are real (Part 8's Doctor Schedule screen reads these to
// show auto-blocked dates). create/update/remove stay stubs — managing the
// list is a later part's scope.
const publicHolidaysService = require('../services/publicHolidays.service');

async function list(req, res, next) {
  try {
    const holidays = await publicHolidaysService.list();
    res.json({ holidays });
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const holiday = await publicHolidaysService.getById(req.params.id);
    if (!holiday) return res.status(404).json({ error: 'Holiday not found' });
    res.json({ holiday });
  } catch (err) {
    next(err);
  }
}

async function create(req, res) {
  res.status(501).json({ error: 'Not implemented yet: create publicHolidays' });
}

async function update(req, res) {
  res.status(501).json({ error: 'Not implemented yet: update publicHolidays' });
}

async function remove(req, res) {
  res.status(501).json({ error: 'Not implemented yet: remove publicHolidays' });
}

module.exports = { list, getById, create, update, remove };
