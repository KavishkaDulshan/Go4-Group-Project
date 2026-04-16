'use strict';
const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    googleId: { type: String, required: true, unique: true, index: true },
    email: { type: String, required: true, lowercase: true },
    displayName: { type: String },
    photoUrl: { type: String },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', userSchema);
