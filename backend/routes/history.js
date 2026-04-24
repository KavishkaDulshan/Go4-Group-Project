'use strict';
const express = require('express');
const mongoose = require('mongoose');
const SearchHistory = require('../models/SearchHistory');

const router = express.Router();

/**
 * GET /api/v1/history
 * Optional query param: ?sessionId=<string>
 *
 * Authentication (via soft middleware in server.js):
 *   - Signed-in user  → filter by userId
 *   - Anonymous       → filter by sessionId (if provided)
 *   - Neither         → return []
 *
 * Response 200: Array of up to 50 history items, newest first.
 * Each item: { searchId, tags, results, imagePath, createdAt }
 */
router.get('/', async (req, res, next) => {
  try {
    let filter;

    if (req.user?.sub) {
      filter = { userId: new mongoose.Types.ObjectId(req.user.sub) };
    } else if (req.query.sessionId) {
      filter = { sessionId: req.query.sessionId };
    } else {
      return res.json([]);
    }

    const docs = await SearchHistory.find(filter)
      .sort({ createdAt: -1 })
      .limit(50)
      .select('_id tags results imagePath createdAt')
      .lean();

    // Strip base64 data URIs that old records may have stored before the
    // upstream serperService filtering was added.  A single base64 thumbnail
    // can be ~100 KB — multiplied across many products and history items it
    // easily blows DIO's 30-second receive timeout.
    const sanitizeProduct = (p) => ({
      ...p,
      imageUrl:   p.imageUrl?.startsWith('data:')   ? null : (p.imageUrl  ?? null),
      thumbnail:  p.thumbnail?.startsWith('data:')  ? null : (p.thumbnail ?? null),
      // Drop the extensions array — it is not displayed in the history card
      // and can be sizeable for some products.
      extensions: undefined,
    });

    const items = docs.map((d) => ({
      searchId:  d._id.toString(),
      tags:      d.tags,
      // Limit to the first 10 products — history cards only show 3 thumbnails
      // and re-running the search loads the full list anyway.
      results:   (d.results ?? []).slice(0, 10).map(sanitizeProduct),
      imagePath: d.imagePath,
      createdAt: d.createdAt,
    }));

    console.log(`[History] ✅  ${items.length} item(s) for ${req.user?.sub ? `user ${req.user.sub}` : `session ${req.query.sessionId}`}`);
    return res.json(items);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
