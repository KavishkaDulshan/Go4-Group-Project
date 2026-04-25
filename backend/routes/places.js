'use strict';
const express = require('express');
const axios   = require('axios');

const router = express.Router();

const NEARBY_URL = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
const TEXT_URL   = 'https://maps.googleapis.com/maps/api/place/textsearch/json';

// ── Category → Search strategies ──────────────────────────────────────────────
//
// Each strategy: { type, keyword }
//   type    – a valid Google Places type for Nearby Search server-side filtering
//   keyword – additional hint sent alongside the type
//
// Design principles:
//   ① namehit() checks ONLY productName — higher trust than Gemini category.
//   ② hit()     checks combined cat+name — used when both signals agree.
//   ③ Niche / service categories are checked FIRST via namehit() so a wrong
//     Gemini category (e.g. "Electronics" for a mug) never misfires them.
//   ④ The broad electronics catch-all is guarded so it won't fire when the
//     product name clearly describes a non-electronic item.

function resolveStrategies(category, productName) {
  const cat     = (category    || '').toLowerCase().replace(/[_\-]/g, ' ').trim();
  const name    = (productName || '').toLowerCase().trim();
  const all     = `${cat} ${name}`;

  // Checks combined cat + name
  const hit     = (...terms) => terms.some((t) => all.includes(t));
  // Checks ONLY productName — higher priority, immune to wrong Gemini category
  const namehit = (...terms) => terms.some((t) => name.includes(t));

  // ── ① PRINT SHOP / CUSTOM PRINTING (checked first — highest mismatch risk) ─
  // Catches: "mug printing", "custom t-shirt print", "business cards", etc.
  // Gemini often categorises these as "Electronics" or "Office Supplies" wrongly.
  if (namehit('printing shop', 'print shop', 'custom print', 'bulk print',
              'mug printing', 'mug print', 'photo print', 'photo mug',
              't-shirt print', 'shirt print', 'screen print', 'sublimation',
              'heat transfer', 'banner printing', 'vinyl print', 'flex print',
              'id card print', 'business card print', 'visiting card',
              'brochure print', 'flyer print', 'poster print', 'sticker print',
              'canvas print', 'name plate', 'embroidery service', 'dtg print',
              'digital printing', 'offset printing', 'letterpress') ||
      hit('print service', 'copy center', 'print center', 'printing service',
          'xerox center', 'copy shop', 'print studio')) {
    return [
      { type: 'store',          keyword: 'custom printing shop printing services' },
      { type: 'store',          keyword: 'print shop commercial printing'          },
      { type: 'store',          keyword: 'custom gifts printing sublimation'       },
    ];
  }

  // ── ② CUSTOM GIFTS, MUGS & PERSONALISED ITEMS ────────────────────────────
  // Catches: "custom mug", "coffee mug", "travel mug", "personalised gift"
  if (namehit('custom mug', 'printed mug', 'personalised mug', 'personalized mug',
              'ceramic mug', 'travel mug', 'coffee mug', 'tea mug', 'photo mug',
              'custom gift', 'personalised gift', 'personalized gift',
              'gift hamper', 'gift basket', 'gift box', 'gift set',
              'souvenir', 'keepsake', 'memento', 'trophy', 'plaque', 'medal',
              'engraved gift', 'name engraving', 'photo frame gift') ||
      hit('gift shop', 'souvenir shop', 'gift store')) {
    return [
      { type: 'store',          keyword: 'gift shop personalised gifts souvenirs'  },
      { type: 'store',          keyword: 'custom gifts engraving trophy shop'      },
      { type: 'shopping_mall',  keyword: 'gift shop souvenirs'                     },
    ];
  }

  // ── ③ ART & CRAFT SUPPLIES ────────────────────────────────────────────────
  if (namehit('craft supply', 'craft kit', 'craft store', 'art supply',
              'paint brush', 'acrylic paint', 'oil paint', 'canvas board',
              'resin', 'epoxy resin', 'polymer clay', 'felt sheet',
              'embroidery hoop', 'cross stitch', 'crochet', 'knitting yarn',
              'scrapbook', 'origami', 'macrame', 'decoupage', 'lanyards',
              'glue gun', 'craft glue', 'foam sheet', 'thermocol') ||
      hit('hobby shop', 'craft shop')) {
    return [
      { type: 'store',          keyword: 'art craft supply hobby shop'             },
      { type: 'store',          keyword: 'art materials store paint brushes'       },
    ];
  }

  // ── ④ OFFICE & STATIONERY SERVICES ────────────────────────────────────────
  if (namehit('office supply', 'stationery', 'ink cartridge', 'printer ink',
              'printer toner', 'copier', 'binding', 'laminate', 'laminator',
              'a4 paper', 'file folder', 'binder', 'paper ream',
              'rubber band', 'sticky note', 'post-it', 'correction fluid',
              'stapler', 'paper clip', 'whiteboard marker', 'whiteboard') ||
      hit('stationery shop', 'office supply')) {
    return [
      { type: 'store',          keyword: 'stationery office supply shop'          },
      { type: 'book_store',     keyword: 'books stationery office supplies'       },
    ];
  }

  // ── ⑤ HOMEWARE, KITCHEN & DRINKWARE ──────────────────────────────────────
  if (namehit('mug', 'cup', 'tumbler', 'drinkware', 'flask', 'thermos',
              'water bottle', 'coffee cup', 'tea pot', 'kettle', 'jug',
              'serving tray', 'bowl', 'plate set', 'cutlery', 'dinner set',
              'kitchen storage', 'lunchbox', 'tiffin', 'container', 'jar')) {
    return [
      { type: 'home_goods_store', keyword: 'homeware kitchen gifts drinkware shop' },
      { type: 'department_store', keyword: 'kitchen accessories home store'        },
      { type: 'store',            keyword: 'home goods kitchenware shop'            },
    ];
  }

  // ── ⑥ BAKERY & CONFECTIONERY ──────────────────────────────────────────────
  if (namehit('cake', 'cupcake', 'pastry', 'bread', 'muffin', 'cookie',
              'donut', 'doughnut', 'croissant', 'macaron', 'brownie',
              'birthday cake', 'wedding cake', 'custom cake', 'fondant',
              'chocolate box', 'candy', 'sweet box', 'confectionery') ||
      hit('bakery', 'cake shop', 'sweet shop', 'patisserie')) {
    return [
      { type: 'bakery',         keyword: 'bakery cake shop pastry'                },
      { type: 'store',          keyword: 'confectionery sweet shop'                },
    ];
  }

  // ── ⑦ FLORIST & PLANTS ───────────────────────────────────────────────────
  if (namehit('flower', 'bouquet', 'floral', 'rose', 'orchid', 'tulip',
              'lily', 'sunflower', 'indoor plant', 'outdoor plant',
              'cactus', 'succulent', 'bonsai', 'potted plant', 'nursery plant',
              'planter', 'plant pot', 'monstera', 'fern', 'air plant') ||
      hit('flower shop', 'florist', 'plant nursery', 'garden center')) {
    return [
      { type: 'florist',        keyword: 'flower shop florist bouquet'             },
      { type: 'store',          keyword: 'plant nursery garden centre'             },
    ];
  }

  // ── ⑧ PARTY & EVENT SUPPLIES ─────────────────────────────────────────────
  if (namehit('party supply', 'party decor', 'balloon', 'party balloon',
              'streamer', 'confetti', 'party hat', 'birthday decoration',
              'wedding decoration', 'event supply', 'table decoration',
              'candle', 'birthday candle', 'centrepiece') ||
      hit('party shop', 'event store')) {
    return [
      { type: 'store',          keyword: 'party supplies events decoration shop'  },
      { type: 'shopping_mall',  keyword: 'party decorations balloons store'       },
    ];
  }

  // ── ⑨ TOOLS & HARDWARE ───────────────────────────────────────────────────
  if (namehit('hammer', 'drill', 'power drill', 'screwdriver', 'wrench',
              'tool set', 'toolbox', 'saw', 'measuring tape', 'level',
              'paint roller', 'wall paint', 'wood stain', 'sandpaper',
              'pipe', 'plumbing', 'electrical wire', 'conduit', 'fitting',
              'bolt', 'nail', 'screw set', 'anchor', 'power tool',
              'angle grinder', 'jigsaw tool', 'hardware') ||
      hit('hardware store', 'building supply')) {
    return [
      { type: 'hardware_store', keyword: 'hardware tools building materials shop' },
      { type: 'store',          keyword: 'hardware power tools DIY shop'          },
    ];
  }

  // ── ⑩ GARDENING & OUTDOOR ─────────────────────────────────────────────────
  if (namehit('garden', 'gardening', 'garden tool', 'hose pipe', 'sprinkler',
              'fertiliser', 'fertilizer', 'soil mix', 'compost', 'mulch',
              'seed', 'vegetable seed', 'plant food', 'lawn mower',
              'garden fork', 'trowel', 'rake', 'garden gloves') ||
      hit('garden centre', 'garden center', 'nursery')) {
    return [
      { type: 'store',          keyword: 'garden centre plants nursery outdoor'   },
      { type: 'hardware_store', keyword: 'garden tools outdoor supplies shop'     },
    ];
  }

  // ── ⑪ CANDLES, AROMATHERAPY & DIFFUSERS ──────────────────────────────────
  if (namehit('scented candle', 'aromatherapy', 'essential oil', 'diffuser',
              'wax melt', 'reed diffuser', 'incense stick', 'incense',
              'aroma lamp', 'potpourri') ||
      hit('candle shop', 'wellness shop')) {
    return [
      { type: 'store',          keyword: 'candles aromatherapy wellness gift shop' },
      { type: 'beauty_salon',   keyword: 'aromatherapy wellness accessories'       },
    ];
  }

  // ── ⑫ ART, FRAMES & GALLERY ──────────────────────────────────────────────
  if (namehit('photo frame', 'picture frame', 'wall art', 'wall hanging',
              'poster frame', 'canvas art', 'oil painting', 'artwork',
              'art print', 'painting', 'drawing supplies', 'sketch pad',
              'gallery', 'frame shop') ||
      hit('art gallery', 'frame shop')) {
    return [
      { type: 'art_gallery',    keyword: 'art gallery frame shop picture frames'  },
      { type: 'store',          keyword: 'art supplies frame store'                },
    ];
  }

  // ── ⑬ BABY & KIDS ─────────────────────────────────────────────────────────
  if (namehit('baby', 'infant', 'newborn', 'baby clothes', 'onesie',
              'baby toy', 'rattle', 'pram', 'stroller', 'baby monitor',
              'nappy', 'diaper', 'baby food', 'formula', 'pacifier',
              'sippy cup', 'baby bottle', 'baby gift') ||
      hit('baby shop', 'kids shop', "children's store")) {
    return [
      { type: 'store',          keyword: 'baby shop kids children products store' },
      { type: 'department_store', keyword: 'baby kids clothing toys accessories'  },
    ];
  }

  // ── ⑭ MOBILE PHONES & ACCESSORIES ────────────────────────────────────────
  if (hit('iphone', 'samsung', 'pixel', 'oneplus', 'xiaomi', 'redmi', 'oppo', 'vivo',
          'huawei', 'realme', 'motorola', 'nokia', 'smartphone', 'mobile phone',
          'phone case', 'phone cover', 'back cover', 'screen protector', 'phone charger',
          'charging cable', 'mobile charger', 'phone stand', 'sim card',
          'phone holder', 'phone accessory', 'mobile accessory')) {
    return [
      { type: 'electronics_store', keyword: 'mobile phone accessories store'     },
      { type: 'electronics_store', keyword: 'mobile phone shop'                  },
      { type: 'shopping_mall',     keyword: 'mobile phone accessories'           },
    ];
  }

  // ── ⑮ LAPTOPS & COMPUTERS ────────────────────────────────────────────────
  if (hit('laptop', 'notebook', 'macbook', 'chromebook', 'desktop computer',
          'hard disk', 'ssd', 'ram', 'graphics card', 'gpu', 'cpu', 'processor',
          'motherboard', 'computer mouse', 'keyboard', 'monitor', 'usb hub')) {
    return [
      { type: 'electronics_store', keyword: 'laptop computer store'              },
      { type: 'electronics_store', keyword: 'computer hardware shop'             },
      { type: 'shopping_mall',     keyword: 'computer laptop accessories'        },
    ];
  }

  // ── ⑯ AUDIO & HEADPHONES ─────────────────────────────────────────────────
  if (hit('headphone', 'earphone', 'earbuds', 'airpods', 'speaker', 'soundbar',
          'bluetooth speaker', 'neckband', 'wireless headset', 'wired headphone')) {
    return [
      { type: 'electronics_store', keyword: 'headphones audio electronics store' },
      { type: 'electronics_store', keyword: 'sound audio equipment shop'         },
    ];
  }

  // ── ⑰ CAMERAS & PHOTOGRAPHY ──────────────────────────────────────────────
  if (hit('camera', 'dslr', 'mirrorless', 'camera lens', 'tripod',
          'photography', 'action camera', 'gopro', 'webcam', 'memory card')) {
    return [
      { type: 'electronics_store', keyword: 'camera photography store'           },
      { type: 'electronics_store', keyword: 'camera accessories shop'            },
    ];
  }

  // ── ⑱ TELEVISIONS & DISPLAYS ─────────────────────────────────────────────
  if (hit('television', ' tv ', 'smart tv', 'oled', 'qled', 'projector', 'tv stand')) {
    return [
      { type: 'electronics_store', keyword: 'television display store'           },
      { type: 'electronics_store', keyword: 'home appliance electronics shop'    },
    ];
  }

  // ── ⑲ SMARTWATCHES & WEARABLES ───────────────────────────────────────────
  if (hit('smartwatch', 'fitness tracker', 'apple watch', 'galaxy watch',
          'fitbit', 'garmin', 'mi band', 'wearable')) {
    return [
      { type: 'electronics_store', keyword: 'smartwatch wearable store'          },
      { type: 'jewelry_store',     keyword: 'smartwatch accessories shop'         },
    ];
  }

  // ── ⑳ WRISTWATCHES (non-smart) ───────────────────────────────────────────
  if (hit('wristwatch', 'analog watch', 'quartz watch', 'luxury watch',
          'watch strap', 'watch band') && !hit('smartwatch', 'fitness tracker')) {
    return [
      { type: 'jewelry_store', keyword: 'wristwatch store'                       },
      { type: 'store',         keyword: 'watch shop'                              },
    ];
  }

  // ── ㉑ GAMING & CONSOLES ─────────────────────────────────────────────────
  if (hit('gaming', 'playstation', 'xbox', 'nintendo', 'switch',
          'game controller', 'gaming headset', 'gaming chair', 'video game')) {
    return [
      { type: 'electronics_store', keyword: 'video game console store'           },
      { type: 'store',             keyword: 'gaming accessories shop'             },
      { type: 'shopping_mall',     keyword: 'game store'                          },
    ];
  }

  // ── ㉒ GENERAL ELECTRONICS (catch-all — guarded against non-electronic names)
  // Only fires when category clearly indicates electronics AND the product name
  // is not a known non-electronic item (gifts, mugs, crafts, etc.).
  const isNonElectronicName = namehit(
    'mug', 'cup', 'print', 'craft', 'gift', 'souvenir', 'candle', 'flower',
    'plant', 'cake', 'bread', 'food', 'cloth', 'shirt', 'shoe', 'jewel',
    'ring', 'book', 'toy', 'pet', 'garden', 'hardware', 'tool', 'furniture'
  );
  if (!isNonElectronicName && hit('electronic', 'gadget', 'tech', 'device', 'appliance')) {
    return [
      { type: 'electronics_store', keyword: `${name || category} store`          },
      { type: 'shopping_mall',     keyword: 'electronics shop'                    },
    ];
  }

  // ── ㉓ SHOES & FOOTWEAR ───────────────────────────────────────────────────
  if (hit('shoes', 'sneakers', 'boots', 'slippers', 'sandals', 'loafers',
          'running shoe', 'sports shoe', 'footwear')) {
    return [
      { type: 'shoe_store',     keyword: productName || 'shoe footwear store'    },
      { type: 'clothing_store', keyword: 'shoes footwear accessories'             },
    ];
  }

  // ── ㉔ CLOTHING & FASHION ─────────────────────────────────────────────────
  if (hit('t-shirt', ' shirt', 'dress', 'jacket', 'coat', 'hoodie', 'sweater',
          'blouse', 'trouser', 'jeans', 'skirt', 'clothing', 'apparel',
          'fashion', 'outfit', 'kurta', 'saree', 'lehenga')) {
    return [
      { type: 'clothing_store',   keyword: productName || 'clothing apparel'     },
      { type: 'department_store', keyword: 'fashion store clothing'               },
    ];
  }

  // ── ㉕ TAILORING & ALTERATIONS ────────────────────────────────────────────
  if (namehit('tailor', 'alteration', 'sewing', 'stitching', 'custom suit',
              'fabric', 'textile', 'dressmaker', 'seamstress')) {
    return [
      { type: 'store',          keyword: 'tailor alterations clothing shop'      },
      { type: 'clothing_store', keyword: 'tailoring fabric store'                 },
    ];
  }

  // ── ㉖ JEWELRY ────────────────────────────────────────────────────────────
  if (hit('ring', 'necklace', 'bracelet', 'earring', 'pendant',
          'jewel', 'gold ', 'silver ', 'diamond', 'gemstone')) {
    return [
      { type: 'jewelry_store', keyword: productName || 'jewelry gold shop'       },
      { type: 'store',         keyword: 'gold silver jewelry store'               },
    ];
  }

  // ── ㉗ BAGS & LUGGAGE ─────────────────────────────────────────────────────
  if (hit('bag', 'handbag', 'backpack', 'purse', 'wallet', 'luggage',
          'suitcase', 'travel bag')) {
    return [
      { type: 'clothing_store',   keyword: 'bags accessories leather goods'      },
      { type: 'department_store', keyword: 'bags luggage travel accessories'     },
    ];
  }

  // ── ㉘ EYEWEAR ────────────────────────────────────────────────────────────
  if (hit('glasses', 'sunglasses', 'eyewear', 'optical', 'spectacle',
          'contact lens', 'reading glass')) {
    return [
      { type: 'store', keyword: 'optical eyewear glasses store'                  },
    ];
  }

  // ── ㉙ FURNITURE ──────────────────────────────────────────────────────────
  if (hit('sofa', 'couch', 'furniture', 'dining table', 'chair', 'wardrobe',
          'bookshelf', 'cabinet', 'desk', 'bed frame', 'closet')) {
    return [
      { type: 'furniture_store',  keyword: productName || 'furniture shop'       },
      { type: 'home_goods_store', keyword: 'furniture interior store'             },
    ];
  }

  // ── ㉚ KITCHEN APPLIANCES ─────────────────────────────────────────────────
  if (hit('frying pan', 'cookware', 'knife set', 'blender', 'toaster',
          'coffee maker', 'air fryer', 'rice cooker', 'oven', 'microwave',
          'refrigerator', 'washing machine', 'kitchen appliance', 'dishwasher')) {
    return [
      { type: 'home_goods_store', keyword: 'kitchen appliances store'            },
      { type: 'hardware_store',   keyword: 'home appliance shop'                  },
      { type: 'department_store', keyword: 'kitchen accessories store'            },
    ];
  }

  // ── ㉛ HOME DÉCOR & TEXTILES ──────────────────────────────────────────────
  if (hit('mattress', 'pillow', 'bedding', 'duvet', 'bed sheet', 'curtain',
          'rug', 'carpet', 'lamp', 'home decor', 'decoration', 'wallpaper', 'cushion')) {
    return [
      { type: 'home_goods_store', keyword: productName || 'home decor store'     },
      { type: 'department_store', keyword: 'home furnishing interior shop'        },
    ];
  }

  // ── ㉜ TOYS & GAMES ────────────────────────────────────────────────────────
  if (hit('toy', 'lego', 'puzzle', 'rubik', 'action figure', 'doll',
          'stuffed animal', 'board game', 'jigsaw', 'remote control car')) {
    return [
      { type: 'store',            keyword: 'toy children game shop'              },
      { type: 'department_store', keyword: 'toys games store'                     },
    ];
  }

  // ── ㉝ SPORTS & FITNESS ───────────────────────────────────────────────────
  if (hit('sport', 'fitness', 'yoga mat', 'dumbbell', 'gym equipment',
          'cycling', 'bicycle', 'cricket', 'football', 'basketball',
          'badminton', 'tennis', 'swimming', 'hiking', 'camping', 'trekking')) {
    return [
      { type: 'store',            keyword: 'sporting goods fitness equipment shop' },
      { type: 'department_store', keyword: 'sports accessories store'              },
    ];
  }

  // ── ㉞ BEAUTY & COSMETICS ─────────────────────────────────────────────────
  if (hit('lipstick', 'foundation', 'mascara', 'blush', 'eyeshadow', 'concealer',
          'skincare', 'moisturizer', 'serum', 'face wash', 'toner', 'sunscreen',
          'perfume', 'fragrance', 'cologne', 'cosmetic', 'makeup', 'beauty')) {
    return [
      { type: 'beauty_salon',     keyword: 'cosmetics beauty store'              },
      { type: 'store',            keyword: 'beauty products makeup shop'          },
      { type: 'department_store', keyword: 'beauty cosmetics counter'             },
    ];
  }

  // ── ㉟ PHARMACY & HEALTH ──────────────────────────────────────────────────
  if (hit('medicine', 'supplement', 'vitamin', 'protein powder', 'whey protein',
          'pharmacy', 'painkiller', 'antibiotic', 'first aid', 'health product')) {
    return [
      { type: 'pharmacy', keyword: productName || 'pharmacy chemist medical store' },
      { type: 'store',    keyword: 'health supplement nutrition shop'               },
    ];
  }

  // ── ㊱ BOOKS ─────────────────────────────────────────────────────────────
  if (hit('book', 'novel', 'textbook', 'notebook paper', 'printer cartridge')) {
    return [
      { type: 'book_store', keyword: productName || 'books stationery shop'      },
      { type: 'store',      keyword: 'books office supplies stationery'           },
    ];
  }

  // ── ㊲ PET SUPPLIES ───────────────────────────────────────────────────────
  if (hit('pet food', 'dog collar', 'cat litter', 'fish tank', 'aquarium',
          'bird cage', 'pet toy', 'pet bed', 'pet grooming', 'pet supply')) {
    return [
      { type: 'pet_store', keyword: productName || 'pet shop supplies'           },
    ];
  }

  // ── ㊳ MUSICAL INSTRUMENTS ────────────────────────────────────────────────
  if (hit('guitar', 'piano', 'keyboard instrument', 'drum', 'violin',
          'flute', 'ukulele', 'musical instrument')) {
    return [
      { type: 'store', keyword: 'musical instrument shop'                        },
    ];
  }

  // ── ㊴ AUTOMOTIVE ACCESSORIES ─────────────────────────────────────────────
  if (hit('tyre', 'tire ', 'car seat cover', 'car accessory', 'motor oil',
          'car part', 'car battery', 'wiper blade', 'dash cam', 'car charger',
          'automotive', 'vehicle part')) {
    return [
      { type: 'car_repair',  keyword: 'auto parts car accessories shop'          },
      { type: 'car_dealer',  keyword: 'automotive accessories store'              },
    ];
  }

  // ── ㊵ FOOD & GROCERY ─────────────────────────────────────────────────────
  if (hit('grocery', 'snack', 'food item', 'beverage', 'soft drink',
          'coffee bean', 'loose tea', 'chocolate bar', 'sauce', 'spice', 'cereal')) {
    return [
      { type: 'supermarket',       keyword: productName || 'grocery supermarket' },
      { type: 'convenience_store', keyword: 'grocery food shop'                   },
    ];
  }

  // ── ㊶ GENERIC FALLBACK ────────────────────────────────────────────────────
  // Use both the raw product name AND category as keyword, giving Google Places
  // maximum context.  Use Text Search (via type=establishment) to avoid the
  // strict type filter that causes misfires in the generic case.
  const kw = name || category || 'retail store';
  return [
    { type: 'establishment', keyword: `${kw} shop`                               },
    { type: 'store',         keyword: kw                                          },
    { type: 'shopping_mall', keyword: `${kw} store`                              },
  ];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function mergeUnique(existing, incoming) {
  const seen = new Set(existing.map((p) => p.placeId).filter(Boolean));
  for (const p of incoming) {
    if (p.placeId && !seen.has(p.placeId)) {
      seen.add(p.placeId);
      existing.push(p);
    }
  }
  return existing;
}

function toPlace(p) {
  return {
    placeId:          p.place_id                      ?? null,
    name:             p.name                          ?? 'Store',
    // nearbysearch returns `vicinity`, textsearch returns `formatted_address`
    address:          p.formatted_address ?? p.vicinity ?? '',
    lat:              p.geometry?.location?.lat         ?? null,
    lng:              p.geometry?.location?.lng         ?? null,
    rating:           p.rating                         ?? null,
    userRatingsTotal: p.user_ratings_total             ?? null,
    openNow:          p.opening_hours?.open_now        ?? null,
    types:            p.types                          ?? [],
  };
}

// ── GET /nearby ───────────────────────────────────────────────────────────────
/**
 * GET /api/v1/places/nearby
 *
 * Query params:
 *   category    {string}  – product category from Gemini (e.g. "Electronics")
 *   productName {string}  – product name from Gemini (e.g. "iPhone SE back cover")
 *   lat         {number}  – device latitude
 *   lng         {number}  – device longitude
 *
 * Strategy:
 *   1. resolveStrategies() maps category+productName → [{type, keyword}, ...]
 *      Product name is checked with higher priority via namehit() to avoid
 *      Gemini misclassification (e.g. "Electronics" for a mug printing shop).
 *   2. When location available: Nearby Search with type+keyword+rankby=distance.
 *   3. When no location: Text Search fallback.
 *   4. Merge unique results by placeId; return up to 20.
 */
router.get('/nearby', async (req, res, next) => {
  try {
    const { category = '', productName = '', lat, lng } = req.query;

    if (!category && !productName) {
      return res.status(400).json({ error: 'Provide at least one of: category, productName' });
    }

    const apiKey = process.env.GOOGLE_MAPS_SERVER_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'GOOGLE_MAPS_SERVER_KEY not configured' });
    }

    const strategies  = resolveStrategies(category, productName);
    const hasLocation = Boolean(lat && lng);
    let   allPlaces   = [];

    for (const { type, keyword } of strategies) {
      if (allPlaces.length >= 20) break;

      try {
        if (hasLocation) {
          // ── Nearby Search with type + rankby=distance ─────────────────────
          const { data } = await axios.get(NEARBY_URL, {
            params: {
              location: `${lat},${lng}`,
              rankby:   'distance',
              type,
              keyword,
              key:      apiKey,
            },
            timeout: 9_000,
          });

          if (data.status === 'OK' || data.status === 'ZERO_RESULTS') {
            const batch = (data.results ?? []).slice(0, 20).map(toPlace);
            mergeUnique(allPlaces, batch);
            console.log(
              `[Places/Nearby] type="${type}" keyword="${keyword}" → ` +
              `${batch.length} result(s) (total ${allPlaces.length})`
            );
          } else {
            console.warn(`[Places/Nearby] status=${data.status} type="${type}" keyword="${keyword}" – ${data.error_message ?? ''}`);
          }

        } else {
          // ── Text Search fallback when GPS unavailable ──────────────────────
          const { data } = await axios.get(TEXT_URL, {
            params: { query: keyword, key: apiKey },
            timeout: 9_000,
          });

          if (data.status === 'OK' || data.status === 'ZERO_RESULTS') {
            const batch = (data.results ?? []).slice(0, 20).map(toPlace);
            mergeUnique(allPlaces, batch);
            console.log(`[Places/Text] keyword="${keyword}" → ${batch.length} result(s)`);
          } else {
            console.warn(`[Places/Text] status=${data.status} for "${keyword}"`);
          }
        }

      } catch (stratErr) {
        console.warn(
          `[Places] strategy {type=${type}, keyword="${keyword}"} ` +
          `error: ${stratErr.message}`
        );
      }
    }

    console.log(
      `[Places] Final: ${allPlaces.length} place(s) ` +
      `for category="${category}" product="${productName}"`
    );
    return res.json({ places: allPlaces.slice(0, 20) });

  } catch (err) {
    next(err);
  }
});

// ── GET /details ──────────────────────────────────────────────────────────────
/**
 * GET /api/v1/places/details
 *
 * Query params:
 *   placeId {string} – Google Places placeId
 *
 * Response 200: { openNow, weekdayText, phone, website, mapsUrl }
 */
router.get('/details', async (req, res, next) => {
  try {
    const { placeId } = req.query;

    if (!placeId) {
      return res.status(400).json({ error: 'placeId param is required' });
    }

    const apiKey = process.env.GOOGLE_MAPS_SERVER_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'GOOGLE_MAPS_SERVER_KEY not configured' });
    }

    const { data } = await axios.get(
      'https://maps.googleapis.com/maps/api/place/details/json',
      {
        params: {
          place_id: placeId,
          fields:   'opening_hours,formatted_phone_number,website,url',
          key:      apiKey,
        },
        timeout: 8_000,
      }
    );

    if (data.status !== 'OK') {
      console.warn(`[Places/Details] ${data.status} for ${placeId}`);
      return res.status(502).json({ error: `Places Details API: ${data.status}` });
    }

    const r = data.result ?? {};
    return res.json({
      openNow:     r.opening_hours?.open_now     ?? null,
      weekdayText: r.opening_hours?.weekday_text ?? [],
      phone:       r.formatted_phone_number      ?? null,
      website:     r.website                     ?? null,
      mapsUrl:     r.url                         ?? null,
    });

  } catch (err) {
    next(err);
  }
});

module.exports = router;
