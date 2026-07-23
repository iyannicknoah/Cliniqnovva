// Controller for /api/v1/platform — Super Admin oversight/support tools
// (Part 5). Keep thin: parse/validate req, call platform.service.js.
const platformService = require('../services/platform.service');

async function search(req, res, next) {
  try {
    const results = await platformService.search(req.query.query);
    res.json(results);
  } catch (err) {
    next(err);
  }
}

async function getMetrics(req, res, next) {
  try {
    const metrics = await platformService.getMetrics();
    res.json({ metrics });
  } catch (err) {
    next(err);
  }
}

async function getAuditLog(req, res, next) {
  try {
    const { organizationId, actorId, action, dateFrom, dateTo, limit } = req.query;
    const auditLog = await platformService.getAuditLog({ organizationId, actorId, action, dateFrom, dateTo, limit });
    res.json({ auditLog });
  } catch (err) {
    next(err);
  }
}

async function viewRecord(req, res, next) {
  try {
    const { collection, id } = req.params;
    const record = await platformService.viewRecord(collection, id, req.user?.uid);
    if (!record) return res.status(404).json({ error: 'Record not found' });
    res.json({ record });
  } catch (err) {
    next(err);
  }
}

async function startSupportView(req, res, next) {
  try {
    const result = await platformService.startSupportView(req.params.organizationId, req.user?.uid);
    if (!result) return res.status(404).json({ error: 'Organization not found' });
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

async function endSupportView(req, res, next) {
  try {
    await platformService.endSupportView(req.params.organizationId, req.body?.sessionId, req.user?.uid);
    res.json({ success: true });
  } catch (err) {
    next(err);
  }
}

async function getRevenueTrend(req, res, next) {
  try {
    const revenueTrend = await platformService.getRevenueTrend({ months: req.query.months });
    res.json({ revenueTrend });
  } catch (err) {
    next(err);
  }
}

module.exports = { search, getMetrics, getAuditLog, viewRecord, startSupportView, endSupportView, getRevenueTrend };
