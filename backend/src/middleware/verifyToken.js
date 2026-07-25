const { auth } = require('../config/firebase-admin');

/**
 * Verifies the Firebase ID token on the Authorization header and attaches
 * the decoded token (uid, custom claims: role/clinicId/branchId) to req.user.
 * Every route in this API sits behind this middleware except public health checks.
 *
 * PATCH (Part 18 Task 1 — security review): `checkRevoked: true` costs one
 * extra Auth backend round-trip per request, but it's the only thing that
 * makes staff.service.js's setStatus(isActive: false) — which calls
 * `auth.updateUser(id, { disabled: true })` — actually block that user's
 * ALREADY-ISSUED token immediately. Without it, `verifyIdToken` only checks
 * the JWT signature/expiry, so a deactivated staff member's existing token
 * would keep working for up to an hour. (A previous `decoded.isActive ===
 * false` check here was dead code: `isActive` was never a custom claim, only
 * a Firestore field — it could never be false. Removed.)
 */
async function verifyToken(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Missing bearer token' });
  }

  try {
    const decoded = await auth.verifyIdToken(token, true);
    req.user = decoded;
    next();
  } catch (err) {
    if (err.code === 'auth/user-disabled') {
      return res.status(403).json({ error: 'Account is deactivated' });
    }
    if (err.code === 'auth/id-token-revoked') {
      return res.status(401).json({ error: 'Session has been revoked — please sign in again' });
    }
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { verifyToken };
