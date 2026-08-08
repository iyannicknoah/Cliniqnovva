const express = require('express');
const router = express.Router();

router.use('/clinics', require('./clinics.routes'));
router.use('/platform', require('./platform.routes'));
router.use('/branches', require('./branches.routes'));
router.use('/departments', require('./departments.routes'));
router.use('/services', require('./services.routes'));
router.use('/staff', require('./staff.routes'));
router.use('/doctors', require('./doctors.routes'));
router.use('/patients', require('./patients.routes'));
router.use('/appointments', require('./appointments.routes'));
router.use('/medicalRecords', require('./medicalRecords.routes'));
router.use('/invoices', require('./invoices.routes'));
router.use('/inventory', require('./inventory.routes'));
router.use('/auditLogs', require('./auditLog.routes'));
router.use('/labOrders', require('./labOrders.routes'));
router.use('/reviews', require('./reviews.routes'));
router.use('/publicHolidays', require('./publicHolidays.routes'));
router.use('/notifications', require('./notifications.routes'));
router.use('/reports', require('./reports.routes'));
router.use('/chats', require('./chats.routes'));
router.use('/auth', require('./auth.routes'));
router.use('/browse', require('./browse.routes'));

module.exports = router;
