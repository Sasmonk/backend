const express = require('express');
const router = express.Router();
const { userAuth } = require('../middleware/auth');
const assetController = require('../controllers/assetController');

// All asset management routes are protected
router.use(userAuth);

// Product Routes
router.get('/products', assetController.getProducts);
router.post('/products', assetController.createProduct);
router.put('/products/:id', assetController.updateProduct);
router.delete('/products/:id', assetController.deleteProduct);

// Truck Routes
router.get('/trucks', assetController.getTrucks);
router.post('/trucks', assetController.createTruck);
// ... add update/delete for trucks

// Destination Routes
router.get('/destinations', assetController.getDestinations);
router.post('/destinations', assetController.createDestination);
// ... add update/delete for destinations

module.exports = router;
