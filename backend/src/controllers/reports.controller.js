// Controller for /api/v1/reports — spec section 6.10 (Part 14). Read-only —
// every export (CSV/PDF) is generated client-side from this same JSON, so
// there's exactly one code path per report, not a duplicate export variant.
const reportsService = require('../services/reports.service');

function resolveClinicId(req, explicit) {
  return req.scope.level === 'platform' ? explicit : req.scope.clinicId;
}

function resolveBranchId(req, explicit) {
  return req.scope.level === 'branch' ? req.scope.branchId : explicit;
}

async function revenue(req, res, next) {
  try {
    const report = await reportsService.revenue({
      clinicId: resolveClinicId(req, req.query.clinicId),
      branchId: resolveBranchId(req, req.query.branchId),
      dateFrom: req.query.dateFrom,
      dateTo: req.query.dateTo,
      groupBy: req.query.groupBy,
    });
    res.json({ report });
  } catch (err) {
    next(err);
  }
}

async function patientVolume(req, res, next) {
  try {
    const report = await reportsService.patientVolume({
      clinicId: resolveClinicId(req, req.query.clinicId),
      branchId: resolveBranchId(req, req.query.branchId),
      dateFrom: req.query.dateFrom,
      dateTo: req.query.dateTo,
      groupBy: req.query.groupBy,
    });
    res.json({ report });
  } catch (err) {
    next(err);
  }
}

async function noShowRate(req, res, next) {
  try {
    const report = await reportsService.noShowRate({
      clinicId: resolveClinicId(req, req.query.clinicId),
      branchId: resolveBranchId(req, req.query.branchId),
      dateFrom: req.query.dateFrom,
      dateTo: req.query.dateTo,
    });
    res.json({ report });
  } catch (err) {
    next(err);
  }
}

module.exports = { revenue, patientVolume, noShowRate };
