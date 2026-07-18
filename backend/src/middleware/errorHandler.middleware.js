function notFound(req, res) {
  res.status(404).json({ error: `No route for ${req.method} ${req.originalUrl}` });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const status = err.status || 500;
  if (status >= 500) {
    console.error(err);
  }
  // Client errors (4xx) are safe to surface as-is (e.g. validation messages);
  // 5xx get a generic message so internals never leak to the response.
  const fallback = status < 500 ? err.message : 'Internal server error';
  res.status(status).json({
    error: err.publicMessage || fallback,
  });
}

module.exports = { notFound, errorHandler };
