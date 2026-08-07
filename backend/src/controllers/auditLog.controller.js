// Controller for /api/v1/auditLogs — view-only, restored 2026-07-29 (see
// auditLog.service.js for the removal/restoration history). Keep thin:
// parse/validate req, call auditLog.service.js, shape the response.
const auditLogService = require('../services/auditLog.service');

function resolveClinicId(req, explicit) {
  return req.scope.level === 'platform' ? explicit : req.scope.clinicId;
}

async function list(req, res, next) {
  try {
    const clinicId = resolveClinicId(req, req.query.clinicId);
    const logs = await auditLogService.list({
      clinicId,
      actorId: req.query.actorId,
      action: req.query.action,
      dateFrom: req.query.dateFrom,
      dateTo: req.query.dateTo,
    });
    res.json({ logs });
  } catch (err) {
    next(err);
  }
}

module.exports = { list };
