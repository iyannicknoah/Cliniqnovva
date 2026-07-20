const dotenv = require('dotenv');
const path = require('path');

const NODE_ENV = process.env.NODE_ENV || 'development';

// Base `.env` (shared across all environments, e.g. R2 credentials for a
// single bucket) loads first; `.env.${NODE_ENV}` loads second and — per
// dotenv's default "don't override already-set keys" behavior — only fills
// in vars the base file didn't already set. This keeps the per-environment
// separation (each env still points at its own Firebase project) while
// making a plain `.env` a real, active config source rather than a dead file.
dotenv.config({ path: path.resolve(process.cwd(), '.env'), quiet: true });
dotenv.config({
  path: path.resolve(process.cwd(), `.env.${NODE_ENV}`),
  quiet: true, // suppress dotenv's startup banner/tips from server logs
});

// Two supported ways to supply Firebase Admin credentials:
// 1. FIREBASE_SERVICE_ACCOUNT_PATH — path to the downloaded service-account JSON file.
// 2. FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / FIREBASE_PRIVATE_KEY — discrete env vars.
const usingServiceAccountFile = Boolean(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);

if (!usingServiceAccountFile) {
  const required = ['FIREBASE_PROJECT_ID', 'FIREBASE_CLIENT_EMAIL', 'FIREBASE_PRIVATE_KEY'];
  for (const key of required) {
    if (!process.env[key]) {
      throw new Error(
        `Missing required environment variable: ${key} (NODE_ENV=${NODE_ENV}). ` +
          'Alternatively set FIREBASE_SERVICE_ACCOUNT_PATH to a service-account JSON file.'
      );
    }
  }
}

module.exports = {
  nodeEnv: NODE_ENV,
  port: parseInt(process.env.PORT, 10) || 3000,
  firebase: {
    serviceAccountPath: process.env.FIREBASE_SERVICE_ACCOUNT_PATH || null,
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') : undefined,
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  },
  smsProvider: {
    apiKey: process.env.SMS_PROVIDER_API_KEY || '',
  },
  r2: {
    accessKeyId: process.env.CLOUDFLARE_R2_ACCESS_KEY_ID,
    secretAccessKey: process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY,
    endpoint: process.env.CLOUDFLARE_R2_ENDPOINT,
    bucketName: process.env.CLOUDFLARE_R2_BUCKET_NAME,
  },
  defaultTimezone: 'Africa/Kigali',
  supportedLocales: ['rw', 'en', 'fr'],
  defaultLocale: process.env.DEFAULT_LOCALE || 'en',
};
