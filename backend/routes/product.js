'use strict';
const express = require('express');
const router = express.Router();
const { enrichProduct } = require('../services/geminiEnrichService');
const { getProductReviews } = require('../services/reviewService');

/**
 * POST /api/v1/product/enrich
 * Body: { title, category?, source?, price? }
 * Returns: { description, specifications, features, compatibility, bestFor }
 */
router.post('/enrich', async (req, res, next) => {
  try {
    const { title, category, source, price } = req.body;
    if (!title || typeof title !== 'string') {
      return res.status(400).json({ error: '"title" is required' });
    }

    console.log(`[Enrich] Enriching: "${title.slice(0, 60)}"`);
    const enriched = await enrichProduct({ title, category, source, price });
    console.log(`[Enrich] ✅ OK — ${enriched.specifications?.length ?? 0} specs, ${enriched.features?.length ?? 0} features`);

    res.json(enriched);
  } catch (err) {
    console.error('[Enrich] ❌', err.message);
    next(err);
  }
});

/**
 * POST /api/v1/product/reviews
 * Body: { title, category? }
 * Returns: { snippets: [{source, title, link, snippet}], analysis: {aiRating, satisfactionPercent, summary, verdict, pros, cons, sentimentLabel} }
 */
router.post('/reviews', async (req, res, next) => {
  try {
    const { title, category } = req.body;
    if (!title || typeof title !== 'string') {
      return res.status(400).json({ error: '"title" is required' });
    }

    console.log(`[Reviews] Fetching reviews: "${title.slice(0, 60)}"`);
    const result = await getProductReviews(title, category);
    console.log(`[Reviews] ✅ ${result.snippets.length} snippets, rating: ${result.analysis.aiRating}`);

    res.json(result);
  } catch (err) {
    console.error('[Reviews] ❌', err.message);
    next(err);
  }
});

module.exports = router;
