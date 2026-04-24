'use strict';
const mongoose = require('mongoose');

const tagSchema = new mongoose.Schema(
  {
    productName: { type: String },
    category: { type: String },
    color: { type: String },
    material: { type: String },
    style: { type: String },
    searchQuery: { type: String },
  },
  { _id: false }
);

const productSchema = new mongoose.Schema(
  {
    title:         { type: String },
    price:         { type: String },
    originalPrice: { type: String },
    link:          { type: String },
    imageUrl:      { type: String },
    thumbnail:     { type: String },
    source:        { type: String },
    rating:        { type: Number },
    ratingCount:   { type: Number },
    delivery:      { type: String },
    offers:        { type: Number },
    extensions:    { type: [String], default: [] },
  },
  { _id: false }
);

const searchHistorySchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', index: true },
    sessionId: { type: String },
    tags: { type: tagSchema },
    results: { type: [productSchema] },
    imagePath: { type: String },
    transcript: { type: String },
  },
  { timestamps: true }
);

// Auto-delete anonymous (no userId) documents after 30 days
searchHistorySchema.index(
  { createdAt: 1 },
  {
    expireAfterSeconds: 30 * 24 * 60 * 60,
    partialFilterExpression: { userId: { $exists: false } },
  }
);

module.exports = mongoose.model('SearchHistory', searchHistorySchema);
