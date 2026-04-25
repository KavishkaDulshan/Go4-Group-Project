'use strict';
const express = require('express');
const { searchShopping } = require('../services/serperService');
const { getUserPreferences } = require('../services/preferenceLearningService');

const router = express.Router();

/**
 * GET /api/v1/recommendations
 *
 * Returns personalized product recommendations based on the user's learned
 * preference profile (materials, styles, categories, price range).
 *
 * Requires: valid JWT (enforced by authMiddleware in server.js)
 *
 * Response 200:
 * {
 *   preferences: { searchCount, topCategory, topMaterial, topStyle, topColor,
 *                  priceRange, allCategories, allMaterials, allStyles, allColors },
 *   recommendations: [ Product, ... ],
 *   query: string,
 *   message?: string   ← present when user needs more searches
 * }
 */
router.get('/', async (req, res, next) => {
  if (!req.user?.sub) {
    return res.status(401).json({ error: 'Sign in to get personalised recommendations.' });
  }

  try {
    const prefs = await getUserPreferences(req.user.sub);

    const MIN_SEARCHES = 2; // minimum before we generate real recommendations
    if (!prefs || prefs.searchCount < MIN_SEARCHES) {
      return res.json({
        preferences: prefs ? _summarisePrefs(prefs) : { searchCount: 0 },
        recommendations: [],
        query: null,
        message: `Search for at least ${MIN_SEARCHES} products to unlock personalised recommendations.`,
      });
    }

    // Build a preference-weighted query
    const queryParts = [];
    if (prefs.categories?.length > 0) queryParts.push(prefs.categories[0].value);
    if (prefs.materials?.length > 0) queryParts.push(prefs.materials[0].value);
    if (prefs.styles?.length > 0) queryParts.push(prefs.styles[0].value);

    const query = queryParts.length > 0 ? queryParts.join(' ') : 'popular products';

    console.log(`[Recs] Building recommendations for user ${req.user.sub} → query="${query}"`);
    const results = await searchShopping(query, { num: 20 });

    return res.json({
      preferences: _summarisePrefs(prefs),
      recommendations: results,
      query,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/v1/recommendations/preferences
 *
 * Returns just the raw preference summary for the signed-in user.
 */
router.get('/preferences', async (req, res, next) => {
  if (!req.user?.sub) {
    return res.status(401).json({ error: 'Authentication required.' });
  }
  try {
    const prefs = await getUserPreferences(req.user.sub);
    return res.json(prefs ? _summarisePrefs(prefs) : { searchCount: 0 });
  } catch (err) {
    next(err);
  }
});

// ── Helpers ───────────────────────────────────────────────────────────────────

function _summarisePrefs(prefs) {
  return {
    searchCount: prefs.searchCount ?? 0,
    topCategory: prefs.categories?.[0]?.value ?? null,
    topMaterial: prefs.materials?.[0]?.value ?? null,
    topStyle: prefs.styles?.[0]?.value ?? null,
    topColor: prefs.colors?.[0]?.value ?? null,
    priceRange: prefs.priceRange ?? null,
    allCategories: (prefs.categories ?? []).slice(0, 5),
    allMaterials: (prefs.materials ?? []).slice(0, 5),
    allStyles: (prefs.styles ?? []).slice(0, 5),
    allColors: (prefs.colors ?? []).slice(0, 5),
  };
}

module.exports = router;
