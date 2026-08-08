const env = require('./config/env');
const app = require('./app');
const { startPopularityRecalcJob } = require('./jobs/popularityRecalc.job');
const { startPurgeArchivedClinicsJob } = require('./jobs/purgeArchivedClinics.job');
const { startAppointmentRemindersJob } = require('./jobs/appointmentReminders.job');

app.listen(env.port, () => {
  console.log(`Cliniqnovva backend listening on :${env.port} [${env.nodeEnv}]`);
});

startPopularityRecalcJob();
startPurgeArchivedClinicsJob();
startAppointmentRemindersJob();
