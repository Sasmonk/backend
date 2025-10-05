require('dotenv').config();
const express = require('express');
const cors = require('cors');
const apiRoutes = require('./routes');
// FIX: Import the errorHandler function directly
const errorHandler = require('./middleware/errorHandler');

const app = express();

// Use port from environment variable, default to 3000 for local development
const PORT = process.env.PORT || 3000;
// FIX: Define the host for containerized environments like Render
const HOST = '0.0.0.0';

// Core Middleware
app.use(cors());
app.use(express.json());

// Main API Routes
app.use('/api', apiRoutes);

// Health Check Endpoint for Render to verify the service is live
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Centralized Error Handler - This must be the LAST `app.use()` call
app.use(errorHandler);

// Start the server
app.listen(PORT, HOST, () => {
  console.log(`✅ Server is running on port ${PORT}`);
});