// Part 16 Task 4 — "recalculated daily via node-cron, not per-request".
// Registered once at server startup (see server.js); the underlying
// function it calls is the exact same one POST /api/v1/reviews/
// recalculate-popularity triggers manually (Task 6), so there's only ever
// one code path to keep correct.
const cron = require('node-cron');
const reviewsService = require('../services/reviews.service');

// 02:00 Africa/Kigali (UTC+2, no DST — spec section 1) — off-hours, well
// after any given day's clinic activity has settled.
const SCHEDULE = '0 2 * * *';

function startPopularityRecalcJob() {
  cron.schedule(
    SCHEDULE,
    async () => {
      try {
        const { recalculated } = await reviewsService.recalculatePopularityForAllBranches();
        console.log(`[popularityRecalc] recalculated ${recalculated} branch(es)`);
      } catch (err) {
        console.error('[popularityRecalc] failed:', err.message);
      }
    },
    { timezone: 'Africa/Kigali' }
  );
}

module.exports = { startPopularityRecalcJob, SCHEDULE };
