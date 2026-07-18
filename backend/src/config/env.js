const dotenv = require('dotenv');
const path = require('path');

const NODE_ENV = process.env.NODE_ENV || 'development';

dotenv.config({
  path: path.resolve(process.cwd(), `.env.${NODE_ENV}`),
  quiet: true, // suppress dotenv's startup banner/tips from server logs
});

const required = ['FIREBASE_PROJECT_ID', 'FIREBASE_CLIENT_EMAIL', 'FIREBASE_PRIVATE_KEY'];

for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key} (NODE_ENV=${NODE_ENV})`);
  }
}

module.exports = {
  nodeEnv: NODE_ENV,
  port: parseInt(process.env.PORT, 10) || 4000,
  firebase: {
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
  },
  smsProvider: {
    apiKey: process.env.SMS_PROVIDER_API_KEY || '',
  },
  defaultTimezone: 'Africa/Kigali',
  supportedLocales: ['rw', 'en', 'fr'],
  defaultLocale: process.env.DEFAULT_LOCALE || 'en',
};
