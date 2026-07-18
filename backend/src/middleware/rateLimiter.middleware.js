const rateLimit = require('express-rate-limit');

// Spec 6.1 / 10: API rate limiting on authentication endpoints to prevent brute-force.
const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many attempts, please try again later' },
});

// Looser default limiter for general API traffic.
const defaultRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = { authRateLimiter, defaultRateLimiter };
