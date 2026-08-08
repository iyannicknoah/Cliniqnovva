// Part 22 Task 3 — "NEW scheduled job (node-cron, running hourly)".
// Registered once at server startup, same pattern as popularityRecalc.job.js
// and purgeArchivedClinics.job.js. The underlying function it calls
// (appointmentsService.sendDueReminders) is the exact same one a future
// manual-trigger endpoint would call, if one is ever added — one code path.
const cron = require('node-cron');
const appointmentsService = require('../services/appointments.service');

// Hourly, on the hour (Task 3's own wording) — closely tracks the job's
// own 24h/2h windows, so no appointment can drift more than ~1 hour past
// either threshold before its reminder fires.
const SCHEDULE = '0 * * * *';

function startAppointmentRemindersJob() {
  cron.schedule(
    SCHEDULE,
    async () => {
      try {
        const { sent } = await appointmentsService.sendDueReminders();
        console.log(`[appointmentReminders] sent ${sent} reminder(s)`);
      } catch (err) {
        console.error('[appointmentReminders] failed:', err.message);
      }
    },
    { timezone: 'Africa/Kigali' }
  );
}

module.exports = { startAppointmentRemindersJob, SCHEDULE };
