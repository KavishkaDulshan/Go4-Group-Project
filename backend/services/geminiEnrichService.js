'use strict';
const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const ENRICH_PROMPT = `You are a product information specialist. Given a product title, category, store source, and price, return a comprehensive JSON object.

The JSON must have exactly these fields:
{
  "description": "2-3 sentence overview of what this product is and its main value",
  "specifications": [
    { "key": "string", "value": "string" }
  ],
  "features": ["string"],
  "compatibility": "string or null",
  "bestFor": "string"
}

Rules:
- "specifications": 5-10 of the most important specs for this product type (e.g. for laptops: CPU, RAM, Storage, Display, OS, Battery, Weight; for clothing: Material, Fit, Care; for phones: Screen, Processor, RAM, Storage, Camera, Battery)
- "features": 3-6 concise bullet-point feature highlights (no leading dash)
- "compatibility": device/software compatibility or null if not relevant
- "bestFor": a single sentence describing the ideal buyer/use case

Return ONLY valid JSON. No markdown fences, no prose.`;

/**
 * Enrich a product with AI-generated specifications and descriptions.
 *
 * @param {object} params
 * @param {string} params.title    - Product title from search results.
 * @param {string} [params.category] - Product category from Gemini image analysis.
 * @param {string} [params.source] - Store name.
 * @param {string} [params.price]  - Price string.
 * @returns {Promise<{description, specifications, features, compatibility, bestFor}>}
 */
async function enrichProduct({ title, category, source, price }) {
  const model = genAI.getGenerativeModel(
    { model: 'gemini-2.5-flash' },
    { generationConfig: { responseMimeType: 'application/json' } }
  );

  const userContent = [
    `Product: "${title}"`,
    `Category: "${category ?? 'General'}"`,
    `Store: "${source ?? 'Online store'}"`,
    `Price: "${price ?? 'Not specified'}"`,
  ].join('\n');

  const result = await model.generateContent(`${ENRICH_PROMPT}\n\n${userContent}`);
  const raw = result.response.text().trim();

  // Strip markdown fences defensively
  const clean = raw
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '');

  return JSON.parse(clean);
}

module.exports = { enrichProduct };
