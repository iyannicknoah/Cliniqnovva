const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const i18nextMiddleware = require('i18next-http-middleware');

const env = require('./config/env');
const i18next = require('./config/i18n');
const routes = require('./routes');
const { defaultRateLimiter } = require('./middleware/rateLimiter.middleware');
const { notFound, errorHandler } = require('./middleware/errorHandler.middleware');

const app = express();

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json({ limit: '2mb' }));
app.use(morgan(env.nodeEnv === 'production' ? 'combined' : 'dev'));
app.use(i18nextMiddleware.handle(i18next));
app.use(defaultRateLimiter);

app.get('/health', (req, res) => res.json({ status: 'ok', env: env.nodeEnv }));

app.use('/api/v1', routes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
