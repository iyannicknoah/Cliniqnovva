// Controller for /api/v1/platform — Super Admin oversight/support tools
// (Part 5). Keep thin: parse/validate req, call platform.service.js.
const platformService = require('../services/platform.service');

async function getMetrics(req, res, next) {
  try {
    const metrics = await platformService.getMetrics();
    res.json({ metrics });
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

module.exports = { getMetrics, startSupportView, endSupportView, getRevenueTrend };
