require('dotenv').config();
const express = require('express');
const cors = require('cors');
const apiRoutes = require('./routes'); // This correctly imports from routes/index.js
const errorHandler = require('./middleware/errorHandler');

const app = express();

const PORT = process.env.PORT || 3000;
// This is crucial for deployment on services like Render
const HOST = '0.0.0.0'; 

// Core Middleware
app.use(cors());
app.use(express.json());

// ✅ FIX: Add a simple, root-level health check for Render
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// API Routes
// All routes defined in the './routes' folder will now be prefixed with /api
app.use('/api', apiRoutes);

// Central Error Handler - Must be the last 'app.use()'
app.use(errorHandler);

app.listen(PORT, HOST, () => {
  console.log(`✅ Server is running on port ${PORT}`);
});