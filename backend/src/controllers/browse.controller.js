// Controller for /api/v1/browse — Part 20, Patient App only (see route's
// requireRole(ROLES.PATIENT)). Thin: parse query params, call
// browse.service.js, shape the response.
const browseService = require('../services/browse.service');

async function listBranches(req, res, next) {
  try {
    const { search, sortBy, department } = req.query;
    const result = await browseService.listBranches({ search, sortBy, department });
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function getBranchDetail(req, res, next) {
  try {
    const result = await browseService.getBranchDetail(req.params.branchId);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

async function listBranchReviews(req, res, next) {
  try {
    const { limit, offset } = req.query;
    const result = await browseService.listBranchReviews(req.params.branchId, { limit, offset });
    res.json(result);
  } catch (err) {
    next(err);
  }
}

module.exports = { listBranches, getBranchDetail, listBranchReviews };
