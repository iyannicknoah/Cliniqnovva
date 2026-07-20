const express = require('express');
const router = express.Router();
const storageService = require('../services/storage.service');
const r2 = require('../config/r2');

// Confirms Access Key, Secret, Endpoint, and bucket name are all correct by
// actually reaching R2 (HeadBucketCommand), not just checking env vars exist.
router.get('/health-storage', async (req, res) => {
  try {
    await storageService.checkBucketConnection();
    res.json({ status: 'ok', bucket: r2.bucketName });
  } catch (err) {
    res.status(503).json({ status: 'error', bucket: r2.bucketName, message: err.message });
  }
});

module.exports = router;
