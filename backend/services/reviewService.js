'use strict';
const axios = require('axios');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// ─── Serper web search ────────────────────────────────────────────────────────

/**
 * Fetch review snippets from organic web search results using Serper.
 * Targets review-rich sources: Reddit, Amazon, YouTube, CNET, Trustpilot, forums.
 *
 * @param {string} title    - Product title
 * @param {string} category - Product category (used to build a smarter query)
 * @returns {Promise<Array<{source, title, link, snippet}>>}
 */
async function fetchReviewSnippets(title, category) {
  // Build a targeted query that pulls from review-heavy sites
  const query = `${title} review reddit OR amazon OR trustpilot OR cnet OR gsmarena OR notebookcheck OR rtings`;

  const response = await axios.post(
    'https://google.serper.dev/search',
    { q: query, gl: 'us', hl: 'en', num: 10 },
    {
      headers: {
        'X-API-KEY': process.env.SERPER_API_KEY,
        'Content-Type': 'application/json',
      },
      timeout: 12_000,
    }
  );

  const organic = response.data?.organic ?? [];
  const snippets = organic
    .filter((item) => item.snippet && item.snippet.length > 40)
    .map((item) => ({
      source: _extractDomain(item.link),
      title: item.title ?? '',
      link: item.link ?? null,
      snippet: item.snippet ?? '',
    }));

  console.log(`[Reviews] Serper returned ${snippets.length} organic snippets for "${title.slice(0, 50)}"`);
  return snippets;
}

function _extractDomain(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return 'Unknown source';
  }
}

// ─── Gemini analysis ──────────────────────────────────────────────────────────

const REVIEW_PROMPT = `You are an expert product analyst. You have been given a list of review snippets about a product collected from the web. Analyze them and return a detailed JSON object.

The JSON must have exactly these fields:
{
  "aiRating": number (1.0 to 5.0, one decimal),
  "satisfactionPercent": integer (0-100, represents overall buyer satisfaction),
  "summary": "3-4 sentence analysis of overall buyer sentiment and product quality",
  "verdict": "one bold sentence conclusion about whether to buy this product",
  "pros": ["string"],
  "cons": ["string"],
  "sentimentLabel": "Highly Positive | Mostly Positive | Mixed | Mostly Negative | Highly Negative"
}

Rules:
- "pros": 3-5 specific positive points mentioned by buyers
- "cons": 2-4 specific negative points or complaints from buyers
- "aiRating": derive from satisfactionPercent (100% = 5.0, 80% = 4.0, 60% = 3.0, etc.)
- "verdict": be direct and honest — do not hedge
- Base analysis ONLY on the provided snippets, not general knowledge

Return ONLY valid JSON. No markdown, no prose.`;

/**
 * Use Gemini to analyse review snippets for a product.
 *
 * @param {string} title              - Product title
 * @param {string} category           - Product category
 * @param {Array}  snippets           - From fetchReviewSnippets()
 * @returns {Promise<object>} Analysis object
 */
async function analyzeReviews(title, category, snippets) {
  const model = genAI.getGenerativeModel(
    { model: 'gemini-2.5-flash' },
    { generationConfig: { responseMimeType: 'application/json' } }
  );

  const snippetsText = snippets
    .map((s, i) => `[${i + 1}] Source: ${s.source}\nTitle: ${s.title}\nReview: ${s.snippet}`)
    .join('\n\n');

  const prompt = [
    REVIEW_PROMPT,
    '',
    `Product: "${title}"`,
    `Category: "${category ?? 'General'}"`,
    '',
    'Review snippets:',
    snippetsText,
  ].join('\n');

  const result = await model.generateContent(prompt);
  const raw = result.response.text().trim()
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '');

  return JSON.parse(raw);
}

// ─── Orchestrator ─────────────────────────────────────────────────────────────

/**
 * Full pipeline: search → analyse → return combined result.
 *
 * @returns {Promise<{snippets, analysis}>}
 */
async function getProductReviews(title, category) {
  const snippets = await fetchReviewSnippets(title, category);

  if (snippets.length === 0) {
    return {
      snippets: [],
      analysis: {
        aiRating: null,
        satisfactionPercent: null,
        summary: 'No review data could be found for this product.',
        verdict: 'Insufficient data to provide a recommendation.',
        pros: [],
        cons: [],
        sentimentLabel: 'Mixed',
      },
    };
  }

  const analysis = await analyzeReviews(title, category, snippets);
  return { snippets, analysis };
}

module.exports = { getProductReviews };
