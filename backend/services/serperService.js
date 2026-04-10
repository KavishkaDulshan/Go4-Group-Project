'use strict';
const axios = require('axios');

const SHOPPING_ENDPOINT = 'https://google.serper.dev/shopping';
const IMAGE_ENDPOINT    = 'https://google.serper.dev/images';

// ── Image-URL helpers (module-scoped so both functions share them) ────────────
const isBase64 = (url) => typeof url === 'string' && url.startsWith('data:');
const safeUrl  = (url) => (isBase64(url) ? null : (url ?? null));
const logUrl   = (url) =>
  isBase64(url)
    ? `[base64-img ~${Math.round(url.length / 1024)}KB]`
    : (url ?? '(none)');

/**
 * Fetch a single product image URL from Serper image search.
 * Used to back-fill thumbnails that Google Shopping didn't provide.
 *
 * @param {string} title  Product title used as the image query.
 * @returns {Promise<string|null>}
 */
async function fetchImageForTitle(title) {
  try {
    const res = await axios.post(
      IMAGE_ENDPOINT,
      { q: title, num: 3 },
      {
        headers: {
          'X-API-KEY':    process.env.SERPER_API_KEY,
          'Content-Type': 'application/json',
        },
        timeout: 6_000,
      }
    );
    const images = res.data?.images ?? [];
    for (const img of images) {
      const url = safeUrl(img.imageUrl) ?? safeUrl(img.thumbnailUrl);
      if (url) return url;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/**
 * Query Google Shopping via Serper.dev.
 * Products that lack a thumbnail are automatically enriched via a secondary
 * Serper image-search call (batched, max 5 concurrent requests).
 *
 * @param {string} searchQuery - Product search query.
 * @param {object} opts
 * @param {string} [opts.gl='us']       Country code (e.g. 'lk', 'in', 'gb').
 * @param {string} [opts.hl='en']       Language.
 * @param {number} [opts.num=40]        Max results to request.
 * @param {string} [opts.location]      City/region string for localised results.
 * @returns {Promise<Array>} Normalised product list
 */
async function searchShopping(searchQuery, { gl = 'us', hl = 'en', num = 40, location } = {}) {
  const body = { q: searchQuery, gl, hl, num };
  if (location) body.location = location;

  const response = await axios.post(
    SHOPPING_ENDPOINT,
    body,
    {
      headers: {
        'X-API-KEY':    process.env.SERPER_API_KEY,
        'Content-Type': 'application/json',
      },
      timeout: 12_000,
    }
  );

  const shopping = response.data?.shopping ?? [];

  // Log a compact summary of the first raw item for diagnostics
  if (shopping.length > 0) {
    const sample = shopping[0];
    console.log('[Serper] Fields from first result:', Object.keys(sample).join(', '));
    console.log('[Serper] imageUrl:', logUrl(sample.imageUrl));
    console.log('[Serper] thumbnail:', logUrl(sample.thumbnail));
  }

  const mapped = shopping.map((item) => {
    const imageUrl =
      safeUrl(item.imageUrl)
      ?? safeUrl(item.image)
      ?? safeUrl(item.thumbnailUrl)
      ?? null;

    const thumbnail = safeUrl(item.thumbnail) ?? imageUrl;

    const extensions = Array.isArray(item.extensions)
      ? item.extensions.filter((e) => typeof e === 'string')
      : [];

    return {
      title:         item.title         ?? 'Untitled',
      price:         item.price         ?? null,
      originalPrice: item.originalPrice ?? null,
      link:          item.link          ?? null,
      imageUrl,
      thumbnail,
      source:        item.source        ?? null,
      rating:        typeof item.rating      === 'number' ? item.rating      : null,
      ratingCount:   typeof item.ratingCount === 'number' ? item.ratingCount : null,
      delivery:      item.delivery      ?? item.shippingPrice ?? null,
      offers:        typeof item.offers === 'number' ? item.offers : null,
      extensions,
    };
  });

  // Sort: items with a valid image first
  const sorted = [...mapped].sort((a, b) => {
    if (a.thumbnail && !b.thumbnail) return -1;
    if (!a.thumbnail && b.thumbnail) return 1;
    return 0;
  });

  const withImgBefore = sorted.filter((i) => i.thumbnail).length;
  console.log(`[Serper] ${sorted.length} results, ${withImgBefore} with image from Shopping API`);

  // ── Thumbnail enrichment ────────────────────────────────────────────────────
  // Products without a thumbnail get a fallback image from Serper image search.
  // We process them in batches of 5 to keep concurrent requests manageable.
  const missing = sorted.filter((i) => !i.thumbnail);
  if (missing.length > 0) {
    console.log(`[Serper] Enriching ${missing.length} products with image search…`);
    const BATCH_SIZE = 5;
    for (let i = 0; i < missing.length; i += BATCH_SIZE) {
      const batch = missing.slice(i, i + BATCH_SIZE);
      await Promise.all(
        batch.map(async (item) => {
          const url = await fetchImageForTitle(item.title);
          if (url) {
            item.thumbnail = url;
            if (!item.imageUrl) item.imageUrl = url;
          }
        })
      );
    }
    const withImgAfter = sorted.filter((i) => i.thumbnail).length;
    console.log(`[Serper] After enrichment: ${withImgAfter} / ${sorted.length} have image (+${withImgAfter - withImgBefore})`);
  }

  return sorted;
}

module.exports = { searchShopping };
