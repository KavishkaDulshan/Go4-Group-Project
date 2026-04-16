'use strict';
const jwt = require('jsonwebtoken');

/**
 * Soft JWT middleware.
 * Populates req.user from a valid Bearer token but never rejects the request —
 * routes that need auth can check req.user themselves.
 */
module.exports = (req, _res, next) => {
  const auth = req.headers.authorization;
  if (auth?.startsWith('Bearer ')) {
    try {
      req.user = jwt.verify(auth.slice(7), process.env.JWT_SECRET);
    } catch (_) {
      // Invalid / expired token → stay anonymous
    }
  }
  next();
};
