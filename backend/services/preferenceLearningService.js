'use strict';
const UserPreferences = require('../models/UserPreferences');

const MAX_ENTRIES = 15; // Keep only the top-N values per preference dimension

/**
 * Upsert 'value' into an entries array.
 * If found, increment count + update lastSeen.
 * If not found, push a new entry.
 * Always trims to MAX_ENTRIES sorted by count (desc).
 *
 * @param {Array}  arr   Existing preference entries
 * @param {string} value Raw value to record
 * @returns {Array}
 */
function upsertEntry(arr, value) {
  if (!value || typeof value !== 'string') return arr;
  const normalized = value.trim().toLowerCase();
  if (!normalized) return arr;

  const copy = [...arr];
  const idx = copy.findIndex((e) => e.value === normalized);
  if (idx >= 0) {
    copy[idx] = { ...copy[idx], count: copy[idx].count + 1, lastSeen: new Date() };
  } else {
    copy.push({ value: normalized, count: 1, lastSeen: new Date() });
  }

  copy.sort((a, b) => b.count - a.count);
  return copy.slice(0, MAX_ENTRIES);
}

/**
 * Parse a price string like "$29.99" or "LKR 1,500" into a float.
 * Returns null if unparseable.
 *
 * @param {string|null} priceStr
 * @returns {number|null}
 */
function parsePrice(priceStr) {
  if (!priceStr || typeof priceStr !== 'string') return null;
  const n = parseFloat(priceStr.replace(/[^0-9.]/g, ''));
  return isNaN(n) ? null : n;
}

/**
 * Learn user preferences from a completed search.
 * Safe to call without await — errors are swallowed.
 *
 * @param {string} userId  MongoDB ObjectId string (req.user.sub)
 * @param {object} tags    { productName, category, color, material, style }
 * @param {Array}  results Array of product objects (from Serper)
 */
async function learnFromSearch(userId, tags, results) {
  if (!userId) return;

  try {
    let doc = await UserPreferences.findOne({ userId });
    if (!doc) doc = new UserPreferences({ userId });

    doc.searchCount = (doc.searchCount || 0) + 1;

    if (tags.category) doc.categories = upsertEntry(doc.categories.toObject?.() ?? doc.categories, tags.category);
    if (tags.material) doc.materials = upsertEntry(doc.materials.toObject?.() ?? doc.materials, tags.material);
    if (tags.style) doc.styles = upsertEntry(doc.styles.toObject?.() ?? doc.styles, tags.style);
    if (tags.color) doc.colors = upsertEntry(doc.colors.toObject?.() ?? doc.colors, tags.color);

    // Learn price range from results
    const prices = (results ?? [])
      .map((r) => parsePrice(r.price))
      .filter((p) => p !== null);

    if (prices.length > 0) {
      const minP = Math.min(...prices);
      const maxP = Math.max(...prices);
      const sum = prices.reduce((a, b) => a + b, 0);
      const pr = doc.priceRange;

      pr.count = (pr.count || 0) + prices.length;
      pr.total = (pr.total || 0) + sum;
      pr.avg = pr.total / pr.count;
      pr.min = pr.min !== null && pr.min !== undefined ? Math.min(pr.min, minP) : minP;
      pr.max = pr.max !== null && pr.max !== undefined ? Math.max(pr.max, maxP) : maxP;
    }

    doc.lastUpdated = new Date();
    doc.markModified('categories');
    doc.markModified('materials');
    doc.markModified('styles');
    doc.markModified('colors');
    doc.markModified('priceRange');

    await doc.save();
    console.log(`[Prefs] ✅  Updated preferences for user ${userId} (${doc.searchCount} searches)`);
  } catch (err) {
    console.warn(`[Prefs] ⚠️  Failed to learn from search: ${err.message}`);
  }
}

/**
 * Return the user's top preferences as a Serper search bias string.
 * Returns null if user is anonymous or hasn't searched enough.
 *
 * @param {string} userId  MongoDB ObjectId string
 * @returns {Promise<string|null>}
 */
async function getPreferenceBias(userId) {
  if (!userId) return null;
  try {
    const doc = await UserPreferences.findOne({ userId }).lean();
    if (!doc || doc.searchCount < 3) return null;

    const parts = [];
    if (doc.materials?.length > 0) parts.push(doc.materials[0].value);
    if (doc.styles?.length > 0) parts.push(doc.styles[0].value);
    if (doc.categories?.length > 0) parts.push(doc.categories[0].value);

    return parts.length > 0 ? parts.join(' ') : null;
  } catch (_) {
    return null;
  }
}

/**
 * Fetch the full preference profile for a user.
 *
 * @param {string} userId  MongoDB ObjectId string
 * @returns {Promise<object|null>}
 */
async function getUserPreferences(userId) {
  if (!userId) return null;
  try {
    return await UserPreferences.findOne({ userId }).lean();
  } catch (_) {
    return null;
  }
}

module.exports = { learnFromSearch, getPreferenceBias, getUserPreferences };
