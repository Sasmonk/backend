// routes/devices.js - CORRECTED

const express = require('express');
const router = express.Router();

// --- CONTROLLERS ---
const deviceController = require('../controllers/deviceController');

// --- MIDDLEWARE ---
// ✅ FIX: Changed 'authenticateUser' to 'userAuth' to match what is exported.
const { userAuth } = require('../middleware/auth'); 

// Middleware to authenticate ESP32 devices via API keys
const { authenticateESP32, requireESP32Permission } = require('../middleware/esp32Auth');

/*
==========================================================================================
 🚚 FIRMWARE (ESP32) ENDPOINTS 🚚
==========================================================================================
*/

// Route for GPS data submission
router.post(
    '/gps/submit',
    authenticateESP32,
    requireESP32Permission('can_send_gps'), 
    deviceController.submitGpsData
);

// Route for RFID scan submission
router.post(
    '/rfid/scan', 
    authenticateESP32, 
    requireESP32Permission('can_send_rfid'), 
    deviceController.submitRfidScan
);


/*
==========================================================================================
 👤 USER/ADMINISTRATION ENDPOINTS 👤
==========================================================================================
*/

// Apply user authentication to all routes defined below this point
router.use(userAuth); // ✅ FIX: Use the correctly imported 'userAuth' function

// GET a list of all device statuses for the user's company
router.get('/status', deviceController.getDeviceStatuses);

// POST to register a new device
router.post('/register', deviceController.registerDevice);

// POST to approve a pending device
router.post('/:id/approve', deviceController.approveDevice);

// POST to bind a device to an asset
router.post('/:id/bind', deviceController.bindDevice);

// POST to generate a new API key for a device
router.post('/:id/rotate-key', deviceController.rotateApiKey);

// POST to blacklist/disable a device
router.post('/:id/blacklist', deviceController.blacklistDevice);

// GET logs for a specific device
router.get('/:id/logs', deviceController.getDeviceLogs);


module.exports = router;