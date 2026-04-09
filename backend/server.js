'use strict';
require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// ─── Route modules ───────────────────────────────────────────────────────────
const searchRouter          = require('./routes/search');
const analyzeRouter         = require('./routes/analyze');
const authRouter            = require('./routes/auth');
const historyRouter         = require('./routes/history');
const placesRouter          = require('./routes/places');
const productRouter         = require('./routes/product');
const recommendationsRouter = require('./routes/recommendations');

// ─── Middleware ──────────────────────────────────────────────────────────────
const authMiddleware = require('./middleware/auth');

// ─── App ─────────────────────────────────────────────────────────────────────
const app = express();
const PORT = process.env.PORT || 3000;

// ─── Ensure upload directory exists ────────────────────────────────────────
const UPLOAD_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

// Verify the directory is actually writable at startup so permission errors
// surface immediately with a clear message rather than on the first request.
try {
  fs.accessSync(UPLOAD_DIR, fs.constants.W_OK);
  console.log(`[Server] 📂  Upload dir writable → ${UPLOAD_DIR}`);
} catch (_) {
  console.error(`[Server] ❌  Upload dir NOT writable → ${UPLOAD_DIR}`);
  console.error('[Server]    Fix: rebuild Docker with "docker-compose down -v && docker-compose up --build -d"');
}

// ─── Multer (multimodal file uploads) ───────────────────────────────────────
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
  filename: (_req, file, cb) => {
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${unique}${path.extname(file.originalname)}`);
  },
});

const fileFilter = (_req, file, cb) => {
  // Accept any image or audio MIME type.
  // Android (and iOS) often tags .m4a recordings as "audio/mp4" — a string-fragment
  // regex on the MIME would miss that, so we use category prefix matching instead.
  const isImage = file.mimetype.startsWith('image/');
  const isAudio = file.mimetype.startsWith('audio/');
  if (isImage || isAudio) return cb(null, true);
  cb(new Error(
    `Unsupported file type: ${file.mimetype} (${path.extname(file.originalname)}) – ` +
    'only image/* and audio/* are accepted'
  ));
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 20 * 1024 * 1024 }, // 20 MB cap
});

// ─── Request logger ──────────────────────────────────────────────────────────
app.use((req, res, next) => {
  const start = Date.now();
  const ct = (req.headers['content-type'] ?? '-').split(';')[0].trim();
  console.log(`[Req] ▶  ${req.method} ${req.path}  ct=${ct}`);
  res.on('finish', () => {
    const ms = Date.now() - start;
    const icon = res.statusCode < 400 ? '✅' : '❌';
    console.log(`[Req] ${icon}  ${req.method} ${req.path} → ${res.statusCode}  (${ms}ms)`);
  });
  next();
});

// ─── Core Middleware ─────────────────────────────────────────────────────────
app.use(cors({
  origin: '*', // tighten in production
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// ─── MongoDB Atlas Connection ────────────────────────────────────────────────
const connectDB = async () => {
  const uri = process.env.ATLAS_URI;
  if (!uri) {
    console.error('[DB] ATLAS_URI is not defined in .env – aborting.');
    process.exit(1);
  }

  try {
    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 8000,
      socketTimeoutMS: 45000,
    });
    console.log('[DB] ✅  Connected to MongoDB Atlas');
  } catch (err) {
    console.error('[DB] ❌  Atlas connection failed:', err.message);
    process.exit(1);
  }
};

mongoose.connection.on('disconnected', () =>
  console.warn('[DB] ⚠️  Atlas disconnected – attempting reconnect…')
);
mongoose.connection.on('reconnected', () =>
  console.log('[DB] ✅  Atlas reconnected')
);

// ─── Routes ──────────────────────────────────────────────────────────────────

// Health-check (no auth required)
app.get('/api/v1/health', (_req, res) => {
  const dbState = ['disconnected', 'connected', 'connecting', 'disconnecting'];
  res.json({
    status: 'ok',
    service: 'go4-backend',
    db: dbState[mongoose.connection.readyState] ?? 'unknown',
    uptime: process.uptime().toFixed(1) + 's',
    ts: new Date().toISOString(),
  });
});

// Multimodal search — Multer then soft-auth (so signed-in users get their userId saved)
app.use(
  '/api/v1/search',
  upload.fields([
    { name: 'image', maxCount: 1 },
    { name: 'audio', maxCount: 1 },
  ]),
  authMiddleware,
  searchRouter
);

// Analyze inputs → tags + smart filters (no Serper call)
app.use(
  '/api/v1/analyze',
  upload.fields([
    { name: 'image', maxCount: 1 },
    { name: 'audio', maxCount: 1 },
  ]),
  analyzeRouter
);

// Authentication
app.use('/api/v1/auth', authRouter);

// Search history (soft auth: works for signed-in users and anonymous sessions)
app.use('/api/v1/history', authMiddleware, historyRouter);

// Nearby places (Google Places Text Search, no auth required)
app.use('/api/v1/places', placesRouter);

// Product enrichment (Gemini-powered specs/description, no auth required)
app.use('/api/v1/product', productRouter);

// Personalised recommendations + preference profile (requires auth)
app.use('/api/v1/recommendations', authMiddleware, recommendationsRouter);

// 404 fallback
app.use((_req, res) => res.status(404).json({ error: 'Route not found' }));

// Global error handler
app.use((err, req, res, _next) => {
  const status = err.status ?? 500;
  console.error(`[Error] ${req.method} ${req.path} → ${status}: ${err.message}`);
  if (process.env.NODE_ENV !== 'production') console.error(err.stack);
  res.status(status).json({ error: err.message ?? 'Internal server error' });
});

// ─── Bootstrap ──────────────────────────────────────────────────────────────
(async () => {
  await connectDB();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[Server] 🚀  go4-backend listening on port ${PORT}`);
    console.log(`[Server]    Health → http://localhost:${PORT}/api/v1/health`);
    console.log(`[Server]    Search → POST http://localhost:${PORT}/api/v1/search`);
    console.log(`[Server]    Auth   → POST http://localhost:${PORT}/api/v1/auth/google`);
  });
})();
