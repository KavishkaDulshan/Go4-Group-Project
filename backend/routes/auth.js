'use strict';
const express = require('express');
const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const User = require('../models/User');

const router = express.Router();
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

/**
 * POST /api/v1/auth/google
 * Body: { idToken: string }
 *
 * Verifies the Google Sign-In ID token issued by the Flutter google_sign_in package.
 * Creates the user document on first login (upsert).
 * Returns a signed JWT valid for 30 days.
 *
 * Response 200:
 * { token: string, user: { id, email, displayName, photoUrl } }
 */
router.post('/google', async (req, res, next) => {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({ error: 'idToken is required.' });
    }

    // Verify the token with Google
    const ticket = await client.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();

    // Upsert user record
    const user = await User.findOneAndUpdate(
      { googleId: payload.sub },
      {
        email: payload.email,
        displayName: payload.name,
        photoUrl: payload.picture,
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    // Sign a session token
    const token = jwt.sign(
      { sub: user._id.toString(), email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.json({
      token,
      user: {
        id: user._id.toString(),
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
