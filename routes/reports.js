const express = require('express');
const router = express.Router();
const { userAuth } = require('../middleware/auth');
const reportController = require('../controllers/reportController');

// All reports are protected
router.use(userAuth);

router.get('/missing-products', reportController.getMissingProductsReport);
router.get('/truck-utilization', reportController.getTruckUtilizationReport);
router.get('/delivery-performance', reportController.getDeliveryPerformanceReport);
router.get('/alerts', reportController.getSystemAlerts);

module.exports = router;
