'use strict';
const { GoogleGenerativeAI } = require('@google/generative-ai');
const fs = require('fs');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const SYSTEM_PROMPT = `You are a retail product identification assistant.
Analyze the provided image (and optional voice hint) and return ONLY a valid JSON object with exactly these fields:
{
  "productName": "string – the most specific product name (e.g. 'linen button-down shirt')",
  "category":    "string – top-level retail category (e.g. 'Clothing', 'Electronics', 'Furniture', 'Footwear')",
  "color":       "string or null – dominant color",
  "material":    "string or null – primary material if visible",
  "style":       "string or null – style descriptor (e.g. 'casual', 'formal', 'vintage', 'sporty')",
  "searchQuery": "string – optimized Google Shopping search query combining all attributes"
}
Return ONLY the raw JSON object. No markdown fences, no prose, no explanation.`;

/**
 * Analyze a product image using Gemini 2.5 Flash.
 *
 * @param {string}      imagePath  - Absolute path to image file on disk.
 * @param {string}      mimeType   - MIME type, e.g. 'image/jpeg'.
 * @param {string|null} transcript - Optional voice transcript from user.
 * @returns {Promise<{productName,category,color,material,style,searchQuery}>}
 */
async function analyzeImage(imagePath, mimeType, transcript = null) {
  const model = genAI.getGenerativeModel(
    { model: 'gemini-2.5-flash' },
    { generationConfig: { responseMimeType: 'application/json' } }
  );

  const imageData = fs.readFileSync(imagePath).toString('base64');
  const imagePart = { inlineData: { data: imageData, mimeType } };
  const textPart = transcript
    ? `${SYSTEM_PROMPT}\n\nAdditional voice hint from the user: "${transcript}"`
    : SYSTEM_PROMPT;

  const result = await model.generateContent([imagePart, textPart]);
  const raw = result.response.text().trim();

  // Defensively strip markdown fences in case responseMimeType is ignored
  const clean = raw
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '');

  return JSON.parse(clean);
}

module.exports = { analyzeImage };
