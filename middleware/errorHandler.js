const errorHandler = (err, req, res, next) => {
  // Log the error for debugging purposes on the server
  console.error("💥 Unhandled Error:", err);

  // Use the status code from the error if it exists, otherwise default to 500
  const statusCode = err.statusCode || 500;

  res.status(statusCode).json({
    success: false,
    error: err.message || 'Internal Server Error',
    // Only show the stack trace in development environments for security
    stack: process.env.NODE_ENV === 'production' ? null : err.stack,
  });
};

// FIX: Export the function directly instead of in an object
module.exports = errorHandler;