const env = require('./config/env');
const app = require('./app');

app.listen(env.port, () => {
  console.log(`Cliniqnovva backend listening on :${env.port} [${env.nodeEnv}]`);
});
