const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getStorage } = require('firebase-admin/storage');
const { getMessaging } = require('firebase-admin/messaging');
const env = require('./env');

// firebase-admin v12+ uses this modular API (no more admin.apps / admin.credential.cert).
// Credential source: either a service-account JSON file path, or discrete env vars.
function buildCredential() {
  return env.firebase.serviceAccountPath
    ? cert(require(require('path').resolve(env.firebase.serviceAccountPath)))
    : cert({
        projectId: env.firebase.projectId,
        clientEmail: env.firebase.clientEmail,
        privateKey: env.firebase.privateKey,
      });
}

// Initialization failure (e.g. placeholder credentials before a real Firebase
// project exists) must NOT crash the whole process — /api/health and other
// Firebase-independent routes should still work. Anything that actually
// touches db/auth/storage/messaging gets a clear error at call time instead.
let firebaseApp = null;
let initError = null;

if (getApps().length) {
  firebaseApp = getApps()[0];
} else {
  try {
    firebaseApp = initializeApp({
      credential: buildCredential(),
      storageBucket: env.firebase.storageBucket,
    });
  } catch (err) {
    initError = err;
    console.warn(
      '[firebase-admin] Skipping Firebase initialization — credentials are missing or invalid ' +
        '(expected until a real Firebase project exists). Routes that touch Firestore/Auth/Storage/' +
        `Messaging will fail until this is fixed. Cause: ${err.message}`
    );
  }
}

function lazy(getService, name) {
  if (firebaseApp) return getService(firebaseApp);
  return new Proxy(
    {},
    {
      get() {
        throw new Error(
          `Firebase ${name} was used, but Firebase Admin failed to initialize: ${initError?.message}`
        );
      },
    }
  );
}

const db = lazy(getFirestore, 'Firestore');
const auth = lazy(getAuth, 'Auth');
const storage = lazy(getStorage, 'Storage');
const messaging = lazy(getMessaging, 'Messaging');

module.exports = { firebaseApp, db, auth, storage, messaging };
