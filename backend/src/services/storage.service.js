// Reusable photo/file storage primitives on top of Cloudflare R2
// (S3-compatible, private bucket — never made public). Entity-specific
// services (patients, staff, chats, etc.) call these when they need to
// store/serve a file; this module only knows about bytes and object keys,
// never business rules.
//
// Flow: caller supplies the object key -> compressed with sharp if it's an
// image -> uploaded via PutObjectCommand. The caller stores that KEY (not a
// URL) in Firestore. To display later, the caller re-checks the requester's
// role/branch/clinic access as it would for any other read, then asks
// this module for a short-lived signed GetObjectCommand URL.

const sharp = require('sharp');
const {
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand,
  HeadBucketCommand,
} = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const r2 = require('../config/r2');

const DEFAULT_SIGNED_URL_TTL_SECONDS = 15 * 60;

/**
 * @param {Buffer} buffer - raw file bytes from the multipart upload.
 * @param {string} key - full R2 object key (caller decides the path, e.g. `patients/${id}/photo.jpg`).
 * @param {string} contentType - MIME type of the upload.
 * @returns {Promise<string>} the object key that was stored (same as the `key` argument).
 */
async function uploadFile(buffer, key, contentType) {
  const isImage = contentType?.startsWith('image/');
  const body = isImage ? await sharp(buffer).rotate().resize({ width: 1600, withoutEnlargement: true }).toBuffer() : buffer;

  await r2.getClient().send(
    new PutObjectCommand({
      Bucket: r2.bucketName,
      Key: key,
      Body: body,
      ContentType: contentType,
    })
  );

  return key;
}

/**
 * @param {string} key
 */
async function deleteFile(key) {
  await r2.getClient().send(new DeleteObjectCommand({ Bucket: r2.bucketName, Key: key }));
}

/**
 * @param {string} key
 * @param {number} [expiresInSeconds]
 * @returns {Promise<string>} a signed URL valid only for expiresInSeconds, for this one view.
 */
async function getSignedDownloadUrl(key, expiresInSeconds = DEFAULT_SIGNED_URL_TTL_SECONDS) {
  const command = new GetObjectCommand({ Bucket: r2.bucketName, Key: key });
  return getSignedUrl(r2.getClient(), command, { expiresIn: expiresInSeconds });
}

/**
 * Fetches an object's raw bytes + content type directly (2026-08-17 —
 * "Go Public" wizard's Doctors step). Unlike a signed URL, this lets a
 * caller PROXY the bytes through our own Express server instead of having
 * the browser fetch R2 directly — the bucket has no CORS policy configured
 * for arbitrary browser origins, which silently breaks `Image.network` in
 * Flutter web's CanvasKit renderer (it fetches bytes itself, unlike a plain
 * `<img>` tag, so it's subject to CORS). Serving through our own
 * already-CORS-permissive API sidesteps that entirely.
 * @param {string} key
 * @returns {Promise<{ body: Buffer, contentType: string | undefined }>}
 */
async function getObjectBuffer(key) {
  const response = await r2.getClient().send(new GetObjectCommand({ Bucket: r2.bucketName, Key: key }));
  const chunks = [];
  for await (const chunk of response.Body) chunks.push(chunk);
  return { body: Buffer.concat(chunks), contentType: response.ContentType };
}

/**
 * Confirms the R2 credentials/endpoint/bucket are all correct by checking
 * the bucket actually exists and is reachable (used by GET /api/health-storage).
 */
async function checkBucketConnection() {
  await r2.getClient().send(new HeadBucketCommand({ Bucket: r2.bucketName }));
}

module.exports = {
  uploadFile,
  deleteFile,
  getSignedDownloadUrl,
  getObjectBuffer,
  checkBucketConnection,
  DEFAULT_SIGNED_URL_TTL_SECONDS,
};
