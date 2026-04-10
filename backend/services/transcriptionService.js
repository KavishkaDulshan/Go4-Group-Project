'use strict';
const OpenAI = require('openai');
const fs = require('fs');

/**
 * Transcribes an audio file using Groq's Whisper API.
 * The Groq API is OpenAI-compatible — we reuse the openai npm package
 * and just point it at https://api.groq.com/openai/v1.
 *
 * @param {string} audioPath - Absolute path to the audio file (m4a / mp3 / wav / …)
 * @returns {Promise<string>} Transcribed text
 */
async function transcribeAudio(audioPath) {
  if (!process.env.GROQ_API_KEY) {
    throw new Error('GROQ_API_KEY is not configured in .env');
  }

  const groq = new OpenAI({
    apiKey: process.env.GROQ_API_KEY,
    baseURL: 'https://api.groq.com/openai/v1',
  });

  const transcription = await groq.audio.transcriptions.create({
    file: fs.createReadStream(audioPath),
    model: 'whisper-large-v3-turbo',
    response_format: 'json',
    language: 'en',
  });

  return (transcription.text ?? '').trim();
}

module.exports = { transcribeAudio };
