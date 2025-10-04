const express = require('express');
const router = express.Router();

const shipmentRoutes = require('./shipments');
const deviceRoutes = require('./devices');
const reportRoutes = require('./reports');
const assetRoutes = require('./assets');

// Health check endpoint
router.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Attach all resource routers
router.use('/shipments', shipmentRoutes);
router.use('/devices', deviceRoutes);
router.use('/reports', reportRoutes);
router.use('/assets', assetRoutes);


module.exports = router;
