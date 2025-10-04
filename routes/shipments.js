const express = require('express');
const router = express.Router();
const { userAuth } = require('../middleware/auth');
const shipmentController = require('../controllers/shipmentController');

// All routes in this file are protected and require a logged-in user.
router.use(userAuth);

router.post('/', shipmentController.createShipment);
router.get('/', shipmentController.getActiveShipments);
router.get('/history', shipmentController.getCompletedShipments);
router.get('/:id', shipmentController.getShipmentById);
router.put('/:id', shipmentController.updateShipmentStatus); // For cancelling, etc.
router.delete('/:id', shipmentController.deleteShipment);
router.post('/:id/complete', shipmentController.completeShipmentVerification);

module.exports = router;
