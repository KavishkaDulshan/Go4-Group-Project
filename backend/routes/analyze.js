'use strict';
const express = require('express');
const fs = require('fs');
const { analyzeImage } = require('../services/geminiService');
const { transcribeAudio } = require('../services/transcriptionService');
const { generateFilters } = require('../services/geminiFilterService');

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
 * POST /api/v1/search/analyze
 *
 * Same multipart/form-data fields as POST /api/v1/search:
 *   image      (file, optional)   – product photo
 *   audio      (file, optional)   – voice recording
 *   query      (string, optional) – plain-text fallback
 *   transcript (string, optional) – pre-transcribed voice text
 *
 * Does NOT call Serper.  Returns Gemini tags + AI-generated smart filters.
 *
 * Response 200: { tags, filters }
 *   tags    – { productName, category, color, material, style, searchQuery }
 *   filters – [{ key, label, type, options: [{value, label}], defaultValue }]
 */
router.post('/', async (req, res, next) => {
  const t0 = Date.now();
  const imageFile = req.files?.image?.[0] ?? null;
  const audioFile = req.files?.audio?.[0] ?? null;
  const { query } = req.body;
  let { transcript } = req.body;

  console.log(
    `[Analyze] ▶  image=${imageFile ? imageFile.originalname : 'none'}` +
    `  audio=${audioFile ? audioFile.originalname : 'none'}` +
    `  query="${query ?? ''}"`
  );

  if (!imageFile && !audioFile && !query) {
    return res.status(400).json({ error: 'Provide at least one of: image, audio, or query.' });
  }

  const tempFiles = [imageFile?.path, audioFile?.path].filter(Boolean);
  const cleanup = () => tempFiles.forEach((p) => {
    try { fs.unlinkSync(p); } catch (_) { }
  });

  try {
    // ── Step 1: Transcribe audio ────────────────────────────────────────────
    if (audioFile && !transcript) {
      console.log(`[Analyze] Groq Whisper → transcribing ${audioFile.originalname}…`);
      try {
        transcript = await transcribeAudio(audioFile.path);
        console.log(`[Analyze] Groq Whisper ✅  "${transcript}"`);
      } catch (e) {
        console.warn(`[Analyze] Groq Whisper ⚠️  failed (non-fatal): ${e.message}`);
        transcript = query ?? '';
      }
    }

    // ── Step 2: Extract product tags ────────────────────────────────────────
    let tags;
    if (imageFile) {
      const mimeType = resolveMimeType(imageFile);
      const voiceHint = transcript || null;
      tags = await analyzeImage(imageFile.path, mimeType, voiceHint);
      console.log(`[Analyze] Gemini vision ✅  tags: ${JSON.stringify(tags)}`);
    } else {
      const textQuery = transcript ?? query ?? '';
      tags = {
        productName: textQuery,
        category: null,
        color: null,
        material: null,
        style: null,
        searchQuery: textQuery,
      };
    }

    // ── Step 3: Generate smart filters (non-fatal) ─────────────────────────
    let filters = [];
    try {
      filters = await generateFilters(tags, transcript ?? null);
      console.log(`[Analyze] Filters ✅  ${filters.length} filter(s) in ${Date.now() - t0}ms`);
    } catch (filterErr) {
      console.warn(`[Analyze] Filters ⚠️  generation failed (non-fatal): ${filterErr.message}`);
    }

    cleanup();
    return res.json({ tags, filters });

  } catch (err) {
    cleanup();
    console.error(`[Analyze] ❌  ${err.message}  (${Date.now() - t0}ms)`);
    next(err);
  }
});

module.exports = router;
