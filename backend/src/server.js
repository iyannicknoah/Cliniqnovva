const env = require('./config/env');
const app = require('./app');
const { startPopularityRecalcJob } = require('./jobs/popularityRecalc.job');

app.listen(env.port, () => {
  console.log(`Cliniqnovva backend listening on :${env.port} [${env.nodeEnv}]`);
});

startPopularityRecalcJob();
