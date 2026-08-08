// Must be required BEFORE any service/controller/middleware module in a
// test file. It swaps out backend/src/config/firebase-admin.js's exports
// for in-memory mocks by pre-seeding Node's own require.cache under that
// file's resolved absolute path — every later `require('../config/firebase-
// admin')` anywhere in the app (services, middleware) resolves to the same
// absolute path and gets these mocks instead of ever touching real
// Firebase, network, or credentials.
const Module = require('module');
const { MockFirestore } = require('./mockFirestore');
const { MockAuth } = require('./mockAuth');
const { MockMessaging } = require('./mockMessaging');

const db = new MockFirestore();
const auth = new MockAuth();
const messaging = new MockMessaging();

const resolvedPath = require.resolve('../../src/config/firebase-admin');
const fakeModule = new Module(resolvedPath, module);
fakeModule.filename = resolvedPath;
fakeModule.loaded = true;
fakeModule.exports = { firebaseApp: {}, db, auth, storage: {}, messaging };
require.cache[resolvedPath] = fakeModule;

// Service modules destructure `{ db }`/`{ auth }` at require-time, binding
// to these exact instances — so "reset" clears their internal state in
// place rather than replacing the objects (which those already-required
// modules would never see).
function reset() {
  db.docs.clear();
  db._counter = 0;
  auth.users.clear();
  auth._counter = 0;
  messaging.sent.length = 0;
}

function actor({ actorId = 'actor1', role, clinicId, branchId, level }) {
  const scopeLevel =
    level || (role === 'super_admin' ? 'platform' : role === 'patient' ? 'patient' : role === 'clinic_admin' ? 'clinic' : 'branch');
  const scope =
    scopeLevel === 'platform'
      ? { level: 'platform' }
      : scopeLevel === 'patient'
        ? { level: 'patient' }
        : scopeLevel === 'clinic'
          ? { level: 'clinic', clinicId }
          : { level: 'branch', clinicId, branchId };
  return { actorId, role, actorRole: role, scope };
}

module.exports = { db, auth, messaging, reset, actor };
