function errorHandler(err, req, res, next) {
  const statusCode = err.statusCode || 500;
  const response = {
    error: {
      code: err.code || 'INTERNAL_SERVER_ERROR',
      message: err.message || 'An unexpected error occurred',
      timestamp: new Date().toISOString(),
      details: err.details || []
    }
  };

  if (process.env.NODE_ENV !== 'test') {
    console.error(`[ERROR] ${err.message}`, err.stack);
  }

  res.status(statusCode).json(response);
}

module.exports = errorHandler;
