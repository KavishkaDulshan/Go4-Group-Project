'use strict';
const mongoose = require('mongoose');

//gg  testA single preference entry, e.g. { value: 'cotton', count: 4 }
const preferenceEntrySchema = new mongoose.Schema(
  {
    value: { type: String, required: true },
    count: { type: Number, default: 1 },
    lastSeen: { type: Date, default: Date.now },
  },
  { _id: false }
);

const priceRangeSchema = new mongoose.Schema(
  {
    min: { type: Number, default: null },
    max: { type: Number, default: null },
    avg: { type: Number, default: null },
    total: { type: Number, default: 0 },
    count: { type: Number, default: 0 },
  },
  { _id: false }
);

const userPreferencesSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
      index: true,
    },
    categories: [preferenceEntrySchema],
    materials: [preferenceEntrySchema],
    styles: [preferenceEntrySchema],
    colors: [preferenceEntrySchema],
    priceRange: { type: priceRangeSchema, default: () => ({}) },
    searchCount: { type: Number, default: 0 },
    lastUpdated: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('UserPreferences', userPreferencesSchema);
