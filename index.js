require('dotenv').config();
const express = require('express');
const cors = require('cors');
const routes = require('./routes');
const errorHandler = require('./middleware/errorHandler');

const app = express();

// Use port from environment variable or default to 3000 for local dev
const PORT = process.env.PORT || 3000;
// Use '0.0.0.0' as the host to be accessible in container environments like Render.
const HOST = '0.0.0.0';

// Middleware
app.use(cors());
app.use(express.json());

// API Routes
app.use('/api', routes);

// Health Check Endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString()
  });
});

// Centralized Error Handler
app.use(errorHandler);

// Start the server
app.listen(PORT, HOST, () => {
  console.log(`✅ Server is running on port ${PORT}`);
});