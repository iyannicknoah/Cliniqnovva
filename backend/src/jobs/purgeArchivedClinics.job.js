// "Delete clinic" archives rather than hard-deletes (2026-07-25, explicit
// user instruction) — this job is what actually makes deletion permanent,
// PURGE_AFTER_DAYS (14) after archiving, same registered-at-startup pattern
// popularityRecalc.job.js already uses.
const cron = require('node-cron');
const clinicsService = require('../services/clinics.service');

// 02:30 Africa/Kigali — 30 minutes after popularityRecalc's 02:00 slot, off
// hours, avoids the two jobs racing each other.
const SCHEDULE = '30 2 * * *';

function startPurgeArchivedClinicsJob() {
  cron.schedule(
    SCHEDULE,
    async () => {
      try {
        const { purged } = await clinicsService.permanentlyDeleteArchivedClinics();
        console.log(`[purgeArchivedClinics] permanently deleted ${purged} clinic(s)`);
      } catch (err) {
        console.error('[purgeArchivedClinics] failed:', err.message);
      }
    },
    { timezone: 'Africa/Kigali' }
  );
}

module.exports = { startPurgeArchivedClinicsJob, SCHEDULE };
