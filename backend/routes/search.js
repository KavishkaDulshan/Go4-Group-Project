'use strict';
const express = require('express');
const fs = require('fs');
const { analyzeImage } = require('../services/geminiService');
const { searchShopping } = require('../services/serperService');
const { transcribeAudio } = require('../services/transcriptionService');
const SearchHistory = require('../models/SearchHistory');
const { learnFromSearch } = require('../services/preferenceLearningService');

const router = express.Router();

/**
 * Determine image MIME type from a Multer file object.
 */
function resolveMimeType(file) {
  if (file.mimetype && file.mimetype.startsWith('image/')) return file.mimetype;
  const ext = (file.originalname?.split('.').pop() ?? 'jpg').toLowerCase();
  const map = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', gif: 'image/gif' };
  return map[ext] ?? 'image/jpeg';
}

/**
 * POST /api/v1/search
 *
 * multipart/form-data:
 *   image      (file, optional)   – product photo
 *   audio      (file, optional)   – voice recording (m4a / mp3 / wav)
 *   query      (string, optional) – plain-text fallback
 *   transcript (string, optional) – pre-transcribed voice text (skips Groq call)
 *   sessionId  (string, optional) – anonymous session token
 *
 * Processing order:
 *   1. If audio + no transcript → Groq Whisper → transcript
 *   2. If image → Gemini vision analysis (transcript used as voice hint)
 *   3. If no image  → text-only search using transcript
 *   4. Serper Google Shopping search
 *   5. Save to MongoDB
 *
 * Response 200:
 * { searchId, tags: { productName, category, color, material, style, searchQuery },
 *   results: [{ title, price, link, thumbnail, source, rating, ratingCount }] }
 */
router.post('/', async (req, res, next) => {
  const t0 = Date.now();
  const imageFile = req.files?.image?.[0] ?? null;
  const audioFile = req.files?.audio?.[0] ?? null;
  const { query, sessionId } = req.body;
  let { transcript } = req.body;

  console.log(
    `[Search] ▶  image=${imageFile ? `${imageFile.originalname} (${(imageFile.size/1024).toFixed(1)}KB)` : 'none'}` +
    `  audio=${audioFile ? `${audioFile.originalname} (${(audioFile.size/1024).toFixed(1)}KB)` : 'none'}` +
    `  query="${query ?? ''}"  session=${sessionId ?? 'anon'}`
  );

  if (!imageFile && !audioFile && !query) {
    return res.status(400).json({ error: 'Provide at least one of: image, audio, or query.' });
  }

  const tempFiles = [imageFile?.path, audioFile?.path].filter(Boolean);
  const cleanup = () => {
    tempFiles.forEach((p) => {
      try { fs.unlinkSync(p); } catch (_) { }
    });
  };

  try {
    // ── Step 1: Transcribe audio via Groq Whisper ────────────────────────────
    if (audioFile && !transcript) {
      console.log(`[Search] Groq Whisper → transcribing ${audioFile.originalname}…`);
      try {
        transcript = await transcribeAudio(audioFile.path);
        console.log(`[Search] Groq Whisper ✅  "${transcript}"`);
      } catch (transcribeErr) {
        console.warn(`[Search] Groq Whisper ⚠️  transcription failed (non-fatal): ${transcribeErr.message}`);
        transcript = query ?? '';
      }
    }

    // ── Step 2: Gemini image analysis OR text-only fallback ──────────────────
    let tags;

    if (imageFile) {
      const mimeType = resolveMimeType(imageFile);
      const voiceHint = transcript || null;
      console.log(`[Search] Gemini → analyzing ${mimeType} image${voiceHint ? ` with voice hint: "${voiceHint}"` : ''}`);
      tags = await analyzeImage(imageFile.path, mimeType, voiceHint);
      console.log(`[Search] Gemini ✅  tags: ${JSON.stringify(tags)}`);
    } else {
      const textQuery = transcript ?? query ?? '';
      console.log(`[Search] Voice/text-only → query="${textQuery}"`);
      tags = {
        productName: textQuery,
        category: null,
        color: null,
        material: null,
        style: null,
        searchQuery: textQuery,
      };
    }

    // ── Step 3: Guard against empty search query ─────────────────────────────
    const searchQuery = (tags.searchQuery ?? tags.productName ?? '').trim();
    if (!searchQuery) {
      cleanup();
      return res.status(400).json({
        error: 'Could not determine a search query. Please speak clearly or take a clearer photo.',
      });
    }

    // ── Step 3b: Optional city/country hint → Serper gl + location ──────────
    // Scans the raw user input for well-known city names to bias results
    // toward a regional Google Shopping index.  Does not restrict results
    // to local websites — the Shopping API is always used globally.
    const rawInput = (transcript ?? query ?? '').toLowerCase();

    let searchGl = 'us';
    let searchLocation = '';

    const CITY_GL = {
      colombo:   { gl: 'lk', location: 'Colombo, Sri Lanka' },
      kandy:     { gl: 'lk', location: 'Kandy, Sri Lanka' },
      delhi:     { gl: 'in', location: 'New Delhi, India' },
      mumbai:    { gl: 'in', location: 'Mumbai, India' },
      bangalore: { gl: 'in', location: 'Bangalore, India' },
      london:    { gl: 'gb', location: 'London, United Kingdom' },
      dubai:     { gl: 'ae', location: 'Dubai, UAE' },
      sydney:    { gl: 'au', location: 'Sydney, Australia' },
      toronto:   { gl: 'ca', location: 'Toronto, Canada' },
      singapore: { gl: 'sg', location: 'Singapore' },
      bangkok:   { gl: 'th', location: 'Bangkok, Thailand' },
    };
    for (const [city, info] of Object.entries(CITY_GL)) {
      if (rawInput.includes(city)) {
        searchGl       = info.gl;
        searchLocation = info.location;
        break;
      }
    }

    const serperOpts = {
      gl: searchGl,
      ...(searchLocation && { location: searchLocation }),
    };
    if (searchLocation) {
      console.log(`[Search] City hint → gl="${searchGl}" location="${searchLocation}"`);
    }

    // ── Step 4: Google Shopping via Serper ───────────────────────────────────
    console.log(`[Search] Shopping → "${searchQuery}"`);
    const results = await searchShopping(searchQuery, serperOpts);
    console.log(`[Search] Serper ✅  ${results.length} result(s)`);

    // ── Step 5: Persist to MongoDB ───────────────────────────────────────────
    let searchId = null;
    try {
      const doc = await SearchHistory.create({
        userId: req.user?.sub ? new (require('mongoose').Types.ObjectId)(req.user.sub) : undefined,
        sessionId: sessionId ?? undefined,
        tags,
        results,
        imagePath: imageFile?.filename ?? undefined,
        transcript: transcript ?? undefined,
      });
      searchId = doc._id.toString();
      console.log(`[Search] DB ✅  saved → ${searchId}`);
    } catch (dbErr) {
      console.warn('[Search] DB ⚠️  history save failed (non-fatal):', dbErr.message);
    }

    // ── Step 6: Learn from this search (non-blocking, errors swallowed) ──────
    if (req.user?.sub) {
      learnFromSearch(req.user.sub, tags, results).catch(() => {});
    }

    cleanup();
    console.log(`[Search] ✅  done in ${Date.now() - t0}ms  searchId=${searchId}`);
    return res.json({ searchId, tags, results });

  } catch (err) {
    cleanup();
    console.error(`[Search] ❌  ${err.message}  (${Date.now() - t0}ms)`);
    next(err);
  }
});

module.exports = router;
