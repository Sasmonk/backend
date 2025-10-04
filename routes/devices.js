// routes/devices.js - ENHANCED VERSION
// Replace your existing devices.js with this

const express = require('express');
const router = express.Router();
const { userAuth } = require('../middleware/auth');
const { authenticateESP32, requireESP32Permission } = require('../middleware/esp32Auth');
const { validate, schemas } = require('../middleware/validation');
const deviceController = require('../controllers/deviceController');

// ============================================
// ESP32 DEVICE ENDPOINTS (No user auth, use device auth)
// ============================================

/**
 * POST /api/devices/gps/submit
 * ESP32 GPS tracker submits location data
 * Headers required: x-device-id, x-api-key
 */
router.post('/gps/submit',
    authenticateESP32,
    requireESP32Permission('can_send_gps'),
    validate(schemas.gpsData),
    deviceController.submitGpsData
);

/**
 * POST /api/devices/rfid/scan
 * ESP32 RFID reader submits scanned tag
 * Headers required: x-device-id, x-api-key
 */
router.post('/rfid/scan',
    authenticateESP32,
    requireESP32Permission('can_send_rfid'),
    validate(schemas.rfidScan),
    deviceController.submitRfidScan
);

// ============================================
// ADMIN/USER ENDPOINTS (Requires user login)
// ============================================

router.use(userAuth); // All routes below require user authentication

/**
 * GET /api/devices/status
 * Get status of all ESP32 devices for user's company
 */
router.get('/status', deviceController.getDeviceStatuses);

/**
 * POST /api/devices/register
 * Register a new ESP32 device
 */
router.post('/register',
    validate(schemas.registerDevice),
    deviceController.registerDevice
);

/**
 * POST /api/devices/:id/approve
 * Approve a pending ESP32 device
 */
router.post('/:id/approve', deviceController.approveDevice);

/**
 * POST /api/devices/:id/bind
 * Bind ESP32 device to a truck or destination
 */
router.post('/:id/bind',
    validate(schemas.bindDevice),
    deviceController.bindDevice
);

/**
 * POST /api/devices/:id/rotate-key
 * Rotate API key for security
 */
router.post('/:id/rotate-key', deviceController.rotateApiKey);

/**
 * POST /api/devices/:id/blacklist
 * Blacklist a compromised device
 */
router.post('/:id/blacklist', deviceController.blacklistDevice);

/**
 * GET /api/devices/:id/logs
 * Get authentication and data logs for a device
 */
router.get('/:id/logs', deviceController.getDeviceLogs);

module.exports = router;