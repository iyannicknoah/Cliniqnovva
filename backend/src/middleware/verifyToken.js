const { auth } = require('../config/firebase-admin');

/**
 * Verifies the Firebase ID token on the Authorization header and attaches
 * the decoded token (uid, custom claims: role/organizationId/branchId) to req.user.
 * Every route in this API sits behind this middleware except public health checks.
 */
async function verifyToken(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }

  try {
    const decoded = await auth.verifyIdToken(token);

    if (decoded.isActive === false) {
      return res.status(403).json({ error: 'Account is deactivated' });
    }

    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { verifyToken };
