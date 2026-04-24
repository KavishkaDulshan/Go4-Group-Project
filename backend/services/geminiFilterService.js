'use strict';
const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const FILTER_PROMPT = `You are a smart product search filter generator.
You will be given a product name, category, and optional user hints.
Your job is to generate 3–5 smart search filters that help the user refine their product search.

Return ONLY a valid JSON array. Each element must have exactly these fields:
{
  "key":          "string — lowercase snake_case identifier (e.g. 'ram', 'screen_size', 'color')",
  "label":        "string — short human-readable label shown to the user (e.g. 'RAM', 'Screen Size', 'Color')",
  "type":         "dropdown | chips",
  "options":      [{"value": "string", "label": "string"}],
  "defaultValue": "string matching an option value, or null"
}

Type rules:
- Use 'chips'    for visual / categorical attributes that look good as tap tiles:
    color, brand, style, material, condition
- Use 'dropdown' for specs with many values or ordered ranges:
    RAM, storage, screen size, price range, age range

Category guidelines (add or remove filters based on what makes sense):
- Laptops / Computers : Brand (chips), RAM (dropdown), Storage (dropdown), Screen Size (dropdown)
- Mobile / Phones     : Brand (chips), RAM (dropdown), Storage (dropdown), Condition (chips)
- Clothing / Apparel  : Size (chips: XS S M L XL XXL), Color (chips), Material (chips), Style (chips)
- Footwear            : Size (dropdown: numeric), Color (chips), Brand (chips), Material (chips)
- Furniture           : Material (chips), Color (chips), Size (dropdown)
- Sports / Fitness    : Brand (chips), Material (chips), Weight (dropdown if applicable)
- Toys / Games        : Age Range (dropdown), Brand (chips), Material (chips)
- TV / Audio          : Brand (chips), Screen Size / Size (dropdown), Resolution (chips if TV)
- Cameras             : Brand (chips), Megapixels (dropdown), Type (chips: DSLR Mirrorless Point-and-shoot)
- General / Unknown   : Color (chips), Brand (chips), Price Range (dropdown), Condition (chips)

Additional rules:
- Generate exactly 3–5 filters — pick the most useful ones for this specific product.
- Each filter must have 4–8 options.
- Pre-fill 'defaultValue' only when the user's context clearly implies a preference
  (e.g. they said "blue shirt" → color defaultValue = "blue").
- Keep option labels concise (1–4 words).
- Return ONLY the JSON array. No markdown fences, no prose.`;

/**
 * Generate smart search filters for a product using Gemini 2.5 Flash Lite.
 * Uses a separate model from the image-analysis service so they don't share quota.
 *
 * @param {object}      tags        - Product tags: { productName, category, color, material, style, searchQuery }
 * @param {string|null} transcript  - Optional voice transcript from the user
 * @returns {Promise<Array>}        - Array of filter objects
 */
async function generateFilters(tags, transcript) {
  const model = genAI.getGenerativeModel(
    { model: 'gemini-2.5-flash-lite' },
    { generationConfig: { responseMimeType: 'application/json' } }
  );

  const contextLines = [
    FILTER_PROMPT,
    '',
    `Product: "${tags.productName ?? 'Unknown product'}"`,
    `Category: "${tags.category ?? 'General'}"`,
    tags.color ? `Detected color: "${tags.color}"` : null,
    tags.material ? `Detected material: "${tags.material}"` : null,
    tags.style ? `Detected style: "${tags.style}"` : null,
    transcript ? `User said: "${transcript}"` : null,
  ].filter(Boolean).join('\n');

  const result = await model.generateContent(contextLines);
  const raw = result.response.text().trim()
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '');

  return JSON.parse(raw);
}

module.exports = { generateFilters };
