const { S3Client } = require('@aws-sdk/client-s3');
const env = require('./env');

// Same non-fatal init pattern as firebase-admin.js: a missing/placeholder R2
// config must not crash the whole process — only routes that actually touch
// photo storage should fail, and only when called.
let client = null;
let initError = null;

if (env.r2.accessKeyId && env.r2.secretAccessKey && env.r2.endpoint) {
  client = new S3Client({
    region: 'auto',
    endpoint: env.r2.endpoint,
    credentials: {
      accessKeyId: env.r2.accessKeyId,
      secretAccessKey: env.r2.secretAccessKey,
    },
  });
} else {
  initError = new Error('Missing CLOUDFLARE_R2_* environment variables');
  console.warn(
    '[r2] Skipping R2 client initialization — credentials are missing. ' +
      'Routes that touch photo storage will fail until this is fixed.'
  );
}

function getClient() {
  if (!client) {
    throw new Error(`R2 client was used, but R2 failed to initialize: ${initError?.message}`);
  }
  return client;
}

module.exports = { getClient, bucketName: env.r2.bucketName };
